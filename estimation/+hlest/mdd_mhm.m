function [lmdd, p] = mdd_mhm(X, lp, p)
%MDD_MHM  Geweke's modified harmonic mean estimate of the log marginal data density.
%
%   [lmdd, p] = hlest.mdd_mhm(X, lp)
%   [lmdd, p] = hlest.mdd_mhm(X, lp, p)
%
%   X   N x d posterior draws (post burn-in, chains pooled); lp  N x 1 log posterior kernel
%   p   truncation probabilities (default 0.1:0.1:0.9, as Dynare marginal_density)
%   lmdd(k) = -log mean_i [ f_k(x_i) / exp(lp_i) ], f_k the normal density with the draws'
%   mean and covariance truncated to {(x-mu)' Sigma^{-1} (x-mu) <= chi2inv(p_k, d)} and divided
%   by p_k. chi2inv(p, d) = 2 gammaincinv(p, d/2) (base MATLAB).

if nargin < 3 || isempty(p)
    p = 0.1:0.1:0.9;
end
[N, d] = size(X);
mu = mean(X, 1);
Sg = cov(X);
[R, flag] = chol(Sg);
if flag ~= 0
    lmdd = NaN(size(p));
    return
end
ldS = 2*sum(log(diag(R)));
Zs = (X - mu)/R;                     % rows: R' \ (x - mu)
q = sum(Zs.^2, 2);
lmdd = NaN(size(p));
for k = 1:numel(p)
    crit = 2*gammaincinv(p(k), d/2);
    in = q <= crit;
    lf = -log(p(k)) - 0.5*d*log(2*pi) - 0.5*ldS - 0.5*q;
    v = lf - lp(:);
    v(~in) = -Inf;
    mx = max(v);
    if ~isfinite(mx)
        continue
    end
    lmean = mx + log(sum(exp(v - mx))) - log(N);
    lmdd(k) = -lmean;
end
end
