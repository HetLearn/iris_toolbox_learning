function [d, rec, ev] = fast_path(F, d)
%FAST_PATH  One density draw for mode 'rational' without conditions (DESIGN 14).
%
%   [d, rec, ev] = hetlearn.density.fast_path(F, d)
%
%   Inputs
%     F  forecast-stage bundle (hetlearn.engine.core); F.m is the loaded RE
%        model (every n1 = 1, belief parameters 0), F.S0 the learning state
%        at the end of the origin
%     d  databank: history up to the origin, scenario shocks plus the draw
%        over the horizon
%
%   Outputs
%     d    databank with the simulated horizon
%     rec  record of the forecast periods (indices 1..H), laid out as by
%          hetlearn.engine.forecast with kStart = 0
%     ev   events of the learning diagnostics (projection facility)
%
%   With every n1 = 1 the solution does not depend on beliefs or shares
%   except through <x>_exp1_BR, which feeds nothing else. One
%   simulate(F.m, d, horizon, 'anticipate', false, 'prependInput', true)
%   therefore gives every other variable of the period-by-period run (DESIGN
%   5.3: rational = one unanticipated simulate). The learning state is then
%   replayed on the simulated path as in hetlearn.engine.forecast:
%   f^RE_t = <x>_exp1_RE(t), f^BR_t = hetlearn.plm.forecast_value(sys,
%   phi_{t-1}, lags) (also written into <x>_exp1_BR), then
%   hetlearn.engine.update_learning; n1_model = 1. Equal to the general path
%   up to rounding (tests/test_density.m, D4).

ctx = F.ctx;
hz = ctx.horizon;
sys = ctx.sys;
lv = ctx.learnVars;
s = simulate(F.m, d, hz, 'anticipate', false, 'prependInput', true);
names = [ctx.xList(:); ctx.yList(:)]';
for i = 1:numel(names)
    d.(names{i})(hz) = s.(names{i})(hz);
end
S = F.S0;
rec = hetlearn.engine.record([], numel(hz), ctx);
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
n1m = struct();
for i = 1:numel(lv)
    n1m.(lv{i}) = 1;
end
for k = 1:numel(hz)
    t = hz(k);
    getVal = @(name, j) d.(name)(t + j);
    fRE = struct();
    fBR = struct();
    for i = 1:numel(lv)
        x = lv{i};
        fRE.(x) = d.([x '_exp1_RE'])(t);
        fBR.(x) = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
        d.([x '_exp1_BR'])(t) = fBR.(x);
    end
    getVal = @(name, j) d.(name)(t + j);
    [S, out, e] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, false);
    ev = [ev, e]; %#ok<AGROW>
    rec = hetlearn.engine.record(rec, k, ctx, S, out, n1m);
end
end
