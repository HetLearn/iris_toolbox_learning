function [a0, P0, ok] = init_state(Tb, Kb, Q)
%INIT_STATE  Stochastic initial condition of the filter (IRIS loglik default 'Initials' 'steady').
%
%   [a0, P0, ok] = hlest.init_state(Tb, Kb, Q)
%
%   a0 = (I - Tb)^{-1} Kb, P0 = Tb P0 Tb' + Q (Lyapunov equation solved on the real Schur form
%   of Tb, a port of IRIS covfun.lyapunov). ok = false when Tb has a root on or outside the
%   unit circle or the result is not finite.

nb = size(Tb, 1);
[U, Ts] = schur(Tb, 'real');
ev = ordeig(Ts);
ok = all(abs(ev) < 1 - 1e-10);
if ~ok
    a0 = [];
    P0 = [];
    return
end
a0 = (eye(nb) - Tb) \ Kb;
Ps = lyap_qt(Ts, U'*Q*U);
P0 = U*Ps*U';
P0 = (P0 + P0')/2;
ok = all(isfinite(P0(:))) && all(isfinite(a0));
end


function C = lyap_qt(T, SGM)
% C = T*C*T' + SGM for quasi-triangular T (IRIS 20230622 covfun.lyapunov, beta = 1).
C = zeros(size(T));
i = size(T, 1);
Tt = T.';
while i >= 1
    if i == 1 || T(i, i-1) == 0
        C(i, i+1:end) = C(i+1:end, i).';
        c = (SGM(i, 1:i) + T(i, i)*C(i, i+1:end)*Tt(i+1:end, 1:i) + ...
            T(i, i+1:end)*C(i+1:end, :)*Tt(:, 1:i)) / (eye(i) - T(i, i)*Tt(1:i, 1:i));
        C(i, 1:i) = c;
        i = i - 1;
    else
        C(i-1:i, i+1:end) = C(i+1:end, i-1:i).';
        X = T(i-1:i, i-1:i)*C(i-1:i, i+1:end)*Tt(i+1:end, 1:i) + ...
            T(i-1:i, i+1:end)*C(i+1:end, :)*Tt(:, 1:i) + SGM(i-1:i, 1:i);
        Xt = X.';
        U = Tt(1:i, 1:i).';
        k = [T(i-1, i-1)*U, T(i-1, i)*U; T(i, i-1)*U, T(i, i)*U];
        ct = (eye(2*i) - k) \ Xt(:);
        C(i-1:i, 1:i) = reshape(ct, [i, 2]).';
        i = i - 2;
    end
end
end
