function [llt, ok, F] = kf(Tb, Rb, Kb, Z, D, Omg, Y, a0, P0, wantPaths)
%KF  Time-invariant Kalman filter, NaN rows dropped (RE model).
%
%   [llt, ok, F] = hlest.kf(Tb, Rb, Kb, Z, D, Omg, Y, a0, P0, wantPaths)
%
%   xb_t = Tb xb_{t-1} + Kb + Rb e_t, e_t ~ N(0, Omg);  y_t = Z xb_t + D (no measurement error)
%   llt(t) = log density of y_t given y_1..y_{t-1} (with the 2 pi constant; 0 without data).
%   ok = false when a prediction-error covariance is not positive definite (llt then partial).
%   F (wantPaths): .a (filtered states nb x nT), .e (filtered shocks E[e_t | y_1..t]),
%   .v (prediction errors ny x nT, NaN where missing).

if nargin < 10
    wantPaths = false;
end
nT = size(Y, 2);
nb = size(Tb, 1);
a = a0;
P = P0;
Q = Rb*Omg*Rb';
Q = (Q + Q')/2;
llt = zeros(1, nT);
ok = true;
F = struct();
if wantPaths
    F.a = NaN(nb, nT);
    F.e = zeros(size(Omg, 1), nT);
    F.v = NaN(size(Y, 1), nT);
end
c2pi = log(2*pi);
for t = 1:nT
    a = Tb*a + Kb;
    P = Tb*P*Tb' + Q;
    obs = isfinite(Y(:, t));
    if any(obs)
        Zt = Z(obs, :);
        v = Y(obs, t) - Zt*a - D(obs);
        PZ = P*Zt';
        Fm = Zt*PZ;
        Fm = (Fm + Fm')/2;
        [L, p] = chol(Fm, 'lower');
        if p ~= 0
            ok = false;
            return
        end
        w = L \ v;
        llt(t) = -0.5*(nnz(obs)*c2pi + 2*sum(log(diag(L))) + w'*w);
        Fi_v = L' \ w;
        if wantPaths
            F.e(:, t) = Omg*Rb'*Zt'*Fi_v;
            F.v(obs, t) = v;
        end
        a = a + PZ*Fi_v;
        P = P - PZ*(L' \ (L \ PZ'));
        P = (P + P')/2;
    end
    if wantPaths
        F.a(:, t) = a;
    end
end
end
