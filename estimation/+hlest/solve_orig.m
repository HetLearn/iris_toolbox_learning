function [ok, ss, mo] = solve_orig(pb, P)
%SOLVE_ORIG  RE solution of the original model at P and its state-space blocks.
%
%   [ok, ss, mo] = hlest.solve_orig(pb, P)
%
%   ok  true when IRIS finds a unique stable solution
%   ss  .Tb .Rb .Kb  xb rows of [xf; xb]_t = T xb_{t-1} + K + R e_t (sspace, triangular false)
%       .Z .D        measurement y_t = Z xb_t + D (no measurement error in SW07)
%       .Omg         shock covariance (diag of std_<shock>^2)
%       .k .c        anchored RE coefficients of pinf: E_t pinf_{t+1} = k + c' xb_t
%                    (K and T rows of pinf, as hetlearn.re_anchor_coefficients)

ss = [];
mo = assign(pb.mo, P);
[mo, flag] = solve(mo, 'Warning', false);
ok = hasSucceeded(flag);
if ~ok
    return
end
[T, R, K, Z, ~, D, ~, Omg] = sspace(mo, 'triangular', false);
T = T(:, :, 1);
ne = size(Omg, 1);
R = R(:, 1:ne, 1);
K = K(:, 1, 1);
nb = size(T, 2);
nf = size(T, 1) - nb;
ss = struct();
ss.Tb = T(nf+1:end, :);
ss.Rb = R(nf+1:end, :);
ss.Kb = K(nf+1:end);
ss.Z = Z(:, :, 1);
ss.D = D(:, 1, 1);
ss.Omg = Omg(:, :, 1);
ss.k = K(pb.pos_pinf);
ss.c = T(pb.pos_pinf, :)';
ok = all(isfinite(ss.Tb(:))) && all(isfinite(ss.Rb(:))) && all(isfinite(ss.Kb)) && all(isfinite(ss.D));
end
