function A = alm_setup(pb, theta)
%ALM_SETUP  Per-theta set-up of the learning model's ALM (the first block of hlest.loglik_learn).
%
%   A = hlest.alm_setup(pb, theta)
%   [Tb, Rb, Kb, flag] = hlest.qz_xb(A.Rd, n1, alpha, beta)    % ALM for given shares and beliefs
%
%   pb     hlest.problem('learn', ...); theta  39 x 1 (36 SW07 parameters, gain, memory, chi)
%   A      .ok (false: no unique stable RE solution or the static elimination failed),
%          .status, .ss (hlest.solve_orig: RE xb block Tb, Rb, Kb, measurement Z, D, shock
%          covariance Omg, anchored RE coefficients k, c of pinf), .Rd (hlest.reduce_static of
%          the extended model with the anchored coefficients assigned)
%   Same steps as hlest.loglik_learn (solve the original model, assign k and c to the
%   extended model, system(), static elimination), so the ALM of hlest.qz_xb is the one the
%   likelihood uses. Used by est_06_post for the impulse responses at fixed beliefs.

A = struct('ok', false, 'status', 'ok', 'ss', [], 'Rd', []);
th = theta(:);
P = hlest.theta_struct(pb, th);
[ok, ss] = hlest.solve_orig(pb, P);
if ~ok
    A.status = 'no unique stable RE solution';
    return
end
PA = P;
an = pb.anchor_names;
PA.(an{1}) = ss.k;
for j = 1:numel(pb.xb)
    PA.(an{1 + j}) = ss.c(j);
end
mLt = assign(pb.mL, PA);
[A0, B0, C0, D0] = system(mLt, 'MatrixFormat', 'plain', 'Normalize', false);
Rd = hlest.reduce_static(pb.sx, A0, B0, C0, D0);
if ~Rd.ok
    A.status = 'static elimination failed';
    return
end
A.ok = true;
A.ss = ss;
A.Rd = Rd;
end
