function R = test_rls()
%TEST_RLS  Constant-gain RLS (hetlearn.rls.update) and the gain interface.
%
%   R = test_rls()   returns a struct array of checks (name, pass, msg).

R = struct('name', {}, 'pass', {}, 'msg', {});
rng(20261017);

% single step against the textbook formula
try
    phi = [0.1; 0.5]; Rm = [1 0.2; 0.2 2]; z = [1; 0.7]; y = 0.9; g = 0.05;
    Rn = Rm + g * (z * z' - Rm);
    pn = phi + g * inv(Rn) * z * (y - phi' * z); %#ok<MINV>
    [p1, R1] = hetlearn.rls.update(phi, Rm, z, y, g);
    d = max([abs(p1 - pn); abs(R1(:) - Rn(:))]);
    R = add(R, 'rls: one step equals IJCB eq. 13 (R first, phi with new R)', d < 1e-14, sprintf('diff %.1e', d));
catch err
    R = add(R, 'rls: one step equals IJCB eq. 13 (R first, phi with new R)', false, err.message);
end

% loop against a hand-coded loop (3 regressors, time-varying gain)
try
    T = 300; k = 3;
    Z = [ones(T, 1), randn(T, k - 1)];
    Y = Z * [0.2; 0.5; -0.3] + 0.1 * randn(T, 1);
    phiA = zeros(k, 1); RA = eye(k);
    phiB = phiA; RB = RA;
    for t = 1:T
        g = 0.02 + 0.01 * sin(t);
        [phiA, RA] = hetlearn.rls.update(phiA, RA, Z(t, :)', Y(t), g);
        RB = RB + g * (Z(t, :)' * Z(t, :) - RB);
        phiB = phiB + g * (RB \ Z(t, :)') * (Y(t) - Z(t, :) * phiB);
    end
    d = max([abs(phiA - phiB); abs(RA(:) - RB(:))]);
    R = add(R, 'rls: 300-step loop equals hand-coded reference', d < 1e-12, sprintf('diff %.1e', d));
catch err
    R = add(R, 'rls: 300-step loop equals hand-coded reference', false, err.message);
end

% the RLS update with gain 1/t reproduces recursive OLS exactly
try
    T = 500; t0 = 10;
    Z = [ones(T, 1), randn(T, 2)];
    Y = Z * [1; 0.8; -0.4] + randn(T, 1);
    Zi = Z(1:t0, :); Yi = Y(1:t0);
    phi = (Zi' * Zi) \ (Zi' * Yi);
    Rm = (Zi' * Zi) / t0;
    for t = t0+1:T
        [phi, Rm] = hetlearn.rls.update(phi, Rm, Z(t, :)', Y(t), 1 / t);
    end
    ols = (Z' * Z) \ (Z' * Y);
    d = max(abs(phi - ols));
    R = add(R, 'rls: gain 1/t equals full-sample OLS', d < 1e-9, sprintf('diff %.1e', d));
catch err
    R = add(R, 'rls: gain 1/t equals full-sample OLS', false, err.message);
end

% constant gain 0.02 on a simulated AR(1) ends near the truth
try
    a = 0.2; b = 0.7; T = 20000;
    x = zeros(T, 1);
    x(1) = a / (1 - b);
    for t = 2:T
        x(t) = a + b * x(t - 1) + randn;
    end
    phi = [0; 0]; Rm = eye(2);
    path = zeros(2, T);
    for t = 2:T
        [phi, Rm] = hetlearn.rls.update(phi, Rm, [1; x(t - 1)], x(t), 0.02);
        path(:, t) = phi;
    end
    m = mean(path(:, T/2:end), 2);
    ok = abs(m(2) - b) < 0.03 && abs(m(1) - a) < 0.1 && abs(phi(2) - b) < 0.25;
    R = add(R, 'rls: constant gain 0.02 on AR(1) data converges near truth', ok, ...
        sprintf('mean alpha %.3f (0.2), mean beta %.3f (0.7), final beta %.3f', m(1), m(2), phi(2)));
catch err
    R = add(R, 'rls: constant gain 0.02 on AR(1) data converges near truth', false, err.message);
end

% gain rule interface
try
    o = struct('rule', 'constant', 'value', 0.0585, 'by_var', struct('pie', 0.02));
    s = struct('eq_index', 1, 'target', 'pie', 't', 1, 'fe_history', [], 'phi_history', []);
    g1 = hetlearn.gain.constant(s, o);
    s.target = 'y';
    g2 = hetlearn.gain.constant(s, o);
    R = add(R, 'gain: constant rule uses by_var, else value', g1 == 0.02 && g2 == 0.0585, '');
catch err
    R = add(R, 'gain: constant rule uses by_var, else value', false, err.message);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
