function F = forecast_re(pb, theta, varargin)
%FORECAST_RE  Application 1 of the RE model consistent with its likelihood: filtered state at the origin, zero shocks.
%
%   F = hlest.forecast_re(pb, theta)
%   F = hlest.forecast_re(pb, theta, 'origin', [2022 2], 'horizon', 16, 'check', true)
%   F = hlest.forecast_re(pb, theta, 'origin_state', xb)     % forecast from a given xb at the origin (gate G8)
%
%   pb  hlest.problem('re') (or 'learn': the first 36 entries of theta are used); theta  36 x 1
%
%   The RE filter of hlest.loglik_re (hlest.kf, stochastic initialisation at 1964Q4, NaN rows
%   dropped) on the data up to the origin; after it, the same filter without data, which is the
%   zero-shock simulation x_t = Tb x_{t-1} + Kb of the RE law of motion. 'check' (default true):
%   the filtered states up to the origin equal those of the filter on the full sample (one-sided;
%   F.check = largest absolute difference, asserted below 1e-12).
%
%   F  .ok, .status, .t_origin, .t_end, .q, .names (observables), .y (model units), .yrep (report
%      units, x spec.report.scale), .a (xb), .fRE (anchored RE forecast of pinf_{t+1} made in t,
%      k + c' x_t, model units), .fRE_rep (4 (fRE + constepinf)), .llt, .origin_state (xb at the
%      origin), .avg_pinf (average annualised inflation over the horizon), .check

ip = inputParser;
ip.addParameter('origin', [2022 2]);
ip.addParameter('horizon', 16);
ip.addParameter('check', true);
ip.addParameter('origin_state', []);
ip.parse(varargin{:});
o = ip.Results;
th = theta(:);
th = th(1:pb.nstruct);
tO = find(abs(pb.dates - double(qq(o.origin(1), o.origin(2)))) < 1e-6, 1);
if isempty(tO)
    error('hlest:forecast_re:origin', 'The origin is outside the filter range.');
end
H = o.horizon;
tEnd = tO + H;
F = struct('ok', false, 'status', 'ok', 't_origin', tO, 't_end', tEnd, 'horizon', H, 'q', {qlabels(tEnd)}, ...
    'names', {pb.yl}, 'check', NaN);
P = hlest.theta_struct(pb, th);
[ok, ss] = hlest.solve_orig(pb, P);
if ~ok
    F.status = 'no unique stable RE solution';
    return
end
nb = size(ss.Tb, 1);
ny = size(pb.Y, 1);
if isempty(o.origin_state)
    Q = ss.Rb*ss.Omg*ss.Rb';
    [a0, P0, ok] = hlest.init_state(ss.Tb, ss.Kb, (Q + Q')/2);
    if ~ok
        F.status = 'initial covariance';
        return
    end
    Y = NaN(ny, tEnd);
    nC = min(pb.nT, tO);
    Y(:, 1:nC) = pb.Y(:, 1:nC);
    [llt, ok, Fk] = hlest.kf(ss.Tb, ss.Rb, ss.Kb, ss.Z, ss.D, ss.Omg, Y, a0, P0, true);
    if ~ok
        F.status = 'prediction-error covariance not PD';
        return
    end
    A = Fk.a;
    if o.check
        [~, ok2, Ff] = hlest.kf(ss.Tb, ss.Rb, ss.Kb, ss.Z, ss.D, ss.Omg, pb.Y, a0, P0, true);
        assert(ok2, 'hlest:forecast_re: full-sample filter failed');
        F.check = max(max(abs(Ff.a(:, 1:tO) - A(:, 1:tO))));
        if ~(F.check < 1e-12)
            error('hlest:forecast_re:check', 'Filtered states up to the origin differ from the full-sample filter by %.3g.', ...
                F.check);
        end
    end
else
    A = NaN(nb, tEnd);
    A(:, tO) = o.origin_state(:);
    for t = tO + 1:tEnd
        A(:, t) = ss.Tb*A(:, t - 1) + ss.Kb;
    end
    llt = zeros(1, tEnd);
end
sc = pb.spec.report.scale;
cm = th(strcmp(pb.tab.name(1:pb.nstruct), 'constepinf'));
F.a = A;
F.y = ss.Z*A + ss.D;
F.yrep = F.y;
for i = 1:ny
    F.yrep(i, :) = F.y(i, :)*sc.(pb.yl{i});
end
F.fRE = ss.k + ss.c'*A;
F.fRE_rep = 4*(F.fRE + cm);
F.llt = llt;
F.origin_state = A(:, tO);
ipo = strcmp(pb.yl, 'pinfobs');
F.avg_pinf = mean(F.yrep(ipo, tO+1:tEnd));
F.ok = true;
end


function Q = qlabels(n)
Q = cell(1, n);
for t = 1:n
    Q{t} = sprintf('%dQ%d', 1965 + floor((t - 1)/4), mod(t - 1, 4) + 1);
end
end
