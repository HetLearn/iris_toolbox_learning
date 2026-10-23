function [D, cols] = run(F, res, H)
%RUN  Density forecast: shock draws on top of the scenario, forecast stage per draw (DESIGN 14).
%
%   D = hetlearn.density.run(F, res, H)
%   [types, cols] = hetlearn.density.run('event_types')   engine event types
%                   counted per draw and their column names, in the fixed
%                   order of D.events and density_events.csv
%
%   Called by hetlearn.run when density.enabled is true; the history stage
%   has run once (hetlearn.engine.core), every draw re-runs only the forecast
%   stage from the same origin state.
%
%   Inputs
%     F    forecast-stage bundle, second output of hetlearn.engine.core
%          (.ctx, .S0, .d0, .C, .m, .warm)
%     res  the point forecast of the same run (first output of core)
%     H    RE filter output (smoothed shocks for sigma 'smoothed' and method
%          'bootstrap')
%
%   Output D (struct; hetlearn.engine.save_results writes it through
%   hetlearn.density.write_outputs)
%     .id, .options (the density options), .dates (horizon), .quantiles (p)
%     .path       'fast' or 'general' (below)
%     .draw_info  hetlearn.density.draws info: shocks, dates, sigma, method,
%                 sigma_range, pool and drawn rows for 'bootstrap'
%     .names      series summarised: every observable of spec.observables,
%                 then per learning variable x: n2_model_<x> (1 - the RE share
%                 used in the model in t) and its belief parameters
%                 (sys.eq param_names, e.g. alpha_x, beta_x). N agent types
%                 and forecast transforms (ctx.nt): per learning
%                 variable x, n_model_<k>_<x> (the model share of type k in
%                 t) for every type k of x, then the belief parameters of
%                 each learning type's PLM equation of x (names with the
%                 suffix __<k>, e.g. alpha_pinf__BR; for a 're_mean' type the
%                 equation of <x>_feRE)
%     .series.<name>  .q (H x numel(p), model units), .mean, .std, .point
%                 (the scenario run), .scale (spec.report.scale.<name>, 1 if
%                 none; 1 for learning series), .q_report, .mean_report,
%                 .point_report (x scale), .kind ('observable' | 'learning')
%     .ndraws, .n_used, .n_explosive, .n_error, .used (1 x N logical)
%     .events     table, one row per draw: draw, status ('ok' | 'explosive' |
%                 'error'), then the counts of the engine events of that
%                 draw in a fixed order (hetlearn.density.run('event_types')):
%                 projection_plm, projection_alm, projection_alm_shares,
%                 explosive_events,
%                 rls_missing, shares_nan, gain_bound; then max_abs, message
%                 (the error text of an 'error' draw, e.g. an
%                 hetlearn:engine:almUnstable stop)
%     .runtime_s, .s_per_draw
%     .draws      (density.keep_draws) .series.<name> H x N (model units),
%                 .shocks nT x nS x N (the draws added)
%
%   Paths. 'fast' when density.fast_path, mode 'rational', no conditions and
%   the two-type engine (no N agent types): hetlearn.density.fast_path (one
%   IRIS simulate over the horizon per draw, learning diagnostics replayed on
%   the simulated path). Otherwise
%   'general': hetlearn.engine.forecast(F.ctx, F.S0, d_draw, ...) per draw,
%   with fopt.warm = F.warm (the point forecast's period-1 solve is reused:
%   every draw starts from the same beliefs and shares).
%
%   The draws (hetlearn.density.draws) are ADDED to the scenario's own
%   shocks at their dates; conditions stay in force, so the endogenised
%   shocks still put the conditioned variables on target in every draw.
%   A draw with a non-finite value or |value| > 1e6 in any summarised series
%   is 'explosive' and a draw whose forecast stage errors is 'error'; both
%   are excluded from the quantiles and counted. Quantiles:
%   hetlearn.density.quantile.

if ischar(F) && strcmp(F, 'event_types')
    [D, cols] = event_types();
    return
end
cols = {};
tAll = tic;
LIMIT = 1e6;
ctx = F.ctx;
o = ctx.opts.density;
spec = ctx.spec;
hz = ctx.horizon;
nH = numel(hz);
quiet = isfield(ctx, 'quiet') && logical(ctx.quiet);
p = reshape(double(o.quantiles), 1, []);

[E, info] = hetlearn.density.draws(F, H);
N = size(E, 3);

% ---- series to summarise -------------------------------------------------------------
obs = spec.observables(ismember(spec.observables, fieldnames(res.paths)));
lv = ctx.learnVars;
sys = ctx.sys;
isNT = hetlearn.engine.ntypes('on', ctx);       % N agent types, forecast transforms
% share: '' = 1 - n1_model (two types), else the record field of a type's model share; lkey: the
% res.learning entry of the point value
spc = struct('name', {}, 'kind', {}, 'var', {}, 'eq', {}, 'row', {}, 'share', {}, 'lkey', {});
for i = 1:numel(obs)
    spc(end+1) = struct('name', obs{i}, 'kind', 'observable', 'var', obs{i}, 'eq', 0, 'row', 0, ...
        'share', '', 'lkey', ''); %#ok<AGROW>
end
if isNT
    spc = nt_series(spc, ctx);
else
    for i = 1:numel(lv)
        x = lv{i};
        spc(end+1) = struct('name', ['n2_model_' x], 'kind', 'learning', 'var', x, 'eq', 0, 'row', 0, ...
            'share', '', 'lkey', x); %#ok<AGROW>
        ie = find(strcmp({sys.eq.target}, x), 1);
        pn = sys.eq(ie).param_names;
        for j = 1:numel(pn)
            spc(end+1) = struct('name', pn{j}, 'kind', 'learning', 'var', x, 'eq', ie, 'row', j, ...
                'share', '', 'lkey', x); %#ok<AGROW>
        end
    end
end
nS = numel(spc);
Y = NaN(nH, nS, N);

% ---- draws ----------------------------------------------------------------------------
fast = logical(o.fast_path) && strcmp(ctx.opts.expectations.mode, 'rational') ...
    && isempty(ctx.opts.conditions) && ~isNT;    % N types: the general path (fast_path replays two types)
pathName = 'general';
if fast
    pathName = 'fast';
end
fopt = struct('warm', F.warm);
[types, cols] = event_types();          % fixed order of the event counts
counts = zeros(N, numel(types));
status = repmat({'ok'}, N, 1);
msg = repmat({''}, N, 1);
maxAbs = NaN(N, 1);
tick = max(1, round(N / 10));
tDraw = tic;
for j = 1:N
    dj = add_draws(F.d0, info.shocks, info.dates, E(:, :, j));
    try
        if fast
            [dj, rec, ev] = hetlearn.density.fast_path(F, dj);
        else
            rec = hetlearn.engine.record([], nH, ctx);
            [~, rec, ev, dj] = hetlearn.engine.forecast(ctx, F.S0, dj, rec, 0, F.m, F.C, fopt);
        end
        Y(:, :, j) = extract(spc, dj, rec, hz);
        for q = 1:numel(types)
            if ~isempty(ev)
                counts(j, q) = sum(strcmp({ev.type}, types{q}));
            end
        end
        v = Y(:, :, j);
        maxAbs(j) = max(abs(v(:)));
        if any(~isfinite(v(:))) || maxAbs(j) > LIMIT
            status{j} = 'explosive';
        end
    catch err
        status{j} = 'error';
        msg{j} = err.message;
    end
    if ~quiet && (mod(j, tick) == 0 || j == N)
        fprintf('  density: %d/%d draws (%s path), %.1f s\n', j, N, pathName, toc(tDraw));
    end
end
tLoop = toc(tDraw);

% ---- summary ------------------------------------------------------------------------------
used = strcmp(status, 'ok')';
D = struct();
D.id = ctx.opts.id;
D.options = o;
D.dates = hz;
D.quantiles = p;
D.path = pathName;
D.draw_info = info;
D.names = {spc.name};
D.series = struct();
for s = 1:nS
    X = reshape(Y(:, s, used), nH, []);
    sc = 1;
    if strcmp(spc(s).kind, 'observable')
        sc = report_scale(spec, spc(s).name);
    end
    z = struct();
    z.kind = spc(s).kind;
    z.variable = spc(s).var;
    z.q = hetlearn.density.quantile(X, p);
    z.mean = NaN(nH, 1);
    z.std = NaN(nH, 1);
    if ~isempty(X)
        z.mean = mean(X, 2);
        z.std = std(X, 0, 2);
    end
    z.point = point_value(spc(s), res, hz);
    z.scale = sc;
    z.q_report = sc * z.q;
    z.mean_report = sc * z.mean;
    z.point_report = sc * z.point;
    D.series.(spc(s).name) = z;
end
D.ndraws = N;
D.used = used;
D.n_used = sum(used);
D.n_explosive = sum(strcmp(status, 'explosive'));
D.n_error = sum(strcmp(status, 'error'));
D.events = [table((1:N)', status, 'VariableNames', {'draw', 'status'}), ...
    array2table(counts, 'VariableNames', cols), ...
    table(maxAbs, msg, 'VariableNames', {'max_abs', 'message'})];
if logical(o.keep_draws)
    D.draws = struct('series', struct(), 'shocks', E);
    for s = 1:nS
        D.draws.series.(spc(s).name) = reshape(Y(:, s, :), nH, N);
    end
end
D.runtime_s = toc(tAll);
D.s_per_draw = tLoop / max(N, 1);
end


function d = add_draws(d, names, dates, Ej)
for s = 1:numel(names)
    cur = d.(names{s})(dates);
    cur(~isfinite(cur)) = 0;
    d.(names{s})(dates) = cur(:) + Ej(:, s);
end
end


function V = extract(spc, d, rec, hz)
V = NaN(numel(hz), numel(spc));
for s = 1:numel(spc)
    switch spc(s).kind
        case 'observable'
            V(:, s) = d.(spc(s).name)(hz);
        otherwise
            if spc(s).eq == 0 && isempty(spc(s).share)
                V(:, s) = 1 - rec.var.(spc(s).var).n1_model(1:numel(hz))';
            elseif spc(s).eq == 0
                V(:, s) = rec.var.(spc(s).var).(spc(s).share)(1:numel(hz))';     % N types: a type's model share
            else
                V(:, s) = rec.eq(spc(s).eq).phi(spc(s).row, 1:numel(hz))';
            end
    end
end
end


function v = point_value(sp, res, hz)
switch sp.kind
    case 'observable'
        v = res.paths.(sp.name)(hz);
    otherwise
        L = res.learning.(sp.lkey);
        if sp.eq == 0 && isempty(sp.share)
            v = 1 - L.n1_model(hz);
        elseif sp.eq == 0
            v = L.(sp.share)(hz);
        else
            v = L.(sp.name)(hz);
        end
end
v = v(:);
end


function spc = nt_series(spc, ctx)
% N agent types: per learning variable x the model share of each of its types (record field
% n_model_<k>), then the belief parameters of each learning type's PLM equation of x (keyed system
% ctx.sys: e.type = the type, e.var = x, or <x>_feRE for a 're_mean' type; auxiliary equations left out)
nt = ctx.nt;
sys = ctx.sys;
eqType = {};
eqVar = {};
eqAux = false(1, 0);
if ~isempty(sys.eq)
    eqType = {sys.eq.type};
    eqVar = {sys.eq.var};
    eqAux = logical([sys.eq.isAux]);
end
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        k = b.names{jj};
        spc(end+1) = struct('name', sprintf('n_model_%s_%s', k, x), 'kind', 'learning', 'var', x, 'eq', 0, ...
            'row', 0, 'share', ['n_model_' k], 'lkey', x); %#ok<AGROW>
    end
    for jj = 1:numel(b.types)
        ty = nt.types(b.types(jj));
        tv = x;
        if isstruct(ty.zvar) && isfield(ty.zvar, x)
            tv = ty.zvar.(x);
        end
        ie = find(strcmp(eqType, ty.name) & strcmp(eqVar, tv) & ~eqAux, 1);
        if isempty(ie)
            continue
        end
        pn = sys.eq(ie).param_names;
        for j = 1:numel(pn)
            spc(end+1) = struct('name', pn{j}, 'kind', 'learning', 'var', x, 'eq', ie, 'row', j, ...
                'share', '', 'lkey', sys.eq(ie).target); %#ok<AGROW>
        end
    end
end
end


function sc = report_scale(spec, name)
sc = 1;
if isfield(spec, 'report') && isstruct(spec.report) && isfield(spec.report, 'scale') ...
        && isstruct(spec.report.scale) && isfield(spec.report.scale, name)
    sc = double(spec.report.scale.(name));
end
end


function [types, cols] = event_types()
% Engine event types counted per draw, in the fixed column order of D.events.
types = {'projection_plm', 'projection_alm', 'projection_alm_shares', 'explosive', 'rls_missing', 'shares_nan', ...
    'gain_bound'};
cols = {'projection_plm', 'projection_alm', 'projection_alm_shares', 'explosive_events', 'rls_missing', 'shares_nan', ...
    'gain_bound'};
end
