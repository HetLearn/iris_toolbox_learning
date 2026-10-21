function [S, rec, ev, d, finfo] = forecast(ctx, S, d, rec, kStart, m, C, fopt)
%FORECAST  Forecast/scenario stage, period by period (DESIGN 5.3).
%
%   [S, rec, ev, d] = hetlearn.engine.forecast(ctx, S, d, rec, kStart, m, C)
%   [S, rec, ev, d, finfo] = hetlearn.engine.forecast(ctx, S, d, rec, kStart, m, C, fopt)
%
%   Inputs
%     ctx     engine context (.opts, .spec, .sys, .learnVars, .horizon,
%             .xList, .yList, .eList; .blocks optional)
%     S       state at the end of the origin (hetlearn.engine.history)
%     d       databank: RE-smoothed history up to the origin plus the
%             scenario shocks over the horizon (hetlearn.engine.build_shocks)
%     rec     record; the forecast periods go to rec indices kStart+1 ..
%     kStart  record index of the origin (0 with a record of H periods)
%     m       loaded model (hetlearn.load_model)
%     C       1 x H struct array of conditions by period
%             (hetlearn.engine.conditions_prepare)
%     fopt    optional struct, for repeated calls from the same origin state
%             (density draws, hetlearn.density.run) and for the model the
%             history stage solved at the origin (hetlearn.engine.core):
%               .warm    struct('pv', pv, 'm', m): if this call's
%                        first-period parameter vector equals warm.pv, the
%                        solved model warm.m is used and assign/solve are
%                        skipped (same parameters, same solution)
%
%   Outputs
%     S, rec  state at the end of the horizon, filled record
%     ev      events (projection facility, 'explosive' periods)
%     d       databank with the scenario over the horizon
%     finfo   .warm = struct('pv', pv, 'm', m) of the first period (to pass
%             as fopt.warm), .n_solve (solve calls, ALM checks included)
%
%   Each period t: (1) belief parameters from phi_{t-1}
%   (hetlearn.plm.param_values), n1_<x> from hetlearn.engine.shares_for_mode,
%   n2_<x> = 1 - n1_<x>; (2) solve unless the parameters equal those of the
%   last solve (the ALM check at the end of t-1 has normally solved this
%   model already): hetlearn.engine.facility('solve', ...) - under
%   projection.facility = 'none' a model without a solution is the error
%   hetlearn:engine:noSolution (a linear model without leads is simulated
%   as is by the backward system); under 'alm' and 'plm_alm' an unstable
%   ALM reverts every belief to its value before the last update and, if
%   that is not enough, keeps the previous quarter's model shares (the
%   record of t-1 is rewritten) or, with no earlier solved model, stops
%   (hetlearn:engine:almUnstable);
%   (3) hetlearn.engine.step; (4) store all variables at t in d; f^RE_t =
%   <x>_exp1_RE(t), f^BR_t = <x>_exp1_BR(t), asserted equal to
%   hetlearn.plm.forecast_value with phi_{t-1} and data from d on the
%   information set of sys.info (beliefs.info: 'lagged' = up to t-1;
%   'current' = up to t, using the x_t just stored; 1e-9, catches timing
%   errors); (5) hetlearn.engine.update_learning with the ALM check of the
%   model in force in t+1 ('alm', 'plm_alm'; DESIGN 4.4), whose solved
%   model the next period reuses.
%
%   Ramsey policy (DESIGN 13): hetlearn.policy.forecast_setup first sets the
%   Lagrange multipliers to 0 at and before the origin (the plan starts
%   there); their values are stored every period like any transition
%   variable, so their lags carry forward. Conditions whose endogenised
%   shocks only drive the rule (e.g. em) keep only rule-only targets (ms).

if nargin < 8 || isempty(fopt)
    fopt = struct();
end
warm = [];
if isfield(fopt, 'warm')
    warm = fopt.warm;
end
sys = ctx.sys;
lv = ctx.learnVars;
hz = ctx.horizon;
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
names = [ctx.xList(:); ctx.yList(:)]';
finfo = struct('warm', [], 'n_solve', 0);
if ~isfield(ctx, 'blocks') || isempty(ctx.blocks)
    ctx.blocks = hetlearn.plm.blocks(sys);
end
doAlm = ~strcmp(hetlearn.engine.facility('name', ctx.opts), 'none');
lastP = [];
[d, C] = hetlearn.policy.forecast_setup(ctx, d, C);     % Ramsey: multipliers 0 up to the origin
isNT = hetlearn.engine.ntypes('on', ctx);              % N agent types (DESIGN_br_extensions 1.1)
if isNT
    d = hetlearn.engine.ntypes('seed', ctx, S, d, hz(1) - 1);   % rule types' own lagged forecasts
end
for k = 1:numel(hz)
    t = hz(k);
    % (1) parameters
    n1m = hetlearn.engine.shares_for_mode(ctx, S);
    P = hetlearn.engine.facility('params', sys, S.phi, lv, n1m, ...
        hetlearn.engine.anchor_update('params', ctx, S));     % level coefficients in force (phase P4)
    pv = cell2mat(struct2cell(P));
    if k == 1 && ~isempty(warm) && isequal(pv, warm.pv)
        m = warm.m;                     % solved for these parameters by an earlier call
        lastP = pv;
    end
    % (2) solve with the projection facility
    if isempty(lastP) || ~isequal(pv, lastP)
        [m, S, r, e] = hetlearn.engine.facility('solve', ctx, m, S, n1m, t, 'forecast');
        n1m = r.n1m;                    % model shares in force in t (kept ones included)
        ev = [ev, e]; %#ok<AGROW>
        finfo.n_solve = finfo.n_solve + r.n_solve;
        if r.reverted && kStart + k - 1 >= 1
            rec = rerecord(rec, kStart + k - 1, sys, S);     % beliefs in force in t after the revert
        end
        pv = r.pv;
        lastP = pv;
    end
    if k == 1
        finfo.warm = struct('pv', pv, 'm', m);
    end
    % (3) one-period simulation with shocks and conditions
    [s, d, stepInfo] = hetlearn.engine.step(m, d, t, C(k));
    ev = [ev, stepInfo.events]; %#ok<AGROW>   % 'explosive' when the backward system was used (DESIGN 11)
    % (4) store and read the forecasts made in t
    for i = 1:numel(names)
        d.(names{i})(t) = s.(names{i})(t);
    end
    getVal = @(name, j) d.(name)(t + j);
    if isNT
        % asserts the PLM, rule, level and re_mean types; fRE = the forecasts as they enter the aggregate,
        % fBR = the forecasts before the transforms (phase P4)
        [fRE, fBR] = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, 'model', t);
    else
        fRE = struct();
        fBR = struct();
        for i = 1:numel(lv)
            x = lv{i};
            fRE.(x) = d.([x '_exp1_RE'])(t);
            fBR.(x) = d.([x '_exp1_BR'])(t);
            chk = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
            if ~(abs(chk - fBR.(x)) < 1e-9)
                error('hetlearn:engine:timing', ...
                    ['Period %s: %s_exp1_BR from the model (%.12g) differs from the PLM ' ...
                    'forecast with phi_{t-1} (%.12g, beliefs.info = ''%s'').'], char(dat2str(t)), x, ...
                    fBR.(x), chk, sys.info);
            end
        end
    end
    % (5) learning update with the projection facility (ALM check of the model in t+1)
    A = [];
    if doAlm
        A = struct('m', m, 'stage', 'forecast');
    end
    [S, out, e] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, false, A);
    ev = [ev, e]; %#ok<AGROW>
    if ~isempty(out.alm) && out.alm.checked
        m = out.alm.m;                  % solved with the beliefs and shares of t+1
        lastP = out.alm.pv;
        finfo.n_solve = finfo.n_solve + out.alm.n_solve;
    end
    rec = hetlearn.engine.record(rec, kStart + k, ctx, S, out, n1m);
end
end


function rec = rerecord(rec, k, sys, S)
% Beliefs of record entry k after an ALM revert at the start of the next period.
for i = 1:numel(sys.eq)
    tg = sys.eq(i).target;
    rec.eq(i).phi(:, k) = S.phi.(tg);
    rec.eq(i).Rdiag(:, k) = diag(S.R.(tg));
end
end
