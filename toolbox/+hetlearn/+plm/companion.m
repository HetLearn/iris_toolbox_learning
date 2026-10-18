function [F, rho] = companion(sys, phi, eqs)
%COMPANION  Companion matrix of the closed PLM system (or of one PLM block) and its spectral radius.
%
%   [F, rho] = hetlearn.plm.companion(sys, phi)
%   [F, rho] = hetlearn.plm.companion(sys, phi, eqs)
%
%   Inputs
%     sys  closed PLM system from hetlearn.plm.build_system
%     phi  struct by target of coefficient column vectors (param_names order)
%     eqs  optional indices into sys.eq of a closed subset, e.g. one PLM
%          block (hetlearn.plm.blocks(sys).eqs): the companion matrix of
%          those equations alone (their regressors must be among them)
%
%   Outputs
%     F    (1 + n*L) square matrix with X_t = F * X_{t-1}, where
%          X_t = [1; y_t; y_{t-1}; ...; y_{t-L+1}], y_t the n targets in
%          sys.targets order, L = max(sys.maxlag, 1).
%     rho  spectral radius excluding the unit root of the constant, i.e.
%          max abs eigenvalue of F(2:end, 2:end); NaN if a coefficient is
%          not finite. Used by the projection facility (DESIGN 4.4: a PLM
%          block is explosive when rho > 1).

if nargin >= 3 && ~isempty(eqs)
    sub = sys;
    sub.eq = sys.eq(eqs);
    sub.targets = sys.targets(eqs);
    lags = [sub.eq.reg_lags];
    sub.maxlag = 0;
    if ~isempty(lags)
        sub.maxlag = max(lags);
    end
    sys = sub;
end
n = numel(sys.targets);
L = max(sys.maxlag, 1);
N = 1 + n * L;
F = zeros(N);
F(1, 1) = 1;
for i = 1:n
    e = sys.eq(i);
    c = phi.(e.target);
    c = c(:);
    row = 1 + i;
    p = 0;
    if e.constant
        p = 1;
        F(row, 1) = c(1);
    end
    for j = 1:numel(e.reg_names)
        u = find(strcmp(sys.targets, e.reg_names{j}), 1);
        if isempty(u)
            error('hetlearn:plm:open', 'Regressor %s of %s is not a target of the equations given.', ...
                e.reg_names{j}, e.target);
        end
        l = e.reg_lags(j);
        col = 1 + (l - 1) * n + u;
        F(row, col) = F(row, col) + c(p + j);
    end
end
for l = 2:L
    rows = 1 + (l - 1) * n + (1:n);
    cols = 1 + (l - 2) * n + (1:n);
    F(rows, cols) = eye(n);
end
A = F(2:end, 2:end);
if isempty(A)
    rho = 0;
elseif ~all(isfinite(A(:)))
    rho = NaN;
else
    rho = max(abs(eig(A)));
end
end
