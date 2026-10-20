function D = diagnostics(X)
%DIAGNOSTICS  Split R-hat and bulk ESS (rank-normalised, Geyer initial monotone sequence).
%
%   D = hlest.diagnostics(X)
%
%   X   n x m x d array: n draws (post burn-in) of m chains for d parameters (equal lengths)
%   D   .rhat (1 x d) split R-hat (Gelman et al. 2013, BDA3 11.4) on the rank-normalised draws
%       (Vehtari et al. 2021), .rhat_raw on the raw draws, .ess_bulk (1 x d) on the
%       rank-normalised split chains, .ess_raw on the raw split chains, .mean, .sd

[n, m, d] = size(X);
D = struct('rhat', NaN(1, d), 'rhat_raw', NaN(1, d), 'ess_bulk', NaN(1, d), 'ess_raw', NaN(1, d), ...
    'mean', NaN(1, d), 'sd', NaN(1, d));
h = floor(n/2);
if h < 4
    return
end
for k = 1:d
    x = X(:, :, k);
    xs = [x(1:h, :), x(n-h+1:n, :)];               % split chains
    z = rank_normalise(xs);
    D.rhat(k) = rhat(z);
    D.rhat_raw(k) = rhat(xs);
    D.ess_bulk(k) = ess(z);
    D.ess_raw(k) = ess(xs);
    D.mean(k) = mean(x(:));
    D.sd(k) = std(x(:));
end
end


function r = rhat(x)
[n, ~] = size(x);
cm = mean(x, 1);
cv = var(x, 0, 1);
W = mean(cv);
Bn = var(cm);                    % B/n
vp = (n - 1)/n*W + Bn;
r = sqrt(vp/W);
if W == 0
    r = NaN;
end
end


function z = rank_normalise(x)
% Rank over the pooled draws (average ranks for ties), z = Phi^{-1}((r - 3/8)/(S + 1/4)).
S = numel(x);
[s, i] = sort(x(:));
r = zeros(S, 1);
k = 1;
while k <= S
    j = k;
    while j < S && s(j + 1) == s(k)
        j = j + 1;
    end
    r(i(k:j)) = (k + j)/2;
    k = j + 1;
end
p = (r - 3/8)/(S + 1/4);
z = reshape(-sqrt(2)*erfcinv(2*p), size(x));
end


function e = ess(x)
% Effective sample size of the m chains in the columns of x (Stan's ess with Geyer's initial
% monotone sequence estimator).
[n, m] = size(x);
if n < 4
    e = NaN;
    return
end
acov = zeros(n, m);
for j = 1:m
    acov(:, j) = autocov(x(:, j));
end
cm = mean(x, 1);
mean_var = mean(acov(1, :))*n/(n - 1);
var_plus = mean_var*(n - 1)/n;
if m > 1
    var_plus = var_plus + var(cm);
end
if var_plus <= 0
    e = NaN;
    return
end
% translation of rstan monitor.R ess_rfun (tl = lag; rho(tl+1) holds lag tl)
rho = zeros(n + 2, 1);
tl = 0;
rho_even = 1;
rho(tl + 1) = rho_even;
rho_odd = 1 - (mean_var - mean(acov(tl + 2, :)))/var_plus;
rho(tl + 2) = rho_odd;
while tl < n - 5 && ~isnan(rho_even + rho_odd) && (rho_even + rho_odd > 0)
    tl = tl + 2;
    rho_even = 1 - (mean_var - mean(acov(tl + 1, :)))/var_plus;
    rho_odd = 1 - (mean_var - mean(acov(tl + 2, :)))/var_plus;
    if (rho_even + rho_odd) >= 0
        rho(tl + 1) = rho_even;
        rho(tl + 2) = rho_odd;
    end
end
max_t = tl;
if rho_even > 0
    rho(max_t + 1) = rho_even;
end
tl = 0;
while tl <= max_t - 4
    tl = tl + 2;
    if rho(tl + 1) + rho(tl + 2) > rho(tl - 1) + rho(tl)
        rho(tl + 1) = (rho(tl - 1) + rho(tl))/2;
        rho(tl + 2) = rho(tl + 1);
    end
end
tau = -1 + 2*sum(rho(1:max_t)) + rho(max_t + 1);
tau = max(tau, 1/log10(n*m));
e = n*m/tau;
end


function g = autocov(y)
% Biased autocovariance (divided by n) by FFT, lags 0..n-1.
n = numel(y);
y = y(:) - mean(y);
nf = 2^nextpow2(2*n);
F = fft(y, nf);
a = real(ifft(F.*conj(F)));
g = a(1:n)/n;
end
