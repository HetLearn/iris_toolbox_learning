function X = prior_draw(T, rs, n)
%PRIOR_DRAW  Draws from the prior truncated to the hard bounds (base MATLAB only).
%
%   X = hlest.prior_draw(T, rs, n)
%
%   T  parameter table; rs  RandStream; n  number of draws.  X is T.n x n.
%   Gamma draws by Marsaglia-Tsang; beta = G1/(G1+G2); inverse gamma 1 = 1/sqrt(G) with
%   G ~ Gamma(nu/2, scale 2/s); normal by randn. Out-of-bounds draws are redrawn.

X = zeros(T.n, n);
for j = 1:n
    for i = 1:T.n
        for tries = 1:10000
            v = one(T, i, rs);
            if v > T.lb(i) && v < T.ub(i)
                break
            end
        end
        X(i, j) = v;
    end
end
end


function v = one(T, i, rs)
a = T.h1(i);
b = T.h2(i);
switch T.shape(i)
    case 1
        g1 = rgamma(a, rs);
        g2 = rgamma(b, rs);
        v = T.p3(i) + (T.p4(i) - T.p3(i))*g1/(g1 + g2);
    case 2
        v = T.p3(i) + b*rgamma(a, rs);
    case 3
        v = a + b*randn(rs);
    case 4
        g = rgamma(b/2, rs)*2/a;
        v = T.p3(i) + 1/sqrt(g);
end
end


function g = rgamma(k, rs)
% Gamma(k, 1) draw (Marsaglia and Tsang 2000; k < 1 by the boost U^(1/k)).
if k < 1
    g = rgamma(k + 1, rs)*rand(rs)^(1/k);
    return
end
d = k - 1/3;
c = 1/sqrt(9*d);
while true
    z = randn(rs);
    v = (1 + c*z)^3;
    if v <= 0
        continue
    end
    u = rand(rs);
    if log(u) < 0.5*z^2 + d - d*v + d*log(v)
        g = d*v;
        return
    end
end
end
