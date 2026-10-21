function [S, rec, ev, dInv, hinfo] = history(ctx, S, H, rec, m)
%HISTORY  History stage: learning on the RE-smoothed history (DESIGN 5.2) or the inversion (DESIGN 15).
%
%   [S, rec, ev, dInv, hinfo] = hetlearn.engine.history(ctx, S, H, rec, m)
%
%   Inputs
%     ctx  engine context (.opts, .sys, .learnVars, .init_date, .origin,
%          .spec, .info; inversion also .xList, .yList, .eList, .inv_start
%          and optionally .inv_snapshots, dates at which to keep the state)
%     S    initial state (hetlearn.engine.state_init)
%     H    RE filter output (hetlearn.re_filter)
%     rec  allocated record (hetlearn.engine.record)
%     m    loaded model (hetlearn.load_model), the model of the forecast
%          stage; needed for the inversion and for the ALM check
%          (projection.facility 'alm' | 'plm_alm'); may be [] otherwise
%
%   Outputs
%     S      state at the end of the origin period (phi_origin, n1_origin,
%            forecasts of x_{origin+1} made at the origin)
%     rec    record filled for the history periods (index 1 = first period)
%     ev     events (projection facility; inversion also 'explosive'
%            periods)
%     dInv   inversion only: databank of every transition and measurement
%            variable and shock, RE-smoothed before inv_start, backed out
%            over [inv_start, origin]; [] for 're_smoother'
%     hinfo  .alm_check_s (time spent in the ALM checks), .alm_n_check,
%            .alm_n_solve, .warm (struct('pv', pv, 'm', m): the forecast
%            model solved at the origin by the last ALM check, [] if none);
%            inversion also .start, .origin, .dates, .shocks (endogenised),
%            .observables, .param_names, .params (parameter values in the
%            model, one column per period), .n_obs and .obs_miss (per
%            period), .max_obs_miss, .shock_diff_vs_smoothed (max abs
%            difference of the backed-out shocks from the RE-smoothed ones),
%            .path_diff_vs_smoothed (same for the variables, x_exp1_BR
%            excluded), .n_solve, .n_fast (periods on the fast step),
%            .runtime_s, .pre_dates, .snapshots (struct array date, k, S at
%            ctx.inv_snapshots and the origin)
%
%   history.mode = 're_smoother', history.learn = true: for t = init_date ..
%     origin, with D = H.smooth (history.re_states = 'smoothed', default:
%     the two-sided smoother) or D = H.filtered ('filtered': the one-sided
%     filter, x_{t|t} from data up to t; hetlearn.engine.history_db):
%     f^RE_t(x) = D.<x>_exp1_RE(t); f^BR_t(x) =
%     hetlearn.plm.forecast_value(sys, phi_{t-1}, getLag, x) with
%     getLag(name, k) = D.<name>(t+k): k <= -1 for beliefs.info =
%     'lagged'; k <= 0 for 'current', so the BR forecast made in t uses x_t
%     from that history (sys.info; IJCB eq. 12); then
%     hetlearn.engine.update_learning, whose realised x_t also comes from D
%     (no errors at t = init_date; FE_t
%     and the RLS update are the same for both information sets). The
%     model is not simulated here, so under projection.facility 'alm' and
%     'plm_alm' it is solved each period only to check the ALM of
%     (phi_t, n_t), the model that would be in force in t+1 (DESIGN 4.4):
%     the history model (the rule model of a Ramsey scenario) before the
%     origin, the forecast model at the origin; the solve is skipped when
%     every BR model share is 0. Under 'none' nothing is solved.
%   history.learn = false: no loop; the initial beliefs and shares apply at
%   the origin and f^i_origin come from the same formulas at t = origin
%   (from D as above).
%
%   history.mode = 'inversion' (DESIGN 15): learning on the RE-smoothed
%   history over [init_date, inv_start - 1] (empty by default, inv_start =
%   init_date), then for t = inv_start .. origin a forecast period (DESIGN
%   5.3) with conditions: (1) belief parameters from phi_{t-1}, shares from
%   hetlearn.engine.shares_for_mode; (2) assign and solve unless the
%   parameters equal those of the last solve or ALM check, with the
%   projection facility (hetlearn.engine.facility 'solve'); (3)
%   hetlearn.engine.step with every observable that has data at t
%   exogenised at its value and history.inversion.shocks endogenised
%   (default: the transition shocks; exactly determined or minimum norm);
%   (4) all variables at t stored; f^RE_t = <x>_exp1_RE(t), f^BR_t =
%   <x>_exp1_BR(t) from the model, the BR one asserted equal to the PLM
%   forecast with phi_{t-1} (1e-9); (5) hetlearn.engine.update_learning
%   with the ALM check (first = true only when inv_start = init_date). The
%   state before inv_start is the RE-smoothed one. Period t uses data up to
%   t only, so history.re_states does not apply: 'filtered' with
%   'inversion' is an error (hetlearn.load_options; checked here too).

if nargin < 5
    m = [];
end
lv = ctx.learnVars;
sys = ctx.sys;
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
dInv = [];
if ~isfield(ctx, 'blocks') || isempty(ctx.blocks)
    ctx.blocks = hetlearn.plm.blocks(sys);
end

if strcmp(ctx.opts.history.mode, 'inversion')
    if isfield(ctx.opts.history, 're_states') && strcmp(ctx.opts.history.re_states, 'filtered')
        error('hetlearn:engine:history', ['history.re_states = ''filtered'' applies to history.mode = ' ...
            '''re_smoother'' only (the inversion is one-sided by construction).']);
    end
    [S, rec, ev, dInv, hinfo] = inversion(ctx, S, H, rec, m);
    return
end
sm = hetlearn.engine.history_db(ctx.opts, H);   % H.smooth, or H.filtered under history.re_states = 'filtered'

hinfo = alm_info();
if ~logical(ctx.opts.history.learn)
    t = ctx.origin;
    getVal = @(name, k) sm.(name)(t + k);
    if hetlearn.engine.ntypes('on', ctx)       % N agent types (DESIGN_br_extensions 1.1)
        [F, X] = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, 'history', t);
        S = hetlearn.engine.ntypes('store', ctx, S, F, X);
        rec = hetlearn.engine.record(rec, 1, ctx, S, hetlearn.engine.ntypes('no_update', ctx), []);
        return
    end
    for i = 1:numel(lv)
        x = lv{i};
        S.fRE.(x) = sm.([x '_exp1_RE'])(t);
        S.fBR.(x) = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
    end
    out = struct('FE_RE', struct(), 'FE_BR', struct(), 'gain', struct());
    for i = 1:numel(lv)
        out.FE_RE.(lv{i}) = NaN;
        out.FE_BR.(lv{i}) = NaN;
    end
    for i = 1:numel(sys.eq)
        out.gain.(sys.eq(i).target) = NaN;
    end
    rec = hetlearn.engine.record(rec, 1, ctx, S, out, []);
    return
end

[mH, mF] = check_models(ctx, m);
dates = ctx.init_date:ctx.origin;
[S, rec, ev, hinfo] = smoothed_loop(ctx, S, sm, rec, dates, 0, mH, mF, hinfo);
end


% =========================================================================
function h = alm_info()
h = struct('alm_check_s', 0, 'alm_n_check', 0, 'alm_n_solve', 0, 'warm', []);
end


function [mH, mF] = check_models(ctx, m)
% Models for the ALM checks: mH before the origin (the history model: the
% rule model of a Ramsey scenario; no fast-step system is built for it), mF
% at the origin (the forecast model, solved for the forecast's first period).
mH = [];
mF = m;
if strcmp(hetlearn.engine.facility('name', ctx.opts), 'none') || isempty(m)
    return
end
mH = m;
if isfield(ctx, 'info') && isfield(ctx.info, 'policy') && isstruct(ctx.info.policy) ...
        && isfield(ctx.info.policy, 'ramsey') && logical(ctx.info.policy.ramsey) ...
        && ~isempty(ctx.info.policy.rule_model)
    mH = ctx.info.policy.rule_model;
end
u = userdata(mH);
if ~isstruct(u)
    u = struct();
end
u.hetlearn_step = 'iris';
if isfield(u, 'hetlearn_sspace')
    u = rmfield(u, 'hetlearn_sspace');
end
mH = userdata(mH, u);
end


function [S, rec, ev, h] = smoothed_loop(ctx, S, sm, rec, dates, k0, mH, mF, h)
% Learning on the RE history sm over dates (record indices k0 + k), with the
% ALM check of each period's update when mH is given. sm = H.smooth, or
% H.filtered under history.re_states = 'filtered' (never in the inversion).
lv = ctx.learnVars;
sys = ctx.sys;
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
origin = double(ctx.origin);
for k = 1:numel(dates)
    t = dates(k);
    getVal = @(name, j) sm.(name)(t + j);
    if hetlearn.engine.ntypes('on', ctx)       % N agent types: every type's forecast (DESIGN_br_extensions 1.1)
        [fRE, fBR] = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, 'history', t);   % fBR: before the transforms (P4)
    else
        fRE = struct();
        fBR = struct();
        for i = 1:numel(lv)
            x = lv{i};
            fRE.(x) = sm.([x '_exp1_RE'])(t);
            fBR.(x) = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
        end
    end
    A = [];
    atOrigin = abs(double(t) - origin) < 1e-6;
    if ~isempty(mH)
        if atOrigin
            A = struct('m', mF, 'stage', 'history');
        else
            A = struct('m', mH, 'stage', 'history');
        end
    end
    [S, out, e] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, k0 + k == 1, A);
    ev = [ev, e]; %#ok<AGROW>
    if ~isempty(out.alm)
        h.alm_check_s = h.alm_check_s + out.alm.time;
        if out.alm.checked
            h.alm_n_check = h.alm_n_check + 1;
            h.alm_n_solve = h.alm_n_solve + out.alm.n_solve;
            if atOrigin
                h.warm = struct('pv', out.alm.pv, 'm', out.alm.m);
            else
                mH = out.alm.m;
            end
        end
    end
    rec = hetlearn.engine.record(rec, k0 + k, ctx, S, out, []);
end
end


% =========================================================================
function [S, rec, ev, d, hinfo] = inversion(ctx, S, H, rec, m)
tAll = tic;
o = ctx.opts;
sys = ctx.sys;
lv = ctx.learnVars;
sm = H.smooth;
start = ctx.inv_start;
origin = ctx.origin;
xl = ctx.xList;
yl = ctx.yList;
el = ctx.eList;
mF = m;                          % forecast model (ALM check at the origin)
if isfield(ctx.info, 'policy') && isstruct(ctx.info.policy) && isfield(ctx.info.policy, 'ramsey') ...
        && logical(ctx.info.policy.ramsey) && ~isempty(ctx.info.policy.rule_model)
    % Ramsey scenarios (DESIGN 13): the history is always the rule-based model
    m = ctx.info.policy.rule_model;
    xl = cellstr(get(m, 'xList'));
    yl = cellstr(get(m, 'yList'));
    el = cellstr(get(m, 'eList'));
end
doAlm = ~strcmp(hetlearn.engine.facility('name', o), 'none');
h = alm_info();

% ---- (a) learning on the RE-smoothed history before the inversion start ----------------
pre = [];
if double(start) > double(ctx.init_date) + 1e-6
    pre = ctx.init_date : start - 1;
end
mH = [];
if doAlm
    mH = m;
end
[S, rec, ev, h] = smoothed_loop(ctx, S, sm, rec, pre, 0, mH, mH, h);
k0 = numel(pre);

% ---- (b) observables, data, endogenised shocks ------------------------------------------
obs = reshape(cellstr(ctx.spec.observables), 1, []);
data = [];
if isfield(H, 'data') && isstruct(H.data) && all(isfield(H.data, obs))
    data = H.data;
else
    data = hetlearn.load_database(ctx.spec);
end
missing = obs(~isfield(data, obs));
if ~isempty(missing)
    error('hetlearn:engine:inversion', 'No data for observable(s) %s.', strjoin(missing, ', '));
end
shk = reshape(cellstr(o.history.inversion.shocks), 1, []);
if isempty(shk) || (numel(shk) == 1 && isempty(shk{1}))
    shk = transition_shocks(m, el);
end
bad = setdiff(shk, el);
if ~isempty(bad)
    error('hetlearn:engine:inversion', 'history.inversion.shocks names unknown shock(s): %s.', ...
        strjoin(bad, ', '));
end
if numel(shk) < numel(obs)
    error('hetlearn:engine:inversion', ...
        'history.inversion.shocks: %d shocks for %d observables (need at least as many shocks).', ...
        numel(shk), numel(obs));
end

% ---- (c) starting databank: RE-smoothed history up to start-1, zero shocks after ---------
names = [xl(:); yl(:)]';
d = struct();
for n = [names, reshape(el, 1, [])]
    x = sm.(n{1});
    d.(n{1}) = clip(x, x.Start, start - 1);
end
dates = start:origin;
for j = 1:numel(el)
    d.(el{j})(dates) = 0;
end

% ---- (d) period loop ----------------------------------------------------------------------
nT = numel(dates);
n1m = hetlearn.engine.shares_for_mode(ctx, S);
pnames = reshape(fieldnames(hetlearn.engine.facility('params', sys, S.phi, lv, n1m)), 1, []);
params = NaN(numel(pnames), nT);
obsMiss = zeros(1, nT);
nObs = zeros(1, nT);
snapDates = origin;
if isfield(ctx, 'inv_snapshots') && ~isempty(ctx.inv_snapshots)
    snapDates = [reshape(double(ctx.inv_snapshots), 1, []), double(origin)];
end
snaps = struct('date', {}, 'k', {}, 'S', {});
lastP = [];
if ~isempty(h.warm)                                  % the pre-inversion loop checked this model
    lastP = h.warm.pv;
    m = h.warm.m;
    h.warm = [];
end
nSolve = 0;
nFast = 0;
for k = 1:nT
    t = dates(k);
    % (1) parameters
    n1m = hetlearn.engine.shares_for_mode(ctx, S);
    P = hetlearn.engine.facility('params', sys, S.phi, lv, n1m);
    pv = cell2mat(struct2cell(P));
    % (2) solve with the projection facility
    if isempty(lastP) || ~isequal(pv, lastP)
        [m, S, r, e] = hetlearn.engine.facility('solve', ctx, m, S, n1m, t, 'inversion');
        n1m = r.n1m;                    % model shares in force in t (kept ones included)
        ev = [ev, e]; %#ok<AGROW>
        nSolve = nSolve + r.n_solve;
        if r.reverted && k0 + k - 1 >= 1
            for i = 1:numel(sys.eq)              % beliefs in force in t after the revert
                tg = sys.eq(i).target;
                rec.eq(i).phi(:, k0 + k - 1) = S.phi.(tg);
                rec.eq(i).Rdiag(:, k0 + k - 1) = diag(S.R.(tg));
            end
        end
        pv = r.pv;
        lastP = pv;
    end
    params(:, k) = pv;
    % (3) one period with every observable exogenised at its data value
    vals = NaN(numel(obs), 1);
    for i = 1:numel(obs)
        vals(i) = data.(obs{i})(t);
    end
    has = isfinite(vals);
    cond = struct('vars', {obs(has)}, 'shocks', {shk}, 'targets', vals(has));
    [s, d, stepInfo] = hetlearn.engine.step(m, d, t, cond);
    ev = [ev, stepInfo.events]; %#ok<AGROW>
    obsMiss(k) = stepInfo.maxerr;
    nObs(k) = sum(has);
    % (4) store; forecasts made in t; timing check
    if stepInfo.fast
        d = s;                       % s = d with every variable and shock at t set
        nFast = nFast + 1;
    else
        for i = 1:numel(names)
            d.(names{i})(t) = s.(names{i})(t);
        end
    end
    getVal = @(name, j) d.(name)(t + j);
    fRE = struct();
    fBR = struct();
    for i = 1:numel(lv)
        x = lv{i};
        fRE.(x) = d.([x '_exp1_RE'])(t);
        fBR.(x) = d.([x '_exp1_BR'])(t);
        chk = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
        if ~(abs(chk - fBR.(x)) < 1e-9)
            error('hetlearn:engine:timing', ...
                ['Inversion period %s: %s_exp1_BR from the model (%.12g) differs from the PLM ' ...
                'forecast with phi_{t-1} (%.12g, beliefs.info = ''%s'').'], char(dat2str(t)), x, ...
                fBR.(x), chk, sys.info);
        end
    end
    % (5) learning update with the ALM check of the model in force in t+1
    A = [];
    atOrigin = k == nT;
    if doAlm
        if atOrigin
            A = struct('m', mF, 'stage', 'inversion');
        else
            A = struct('m', m, 'stage', 'inversion');
        end
    end
    [S, out, e] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, k == 1 && k0 == 0, A);
    ev = [ev, e]; %#ok<AGROW>
    if ~isempty(out.alm)
        h.alm_check_s = h.alm_check_s + out.alm.time;
        if out.alm.checked
            h.alm_n_check = h.alm_n_check + 1;
            h.alm_n_solve = h.alm_n_solve + out.alm.n_solve;
            nSolve = nSolve + out.alm.n_solve;
            if atOrigin
                h.warm = struct('pv', out.alm.pv, 'm', out.alm.m);
            else
                m = out.alm.m;
                lastP = out.alm.pv;
            end
        end
    end
    rec = hetlearn.engine.record(rec, k0 + k, ctx, S, out, n1m);
    if any(abs(snapDates - double(t)) < 1e-6)
        snaps(end+1) = struct('date', double(t), 'k', k0 + k, 'S', S); %#ok<AGROW>
    end
end

% ---- (e) diagnostics against the RE smoother ------------------------------------------------
dsh = 0;
for j = 1:numel(shk)
    a = d.(shk{j})(dates);
    b = sm.(shk{j})(dates);
    dsh = max([dsh; abs(a(:) - b(:))]);
end
dpath = 0;
for i = 1:numel(names)
    if numel(names{i}) > 8 && strcmp(names{i}(end-7:end), '_exp1_BR')
        continue
    end
    a = d.(names{i})(dates);
    b = sm.(names{i})(dates);
    dpath = max([dpath; abs(a(:) - b(:))]);
end
hinfo = h;
hinfo.start = start;
hinfo.origin = origin;
hinfo.dates = dates;
hinfo.shocks = shk;
hinfo.observables = obs;
hinfo.param_names = pnames;
hinfo.params = params;
hinfo.n_obs = nObs;
hinfo.obs_miss = obsMiss;
hinfo.max_obs_miss = max([0, obsMiss]);
hinfo.shock_diff_vs_smoothed = dsh;
hinfo.path_diff_vs_smoothed = dpath;
hinfo.n_solve = nSolve;
hinfo.n_fast = nFast;
hinfo.runtime_s = toc(tAll);
hinfo.pre_dates = pre;
hinfo.snapshots = snaps;
end


% =========================================================================
function shk = transition_shocks(m, eList)
% Transition shocks of the model (the default endogenised set).
shk = {};
try
    shk = reshape(cellstr(access(m, 'transition-shocks')), 1, []);
catch
end
if isempty(shk)
    shk = reshape(cellstr(eList), 1, []);
end
end
