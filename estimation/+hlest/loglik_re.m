function [ll, out] = loglik_re(pb, theta, wantPaths)
%LOGLIK_RE  Log likelihood of the RE model (own Kalman filter, stochastic initialisation).
%
%   [ll, out] = hlest.loglik_re(pb, theta)
%   [ll, out] = hlest.loglik_re(pb, theta, true)      % with filtered paths
%
%   ll   sum of the log densities over pb.ilike:end (1966Q1-2026Q2); the filter starts at
%        1965Q1 (presample 1965Q1-Q4) from a0 = (I-Tb)^{-1}Kb and the Lyapunov MSE.
%        -Inf when the model has no unique stable solution or a covariance is not PD.
%   out  .llt (1 x nT), .status, .ss (state space), .F (paths: filtered states and shocks)

if nargin < 3
    wantPaths = false;
end
out = struct('llt', [], 'status', 'ok');
P = hlest.theta_struct(pb, theta);
[ok, ss] = hlest.solve_orig(pb, P);
if ~ok
    ll = -Inf;
    out.status = 'no unique stable RE solution';
    return
end
Q = ss.Rb*ss.Omg*ss.Rb';
[a0, P0, ok] = hlest.init_state(ss.Tb, ss.Kb, (Q + Q')/2);
if ~ok
    ll = -Inf;
    out.status = 'initial covariance';
    return
end
[llt, ok, F] = hlest.kf(ss.Tb, ss.Rb, ss.Kb, ss.Z, ss.D, ss.Omg, pb.Y, a0, P0, wantPaths);
if ~ok
    ll = -Inf;
    out.status = 'prediction-error covariance not PD';
    return
end
ll = sum(llt(pb.ilike:end));
if ~isfinite(ll)
    ll = -Inf;
    out.status = 'non-finite likelihood';
end
out.llt = llt;
if wantPaths
    out.ss = ss;
    out.F = F;
    out.a0 = a0;
    out.P0 = P0;
end
end
