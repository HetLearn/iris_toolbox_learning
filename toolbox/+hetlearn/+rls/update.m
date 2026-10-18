function [phi, R] = update(phi, R, z, y, g)
%UPDATE  One constant-gain (or any-gain) RLS step, IJCB eq. 13 (DESIGN 4.3).
%
%   [phi, R] = hetlearn.rls.update(phi, R, z, y, g)
%
%   Inputs
%     phi  k x 1 coefficients phi_{t-1}
%     R    k x k second-moment matrix R_{t-1}
%     z    k x 1 regressors z_{t-1} = [1; regressors dated <= t-1]
%          (no leading 1 when the PLM has no constant)
%     y    scalar realised target v_t
%     g    scalar gain g_t
%
%   Outputs
%     phi  phi_t = phi_{t-1} + g * R_t \ (z * (y - phi_{t-1}' * z))
%     R    R_t   = R_{t-1} + g * (z * z' - R_{t-1})
%
%   R is updated first and phi uses the new R_t (R_t \ ..., no inverse).

phi = phi(:);
z = z(:);
R = R + g * (z * z' - R);
phi = phi + g * (R \ (z * (y - phi' * z)));
end
