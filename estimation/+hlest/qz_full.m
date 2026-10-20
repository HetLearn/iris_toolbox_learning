function [T0, R0, K0, flag, info] = qz_full(A, B, C, D, nu, keep, tol)
%QZ_FULL  Port of the IRIS 20230622 first-order solver on the full pencil (no static elimination).
%
%   [T0, R0, K0, flag, info] = hlest.qz_full(A, B, C, D, nu, keep)
%
%   Reference implementation (design prototype proto/qz_solve.m) kept for diagnostics:
%   A E[x_t] + B x_{t-1} + C + D e_t = 0, x = [xf (nu); xb]; output
%   [xf(keep); xb]_t = T0 xb_{t-1} + K0 + R0 e_t; flag 1 unique stable, 0 none, Inf multiple.
if nargin < 7 || isempty(tol)
    tol = eps()^(5/9);
end
nX = size(A, 2);
nb = nX - nu;
[SS, TT, QQ, ZZ] = qz(A, B, 'real');
invEig = -ordeig(SS, TT);
absInv = abs(invEig);
stable = absInv >= 1 + tol;
unit = abs(absInv - 1) < tol;
cl = zeros(size(invEig));
cl(unit) = 2;
cl(stable) = 1;
[SS, TT, QQ, ZZ] = ordqz(SS, TT, QQ, ZZ, cl);
invEig = -ordeig(SS, TT);
ev = Inf(size(invEig));
nz = invEig ~= 0;
ev(nz) = 1 ./ invEig(nz);
absE = abs(ev);
nStable = nnz(absE <= 1 - tol);
nUnit = nnz(abs(absE - 1) < tol);
if nb == nStable + nUnit
    flag = 1;
elseif nb > nStable + nUnit
    flag = 0;
else
    flag = Inf;
end
info = struct('eig', ev, 'nb', nb, 'n_stable', nStable, 'n_unit', nUnit);
T0 = [];
R0 = [];
K0 = [];
if flag ~= 1
    return
end
S11 = SS(1:nb, 1:nb);
S12 = SS(1:nb, nb+1:end);
S22 = SS(nb+1:end, nb+1:end);
T11 = TT(1:nb, 1:nb);
T12 = TT(1:nb, nb+1:end);
T22 = TT(nb+1:end, nb+1:end);
ZZf = ZZ(1:nu, :);
Z11 = ZZf(keep, 1:nb);
Z12 = ZZf(keep, nb+1:end);
Z21 = ZZ(nu+1:end, 1:nb);
Z22 = ZZ(nu+1:end, nb+1:end);
Cq = QQ * C;
Dq = QQ * D;
C1 = Cq(1:nb, 1);
C2 = Cq(nb+1:end, 1);
D1 = Dq(1:nb, :);
D2 = Dq(nb+1:end, :);
U = Z21;
G = -Z21 \ Z22;
Ru = -T22 \ D2;
Ku = -(S22 + T22) \ C2;
Ta = -S11 \ T11;
Xa0 = S11 \ (T11*G + T12);
Ra = -Xa0*Ru - S11 \ D1;
Xa1 = G + S11 \ S12;
Ka = -(Xa0 + Xa1)*Ku - S11 \ C1;
Xf = Z11*G + Z12;
Tf = Z11;
Rf = Xf*Ru;
Kf = Xf*Ku;
T0 = [Tf / U; U*Ta / U];
R0 = [Rf; U*Ra];
K0 = [Kf; U*Ka];
end
