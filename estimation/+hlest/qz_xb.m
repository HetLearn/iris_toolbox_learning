function [Tb, Rb, Kb, flag] = qz_xb(Rd, n1, al, be)
%QZ_XB  Predetermined-state block of the ALM solution for given shares and beliefs (fast path).
%
%   [Tb, Rb, Kb, flag] = hlest.qz_xb(Rd, n1, alpha, beta)
%
%   Rd     reduced system of hlest.reduce_static
%   n1     RE share in the model (n2 = 1 - n1); alpha, beta  AR(1) PLM beliefs of pinf
%   Output xb_t = Tb xb_{t-1} + Kb + Rb e_t, the xb rows of IRIS's solution
%          (sspace(m, 'triangular', false)); flag 1 unique stable, 0 no stable, Inf
%          multiple stable (IRIS's test, tolerance eps^(5/9)).
%
%   Steps: (1) the four belief/share entries (anchored RE, IRIS system convention):
%          pinf_exp1 = n1 pinf_exp1_RE + n2 pinf_exp1_BR, and
%          'lagged'  pinf_exp1_BR = alpha + beta (alpha + beta pinf{-1}),
%          'current' pinf_exp1_BR = alpha + beta pinf;
%   (2) eliminate the statics pinf_exp1, pinf_exp1_RE, pinf_exp1_BR (QR of their three B
%   columns); (3) generalised Schur decomposition of the remaining pencil, ordered as IRIS
%   solveFirstOrder (unit roots, then stable, then unstable), and the stable block mapped to
%   the predetermined states (port of IRIS's local_computeGeneralizedSchur and the
%   transition-equation step, xb rows only).

tol = 1.8189894035458565e-09;      % eps()^(5/9), IRIS default
A = Rd.A;
B = Rd.B;
C = Rd.C;
sE = Rd.sE;
sB = Rd.sB;
B(Rd.rE, Rd.jRE) = -sE*n1;
B(Rd.rE, Rd.jBR) = -sE*(1 - n1);
if Rd.current
    A(Rd.rB, Rd.jP) = -sB*be;
    C(Rd.rB) = -sB*al;
else
    B(Rd.rB, Rd.jP) = -sB*be^2;
    C(Rd.rB) = -sB*al*(1 + be);
end
[Q3, ~] = qr(B(:, Rd.s3));
Qk = Q3(:, 4:end)';
kc = Rd.keepc;
A2 = Qk*A(:, kc);
B2 = Qk*B(:, kc);
C2 = Qk*C;
D2 = Qk*Rd.D;
nu = Rd.nu2;
nb = Rd.nb;
Tb = [];
Rb = [];
Kb = [];
[SS, TT, QQ, ZZ] = qz(A2, B2, 'real');
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
    return
else
    flag = Inf;
    return
end
S11 = SS(1:nb, 1:nb);
S12 = SS(1:nb, nb+1:end);
S22 = SS(nb+1:end, nb+1:end);
T11 = TT(1:nb, 1:nb);
T12 = TT(1:nb, nb+1:end);
T22 = TT(nb+1:end, nb+1:end);
Z21 = ZZ(nu+1:end, 1:nb);
Z22 = ZZ(nu+1:end, nb+1:end);
Cq = QQ*C2;
Dq = QQ*D2;
C1 = Cq(1:nb, 1);
C2b = Cq(nb+1:end, 1);
D1 = Dq(1:nb, :);
D2b = Dq(nb+1:end, :);
G = -Z21 \ Z22;
Ru = -T22 \ D2b;
Ku = -(S22 + T22) \ C2b;
Ta = -S11 \ T11;
Xa0 = S11 \ (T11*G + T12);
Ra = -Xa0*Ru - S11 \ D1;
Xa1 = G + S11 \ S12;
Ka = -(Xa0 + Xa1)*Ku - S11 \ C1;
Tb = Z21*Ta / Z21;
Rb = Z21*Ra;
Kb = Z21*Ka;
if ~(all(isfinite(Tb(:))) && all(isfinite(Rb(:))) && all(isfinite(Kb)))
    flag = NaN;
end
end
