function [res, F] = core(ctx, m, H)
%CORE  History and forecast stages of one scenario, without saving (DESIGN 5).
%
%   res = hetlearn.engine.core(ctx, m, H)
%   [res, F] = hetlearn.engine.core(ctx, m, H)
%
%   Inputs
%     ctx  struct with
%            .opts         merged options (hetlearn.load_options)
%            .spec         model spec (hetlearn.load_spec)
%            .info         second output of hetlearn.load_model
%            .results_dir  folder holding results/<id>/ (for 'delta'
%                          references given as scenario ids)
%            .quiet        true to suppress progress lines
%          optional, history.mode = 'inversion' only:
%            .inv_snapshots  dates at which the inversion keeps its state,
%                          so that later calls can start there
%            .history_cache  F.history_cache of an earlier call with the
%                          same learning options and an inversion that
%                          covers this origin: the history is not
%                          recomputed (hetlearn.evaluate, delta references)
%     m    loaded model (hetlearn.load_model)
%     H    RE filter output (hetlearn.re_filter)
%
%   Output
%     res  struct with .cfg, .paths, .learning, .events, .state, .dates,
%          .meta (partial; hetlearn.run adds timing), .history_mode; with
%          'inversion' also .inversion (hetlearn.engine.history hinfo
%          without the snapshots); with 'kalman' also .kalman
%          (hetlearn.engine.kalman_history), see hetlearn.run.
%     F    forecast-stage bundle, to re-run the forecast stage from the same
%          origin state with other shocks (hetlearn.density.run):
%            .ctx   engine context (with share groups)
%            .S0    learning state at the end of the origin
%            .d0    starting databank (hetlearn.engine.build_shocks; with
%                   'inversion' the backed-out history over [start, origin])
%            .C     conditions by period (delta targets resolved)
%            .m     loaded model; .kStart, .recDates as in this run
%            .warm  first-period solved model of this run (fopt.warm of
%                   hetlearn.engine.forecast)
%            .history_cache  inversion only: state snapshots, record,
%                   events and backed-out databank (ctx.history_cache)
%
%   Steps: dates and checks; the engine.step flag in the model's user data
%   (field hetlearn_step, read by hetlearn.engine.solve_model);
%   hetlearn.engine.state_init; hetlearn.engine.history (history.mode =
%   'kalman': hetlearn.engine.kalman_history, whose filtered history then
%   replaces the RE-smoothed one, so the forecast starts from the filtered
%   state at the origin; (technical appendix, "The Kalman history"));
%   hetlearn.engine.build_shocks (with 'inversion' the backed-out history
%   then replaces the RE-smoothed one over [history.inversion.start,
%   origin], variables and shocks); reference runs for 'delta' conditions
%   (reference 'self' = this scenario with conditions removed and
%   compare_with emptied, not saved, sharing the inversion history; a
%   scenario id is read from results_dir/<id>/results.mat, run first if
%   missing); hetlearn.engine.conditions_prepare; hetlearn.engine.forecast;
%   hetlearn.engine.assemble.

o = ctx.opts;
info = ctx.info;
ctx.sys = info.sys;
ctx.learnVars = info.learnVars;
ctx.xList = info.xList;
ctx.yList = info.yList;
ctx.eList = info.eList;
ctx.blocks = hetlearn.plm.blocks(ctx.sys);      % PLM blocks of the projection facility (DESIGN 4.4)
if ~isfield(ctx, 'quiet')
    ctx.quiet = false;
end
invMode = strcmp(o.history.mode, 'inversion');
kalMode = strcmp(o.history.mode, 'kalman');     % time-varying Kalman filter of the ALM

% ---- dates -----------------------------------------------------------------------
if isempty(o.forecast.origin)
    error('hetlearn:engine:origin', 'forecast.origin must be set.');
end
origin = o.forecast.origin(1);
fr = H.range;
if double(origin) > double(fr(end)) + 1e-6 || double(origin) < double(fr(1)) + ctx.sys.maxlag - 1e-6
    error('hetlearn:engine:origin', 'forecast.origin %s is outside the filter range %s-%s.', ...
        char(dat2str(origin)), char(dat2str(fr(1))), char(dat2str(fr(end))));
end
ctx.origin = origin;
ctx.horizon = origin + 1 : origin + o.forecast.horizon;
initDate = o.beliefs.init.date;
if isempty(initDate)
    initDate = fr(1) + 4;
end
initDate = initDate(1);
if logical(o.history.learn)
    if double(initDate) > double(origin) + 1e-6
        error('hetlearn:engine:initDate', 'beliefs.init.date %s is after the origin %s.', ...
            char(dat2str(initDate)), char(dat2str(origin)));
    end
    if double(initDate) < double(fr(1)) + ctx.sys.maxlag - 1e-6
        error('hetlearn:engine:initDate', ...
            'beliefs.init.date %s leaves no room for %d PLM lag(s) after the filter start %s.', ...
            char(dat2str(initDate)), ctx.sys.maxlag, char(dat2str(fr(1))));
    end
    recDates = initDate : ctx.horizon(end);
    kStart = numel(initDate:origin);
else
    if invMode
        error('hetlearn:engine:inversion', 'history.mode = ''inversion'' needs history.learn = true.');
    end
    recDates = origin : ctx.horizon(end);
    kStart = 1;
end
ctx.init_date = initDate;
if invMode
    invStart = o.history.inversion.start;
    if isempty(invStart)
        invStart = initDate;
    end
    invStart = hetlearn.util.to_dates(invStart);
    invStart = invStart(1);
    if double(invStart) < double(initDate) - 1e-6 || double(invStart) > double(origin) + 1e-6
        error('hetlearn:engine:inversion', ...
            'history.inversion.start %s must lie in [beliefs.init.date %s, origin %s].', ...
            char(dat2str(invStart)), char(dat2str(initDate)), char(dat2str(origin)));
    end
    ctx.inv_start = invStart;
end

% ---- engine.step flag (fast state-space step or IRIS simulate) ---------------------
stepMode = 'iris';
if isfield(o, 'engine') && isfield(o.engine, 'step')
    stepMode = char(o.engine.step);
end
m = set_step_mode(m, stepMode);
cw = 'std';                         % engine.conditions_weighting, read by hetlearn.engine.step
if isfield(o, 'engine') && isfield(o.engine, 'conditions_weighting')
    cw = char(o.engine.conditions_weighting);
end
u = userdata(m);
if ~isstruct(u)
    u = struct();
end
if ~isfield(u, 'hetlearn_cond_weighting') || ~strcmp(u.hetlearn_cond_weighting, cw)
    u.hetlearn_cond_weighting = cw;
    m = userdata(m, u);
end

% ---- initial state and history ---------------------------------------------------
[S, ctx] = hetlearn.engine.state_init(ctx, m, H);
rec = hetlearn.engine.record([], numel(recDates), ctx);
t0 = tic;
dInv = [];
hinfo = struct();
hc = [];
if invMode && isfield(ctx, 'history_cache') && ~isempty(ctx.history_cache)
    [S, rec, evH, dInv, hinfo] = from_cache(ctx.history_cache, ctx, rec, origin);
    hc = ctx.history_cache;
elseif invMode
    [S, rec, evH, dInv, hinfo] = hetlearn.engine.history(ctx, S, H, rec, m);
    hc = struct('key', cache_key(o), 'init_date', double(initDate), 'start', double(ctx.inv_start), ...
        'origin', double(origin), 'rec', rec, 'ev', evH, 'd', dInv, ...
        'info', rmfield(hinfo, {'snapshots', 'warm'}), 'snapshots', hinfo.snapshots);
elseif kalMode
    [S, rec, evH, dInv, hinfo] = hetlearn.engine.kalman_history(ctx, S, H, rec, m);
else
    [S, rec, evH, ~, hinfo] = hetlearn.engine.history(ctx, S, H, rec, m);
end
tHist = toc(t0);
if ~ctx.quiet
    if invMode
        fprintf(['  history (inversion) %s-%s: %d periods, max observable miss %.2g, %d solves, ' ...
            '%d events, %.1f s%s\n'], char(dat2str(ctx.inv_start)), char(dat2str(origin)), ...
            numel(ctx.inv_start:origin), hinfo.max_obs_miss, hinfo.n_solve, numel(evH), toc(t0), ...
            ternary(isfield(hinfo, 'from_cache'), ' (cached)', ''));
    elseif kalMode
        fprintf('  history (kalman, %s start) %s-%s: %d quarters, log likelihood %.4f from %s, %d solves, %d events, %.1f s\n', ...
            hinfo.kalman.init, char(dat2str(hinfo.start)), char(dat2str(origin)), numel(hinfo.kalman.dates), ...
            hinfo.kalman.loglik, char(dat2str(initDate)), hinfo.n_solve, numel(evH), toc(t0));
    elseif logical(o.history.learn)
        fprintf('  history %s-%s: %d periods, %d events, %d ALM checks (%.1f s), %.1f s\n', ...
            char(dat2str(initDate)), char(dat2str(origin)), kStart, numel(evH), hinfo.alm_n_check, ...
            hinfo.alm_check_s, toc(t0));
    else
        fprintf('  history: no learning (initial state applies at %s)\n', char(dat2str(origin)));
    end
end

% ---- shocks, references, conditions ---------------------------------------------------
d = hetlearn.engine.build_shocks(ctx, H);
if invMode || kalMode
    if invMode
        rng = ctx.inv_start:origin;
    else
        rng = hinfo.db_start:origin;            % filtered history; the origin's state lags from a_{origin|origin}
    end
    nmAll = [ctx.xList(:); ctx.yList(:); ctx.eList(:)]';
    for i = 1:numel(nmAll)
        if isfield(dInv, nmAll{i})              % Ramsey multipliers are not in the rule-model history
            d.(nmAll{i})(rng) = dInv.(nmAll{i})(rng);
        end
    end
end
refs = struct();
cs = o.conditions;
for i = 1:numel(cs)
    if isfield(cs(i), 'type') && strcmp(char(cs(i).type), 'delta')
        ref = 'self';
        if isfield(cs(i), 'reference') && ~isempty(cs(i).reference)
            ref = char(cs(i).reference);
        end
        key = hetlearn.engine.conditions_key(ref);
        if isfield(refs, key)
            continue
        end
        if strcmp(ref, 'self')
            ctxR = ctx;
            ctxR.opts.conditions = o.conditions([]);
            ctxR.opts.compare_with = {};
            ctxR.quiet = true;
            if invMode
                ctxR.history_cache = hc;         % same history, not recomputed
            end
            if ~ctx.quiet
                fprintf('  reference run (self, no conditions) for delta conditions\n');
            end
            rr = hetlearn.engine.core(ctxR, m, H);
        else
            rr = hetlearn.engine.load_result(ref, ctx.results_dir, true);
        end
        refs.(key) = rr.paths;
    end
end
C = hetlearn.engine.conditions_prepare(ctx, refs);

% ---- forecast ----------------------------------------------------------------------------
F = struct('ctx', ctx, 'S0', S, 'd0', d, 'C', C, 'm', m, 'kStart', kStart, ...
    'recDates', recDates, 'warm', []);
if invMode
    F.history_cache = hc;
end
t0 = tic;
fopt = struct();
if isfield(hinfo, 'warm') && ~isempty(hinfo.warm)
    fopt.warm = hinfo.warm;             % the history's ALM check solved the origin's model
end
[S, rec, evF, d, finfo] = hetlearn.engine.forecast(ctx, S, d, rec, kStart, m, C, fopt);
F.warm = finfo.warm;
if ~ctx.quiet
    fprintf('  forecast %s-%s: %d periods, %d conditioned, %d events, %.1f s\n', ...
        char(dat2str(ctx.horizon(1))), char(dat2str(ctx.horizon(end))), numel(ctx.horizon), ...
        sum(arrayfun(@(c) ~isempty(c.vars), C)), numel(evF), toc(t0));
end

res = hetlearn.engine.assemble(ctx, d, rec, recDates, [evH, evF], S, H);
res.history_mode = o.history.mode;
res.meta.history_mode = o.history.mode;
res.meta.engine_step = stepMode;
res.meta.projection_facility = hetlearn.engine.facility('name', o);
res.meta.history_runtime_s = tHist;
res.meta.history_alm_check_s = 0;            % time of the history-stage ALM checks (DESIGN 4.4)
res.meta.history_alm_n_check = 0;
res.meta.history_alm_n_solve = 0;
if isfield(hinfo, 'alm_check_s')
    res.meta.history_alm_check_s = hinfo.alm_check_s;
    res.meta.history_alm_n_check = hinfo.alm_n_check;
    res.meta.history_alm_n_solve = hinfo.alm_n_solve;
end
res.meta.forecast_n_solve = finfo.n_solve;
if invMode
    hi = hinfo;
    hi = rmfield(hi, intersect({'snapshots', 'warm'}, fieldnames(hi)));
    res.inversion = hi;
end
if kalMode
    res.kalman = hinfo.kalman;
end
end


% =========================================================================
function m = set_step_mode(m, mode)
% engine.step in the model's user data; 'iris' also drops a cached system.
if ~any(strcmp(mode, {'fast', 'iris'}))
    error('hetlearn:engine:step', 'engine.step must be ''fast'' or ''iris'', not ''%s''.', mode);
end
u = userdata(m);
if ~isstruct(u)
    u = struct();
end
if isfield(u, 'hetlearn_step') && strcmp(u.hetlearn_step, mode)
    return
end
u.hetlearn_step = mode;
if strcmp(mode, 'iris') && isfield(u, 'hetlearn_sspace')
    u = rmfield(u, 'hetlearn_sspace');
end
m = userdata(m, u);
end


function k = cache_key(o)
% Options that determine the inversion history.
s = struct('expectations', o.expectations, 'beliefs', o.beliefs, 'gain', o.gain, ...
    'shares', o.shares, 'switching', o.switching, 'projection', o.projection, ...
    'inversion', o.history.inversion, 'model', o.model);
k = hetlearn.util.struct_key(s);
end


function [S, rec, evH, dInv, hinfo] = from_cache(hc, ctx, rec, origin)
% Start from a stored inversion state at the origin.
o = ctx.opts;
if ~strcmp(hc.key, cache_key(o)) || abs(hc.init_date - double(ctx.init_date)) > 1e-6 ...
        || abs(hc.start - double(ctx.inv_start)) > 1e-6
    error('hetlearn:engine:historyCache', ...
        'The inversion history cache was built with other learning options or dates.');
end
i = find(abs([hc.snapshots.date] - double(origin)) < 1e-6, 1);
if isempty(i)
    error('hetlearn:engine:historyCache', 'The inversion history cache has no state at %s.', ...
        char(dat2str(origin)));
end
S = hc.snapshots(i).S;
k = hc.snapshots(i).k;
fq = fieldnames(hc.rec.eq);       % phi, Rdiag, gain and the gain rule's series (gain_R)
for j = 1:numel(rec.eq)
    for q = 1:numel(fq)
        rec.eq(j).(fq{q})(:, 1:k) = hc.rec.eq(j).(fq{q})(:, 1:k);
    end
end
f = fieldnames(rec.var);
for j = 1:numel(f)
    g = fieldnames(rec.var.(f{j}));
    for q = 1:numel(g)
        rec.var.(f{j}).(g{q})(1:k) = hc.rec.var.(f{j}).(g{q})(1:k);
    end
end
evH = hc.ev;
if ~isempty(evH)
    evH = evH([evH.date] <= double(origin) + 1e-6);
end
dInv = hc.d;
hinfo = hc.info;
keep = double(hinfo.dates) <= double(origin) + 1e-6;
hinfo.dates = hinfo.dates(keep);
hinfo.params = hinfo.params(:, keep);
hinfo.obs_miss = hinfo.obs_miss(keep);
hinfo.n_obs = hinfo.n_obs(keep);
hinfo.max_obs_miss = max([0, hinfo.obs_miss]);
hinfo.origin = origin;
hinfo.from_cache = true;
hinfo.warm = [];                 % the forecast's first period solves (no model kept in the cache)
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
