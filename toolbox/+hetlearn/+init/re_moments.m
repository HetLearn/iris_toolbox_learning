function [phi0, R0, info] = re_moments(m, sys)
%RE_MOMENTS  Initial beliefs from the unconditional RE moments (DESIGN 4.7).
%
%   [phi0, R0, info] = hetlearn.init.re_moments(m, sys)
%
%   Inputs
%     m    solved IRIS Model (the RE model: the original model, or the
%          extended model with every n1 = 1); must contain every variable
%          in the PLM system.
%     sys  closed PLM system from hetlearn.plm.build_system
%
%   Outputs
%     phi0  struct by target: phi0.<v> = E[z z'] \ E[z v]   (column vector,
%           param_names order)
%     R0    struct by target: R0.<v> = E[z z']
%     info  struct with .means (struct of steady-state levels used) and
%           .order (acf order used)
%
%   Moments come from acf(m, 'order', sys.maxlag): C(:,:,k+1) =
%   Cov(x_t, x_{t-k}). Means are the steady-state levels
%   (access(m,'steady-level')); for a linear model in deviations they are the
%   steady-state levels as computed by IRIS, usually 0. If they are NaN,
%   sstate(m) is called once. Second moments are Cov + mean*mean'.
%
%   For an AR(1) PLM on a zero-mean x this gives alpha = 0,
%   beta = C(x,x,lag1)/C(x,x,lag0), R0 = [1 0; 0 var(x)].

order = max(sys.maxlag, 1);
C = acf(m, 'order', order);
names = cellstr(C.RowNames);
Cd = double(C);
Cd = Cd(:, :, :, 1);

ss = get_means(m);
needed = unique([sys.targets, [sys.eq.reg_names]]);
mu = struct();
for i = 1:numel(needed)
    v = needed{i};
    if ~isfield(ss, v)
        error('hetlearn:init:noVar', 'Variable %s is not in the model.', v);
    end
    mu.(v) = real(ss.(v));
    if isnan(mu.(v))
        if ~isLinear(m)
            error('hetlearn:init:noSstate', 'Steady state of %s is NaN; run sstate first.', v);
        end
        m = sstate(m);
        ss = get_means(m);
        mu.(v) = real(ss.(v));
        if isnan(mu.(v))
            error('hetlearn:init:noSstate', 'Steady state of %s is NaN.', v);
        end
    end
end

    function c = cv(a, la, b, lb)
        % Cov(a_{t-la}, b_{t-lb})
        ia = find(strcmp(names, a), 1);
        ib = find(strcmp(names, b), 1);
        if isempty(ia) || isempty(ib)
            error('hetlearn:init:noVar', 'Variable %s or %s is not in the acf output.', a, b);
        end
        d = lb - la;
        if d >= 0
            c = Cd(ia, ib, d + 1);       % Cov(a_s, b_{s-d})
        else
            c = Cd(ib, ia, -d + 1);      % Cov(b_s, a_{s-|d|})
        end
    end

phi0 = struct();
R0 = struct();
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    v = e.target;
    nr = numel(e.reg_names);
    % element list: (name, lag); lag 0 = target, NaN = constant
    zn = e.reg_names;
    zl = e.reg_lags;
    S = zeros(nr);
    s = zeros(nr, 1);
    for a = 1:nr
        for b = 1:nr
            S(a, b) = cv(zn{a}, zl(a), zn{b}, zl(b)) + mu.(zn{a}) * mu.(zn{b});
        end
        s(a) = cv(zn{a}, zl(a), v, 0) + mu.(zn{a}) * mu.(v);
    end
    if e.constant
        mz = cellfun(@(u) mu.(u), zn)';
        S = [1, mz'; mz, S]; %#ok<AGROW>
        s = [mu.(v); s]; %#ok<AGROW>
    end
    if rcond(S) < 1e-14
        warning('hetlearn:init:singular', ...
            'E[zz''] for the PLM of %s is (near) singular; using pinv.', v);
        phi0.(v) = pinv(S) * s;
    else
        phi0.(v) = S \ s;
    end
    R0.(v) = S;
end
info = struct('means', mu, 'order', order);
end


function ss = get_means(m)
try
    ss = access(m, 'steady-level');
catch
    ss = get(m, 'steadyLevel');
end
end
