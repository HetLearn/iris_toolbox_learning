function [lmdd, info] = mdd_laplace(lp, H)
%MDD_LAPLACE  Laplace approximation of the log marginal data density at the posterior mode.
%
%   [lmdd, info] = hlest.mdd_laplace(lp, H)
%
%   lp  log posterior kernel at the mode (log L + log prior); H  Hessian of minus the log
%   posterior at the mode (original parameter space).
%   log p(Y) = lp + (d/2) log(2 pi) - 0.5 log det H   (Dynare: -1668.8829 for swX1, d = 36).
%   A non-PD H gives NaN (info.pd = false).

d = size(H, 1);
H = (H + H')/2;
[R, p] = chol(H);
info = struct('pd', p == 0, 'logdetH', NaN, 'd', d);
if p ~= 0
    lmdd = NaN;
    return
end
info.logdetH = 2*sum(log(diag(R)));
lmdd = lp + 0.5*d*log(2*pi) - 0.5*info.logdetH;
end
