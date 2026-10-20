function [lp, lpi] = prior_logpdf(T, x)
%PRIOR_LOGPDF  Log prior density (Dynare 4.6.1 priordens), not renormalised for the bounds.
%
%   [lp, lpi] = hlest.prior_logpdf(T, x)
%
%   T   parameter table (hlest.param_table); x  column of T.n values
%   lp  sum of lpi; lpi(i) log density of parameter i (-Inf outside the prior support).
%   The hard bounds T.lb, T.ub are applied by hlest.logpost, not here (as in Dynare).

x = x(:);
n = T.n;
lpi = zeros(n, 1);
for i = 1:n
    xi = x(i);
    a = T.h1(i);
    b = T.h2(i);
    switch T.shape(i)
        case 1
            lo = T.p3(i);
            hi = T.p4(i);
            if xi <= lo || xi >= hi
                lpi(i) = -Inf;
            else
                lpi(i) = -betaln(a, b) + (a - 1)*log(xi - lo) + (b - 1)*log(hi - xi) ...
                    - (a + b - 1)*log(hi - lo);
            end
        case 2
            y = xi - T.p3(i);
            if y <= 0
                lpi(i) = -Inf;
            else
                lpi(i) = -gammaln(a) - a*log(b) + (a - 1)*log(y) - y/b;
            end
        case 3
            lpi(i) = -0.5*log(2*pi) - log(b) - 0.5*((xi - a)/b)^2;
        case 4
            y = xi - T.p3(i);
            if y <= 0
                lpi(i) = -Inf;
            else
                lpi(i) = log(2) - gammaln(b/2) - (b/2)*(log(2) - log(a)) - (b + 1)*log(y) - a/(2*y^2);
            end
    end
end
lp = sum(lpi);
end
