function q = quantile(X, p)
%QUANTILE  Sample quantiles along the second dimension (base MATLAB only).
%
%   q = hetlearn.density.quantile(X, p)
%
%   Inputs
%     X  n x N matrix: rows are series/dates, columns are draws (no NaN)
%     p  vector of probabilities in [0, 1]
%
%   Output
%     q  n x numel(p); NaN when N = 0
%
%   Definition (the default of quantile in the Statistics and Machine
%   Learning Toolbox): the sorted values x_(1) <= ... <= x_(N) sit at the
%   probabilities (i - 0.5)/N; q(p) interpolates linearly between them and
%   is x_(1) for p <= 0.5/N and x_(N) for p >= (N - 0.5)/N. q is monotone in
%   p, so quantiles of increasing p are ordered.

p = reshape(double(p), 1, []);
[n, N] = size(X);
q = NaN(n, numel(p));
if N == 0 || n == 0
    return
end
Xs = sort(X, 2);
pos = min(max(N * p + 0.5, 1), N);    % position in the sorted sample
lo = floor(pos);
hi = min(lo + 1, N);
w = pos - lo;
q = Xs(:, lo) .* (1 - w) + Xs(:, hi) .* w;
exact = (w == 0);
q(:, exact) = Xs(:, lo(exact));
end
