function [h1, h2] = prior_hyper(shape, p1, p2, p3, p4)
%PRIOR_HYPER  Hyperparameters of a prior given its mean p1, sd p2 and support (Dynare 4.6.1).
%
%   [h1, h2] = hlest.prior_hyper(shape, p1, p2, p3, p4)
%
%   shape 1 beta on [p3, p4]:   mu = (p1-p3)/(p4-p3), s2 = p2^2/(p4-p3)^2,
%                                a = (1-mu) mu^2/s2 - mu, b = a (1/mu - 1)      -> h1 = a, h2 = b
%   shape 2 gamma, shift p3:    k = (p1-p3)^2/p2^2, theta = p2^2/(p1-p3)       -> h1 = k, h2 = theta
%   shape 3 normal:             h1 = p1, h2 = p2
%   shape 4 inverse gamma 1:    (s, nu) with E[x] = sqrt(s/2) Gamma((nu-1)/2)/Gamma(nu/2) = p1 - p3
%                                and s = (p2^2 + (p1-p3)^2)(nu - 2) (Dynare inverse_gamma_specification,
%                                type 1)                                         -> h1 = s, h2 = nu

switch shape
    case 1
        mu = (p1 - p3)/(p4 - p3);
        s2 = p2^2/(p4 - p3)^2;
        h1 = (1 - mu)*mu^2/s2 - mu;
        h2 = h1*(1/mu - 1);
    case 2
        m = p1 - p3;
        h1 = m^2/p2^2;
        h2 = p2^2/m;
    case 3
        h1 = p1;
        h2 = p2;
    case 4
        [h1, h2] = ig1_spec(p1 - p3, p2^2);
    otherwise
        error('hlest:prior_hyper:shape', 'Unknown prior shape %d.', shape);
end
end


function [s, nu] = ig1_spec(mu, sigma2)
% Inverse gamma type 1 with mean mu and variance sigma2 (Dynare inverse_gamma_specification,
% type 1): s = (sigma2 + mu^2)*(nu - 2) and E[x] = sqrt(s/2)*Gamma((nu-1)/2)/Gamma(nu/2) = mu.
f = @(nu) log(mu) - 0.5*log((sigma2 + mu^2)*(nu - 2)/2) - gammaln((nu - 1)/2) + gammaln(nu/2);
lo = 2 + 1e-12;
hi = 4;
while f(hi) > 0
    hi = 2*hi;
end
for it = 1:200
    mid = (lo + hi)/2;
    if f(mid) > 0
        lo = mid;
    else
        hi = mid;
    end
    if hi - lo < 1e-15*hi
        break
    end
end
nu = (lo + hi)/2;
s = (sigma2 + mu^2)*(nu - 2);
end
