function [n1, zetaRE, zetaBR] = discrete_choice(FE_RE, FE_BR, zetaRE_prev, zetaBR_prev, chi, omega)
%DISCRETE_CHOICE  Fitness update and RE share, IJCB eqs. 14-15 (DESIGN 4.5).
%
%   [n1, zetaRE, zetaBR] = hetlearn.switching.discrete_choice( ...
%       FE_RE, FE_BR, zetaRE_prev, zetaBR_prev, chi, omega)
%
%   Inputs (scalars, or arrays of equal size for several share groups)
%     FE_RE, FE_BR   sums of squared one-step forecast errors in period t
%     zetaRE_prev    fitness zeta^RE_{t-1}
%     zetaBR_prev    fitness zeta^BR_{t-1}
%     chi            intensity of choice (>= 0)
%     omega          memory (0 <= omega < 1)
%
%   Outputs
%     n1       share of RE agents,
%              exp(chi*zRE) / (exp(chi*zRE) + exp(chi*zBR)); n2 = 1 - n1
%     zetaRE   zeta^RE_t = -(1 - omega)*FE_RE + omega*zetaRE_prev
%     zetaBR   zeta^BR_t = -(1 - omega)*FE_BR + omega*zetaBR_prev
%
%   Numerically stable: n1 = logistic(chi*(zRE - zBR)) evaluated without
%   overflow for any magnitude of chi*zeta. Infinite fitness values (from
%   init_n2 = 0 or 1) are carried through without NaN when omega = 0 or
%   chi = 0.

zetaRE = fit(FE_RE, zetaRE_prev, omega);
zetaBR = fit(FE_BR, zetaBR_prev, omega);
d = chi .* (zetaRE - zetaBR);
d(chi == 0 & ~isnan(zetaRE - zetaBR)) = 0;
d(isnan(d) & isinf(zetaRE) & isinf(zetaBR)) = 0;
n1 = zeros(size(d));
pos = d >= 0;
n1(pos) = 1 ./ (1 + exp(-d(pos)));
ed = exp(d(~pos));
n1(~pos) = ed ./ (1 + ed);
n1(isnan(d)) = NaN;
end


function z = fit(FE, zprev, omega)
mem = omega .* zprev;
if isscalar(omega)
    if omega == 0
        mem = zeros(size(zprev));
    end
else
    mem(omega == 0) = 0;
end
z = -(1 - omega) .* FE + mem;
end
