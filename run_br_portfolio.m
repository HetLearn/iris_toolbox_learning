function out = run_br_portfolio(cmd, varargin)
%RUN_BR_PORTFOLIO  BR portfolio: generalized IRFs from 2019Q4 and in-sample (Kalman) RMSE, with their CSV tables.
%
%   run_br_portfolio('irf')          GIRF runs of the 9 scenarios (references a1_re, a1_learn, then
%                                    the 7 variants of scenarios/sw07/br_portfolio/), in this session
%   run_br_portfolio('irf', ids)     only these ids (cellstr), in the order given
%   run_br_portfolio('rmse')         Kalman-history runs of the 9 scenarios ('rmse', ids: only these)
%   run_br_portfolio('check')        gate: the forecast-stage reruns of 'irf' against full hetlearn.run
%                                    calls with shocks.add, for eight (scenario, shock) pairs
%   run_br_portfolio('csv')          write the tables below from the saved runs ('csv_irf', 'csv_rmse':
%                                    one family of tables)
%   ids = run_br_portfolio('ids')    the 9 ids in report order (= run_br_app1('ids'))
%
%   The portfolio has seven variants (5b, 7, 10, 19, 23, 24, 26; docs/USER_GUIDE.md section 7.7);
%   see help run_br_app1.
%   Every run uses the original SW07 parameters (the published mode, config/master_options.m) and
%   inherits every baseline option, projection.facility 'alm' included; facility events are
%   recorded. Nothing is written to results/<id>/: runs are not saved (hetlearn.run 'save' false, or
%   the engine called directly), and the compact outputs go to results/br_portfolio/irf_runs/ and
%   rmse_runs/. Run from the project root (setup_paths is called if IRIS is not started).
%
%   IRFs (section 4). Each scenario with forecast.origin 2019Q4, horizon 20 (2020Q1-2024Q4) and
%   compare_with {}. The steps of hetlearn.run up to hetlearn.engine.core run once: the history stage
%   (RE smoother with filtered RE states, as the baseline) to 2019Q4, so beliefs, gains and shares at
%   2019Q4 are the variant's own, and core's zero-shock forecast. Then the forecast stage
%   (hetlearn.engine.forecast with core's forecast bundle, as hetlearn.density.run calls it) runs from
%   that state with no shock and with +1 sd and -1 sd of one shock added in 2020Q1: the 7 SW07 shocks
%   (std_<shock> of the published mode). No other shocks; beliefs, gains and shares keep updating.
%   GIRF = shocked path minus unshocked path. A forecast that stops (hetlearn:engine:noSolution,
%   :almUnstable) is rerun up to the quarter before the stop; its GIRF is NaN after that. Gates kept
%   in each file: gate_base (the unshocked rerun against core's forecast, max abs difference) and,
%   for a1_re, gate_srf (the RE(t-1) GIRFs against IRIS srf of its solved model, max abs
%   difference). 'check' compares reruns with full hetlearn.run calls.
%
%   RMSE (section 5). Each scenario with history.mode 'kalman', history.re_states 'smoothed' (required
%   with 'kalman'; the Kalman history is one-sided by construction), history.kalman.init 'stochastic'
%   (the default), origin 2026Q2, horizon 4. One-step prediction errors of the 7 observables
%   1966Q1-2026Q2 (2020Q1-Q3 have no data, so 2020Q4 is a four-step prediction) and the log likelihood
%   sum l_t. Relative RMSE and Diebold-Mariano tests (squared errors, h = 1, HLN correction) by
%   hetlearn.evaluate_tables against a1_learn (the baseline) and a1_re (RE(t-1)), by target date: full
%   sample 1966Q1-2026Q2, 1966Q1-1983Q4, 1984Q1-2007Q4, 2008Q1-2019Q4, 2020Q4-2026Q2.
%
%   Writes results/br_portfolio/
%     irf_runs/<id>.mat   one per scenario (struct R): status, the paths of every run (unshocked,
%                         +-1 sd of each shock), shares by type, forecast-stage events, 2019Q4 state,
%                         history-stage events, shock sizes, gates
%     rmse_runs/<id>.mat  one per scenario (struct R): res.kalman (dates, data, predictions, errors,
%                         variances, l_t), events, the RMSE table of kalman_history('rmse'), model gaps
%     irf_long.csv        variant, no, family, shock, sign, size, variable, h (0 = 2020Q1), date,
%                         value_model (GIRF, model units), value_report (x scale: inflation, growth
%                         rates, the policy rate and the inflation expectation in pp of % annualised;
%                         shares x 100, pp of the population), base_model (unshocked path, model units), unit, status.
%                         Variables: pinfobs, dy, robs, dc, pinf_exp1 (aggregate inflation expectation)
%                         and, for switching runs, the shares of the types in the population:
%                         n_<type>_<x> (end of quarter, discrete choice) and n_model_<type>_<x> (in force
%                         in the model).
%     irf_runs.csv        one row per scenario x shock x sign, plus the unshocked run (shock 'none'):
%                         status, stop, facility events of the forecast stage (count, types, first,
%                         last), asymmetry max_h |GIRF(+) + GIRF(-)| in report units over the five
%                         paths and its ratio to max_h |GIRF(+)|; the unshocked row has the runtime,
%                         gate_base and gate_srf
%     states_2019Q4.csv   variant, variable, type, item, value: shares at the end of 2019Q4, shares in
%                         force in 2020Q1, belief parameters and gains at 2019Q4, shock sizes
%     rmse_long.csv       variant x sample x observable: n, RMSE (model units, and x scale), RMSE and
%                         ratio against the baseline and RE(t-1), DM against the baseline and against
%                         RE(t-1) (statistic, p-value, mean loss difference), the log likelihood of the
%                         sample (variant, baseline, RE(t-1)), the largest model gap (max |forecast in
%                         the model - forecast the agents record| over the types in the Kalman history,
%                         a check), facility events, status
%     rmse_runs.csv       one row per scenario: status, log likelihood 1966Q1-2026Q2, solves, facility
%                         events, model gap by type, shares at 2019Q4 and 2026Q2, the check of the RMSE
%                         table (evaluate_tables against kalman_history('rmse'), max abs difference)
%     irf_check.csv       ('check') per pair: max abs difference between the rerun and the full run
%                         (GIRF and unshocked path of the five paths, end-of-quarter shares)
%
%   Sessions: the 9 scenarios take about three minutes ('irf') and one and a half
%   ('rmse') in total, so one session is enough. 'irf' and 'rmse' write one file per scenario, so
%   sessions can also take disjoint id lists; 'csv' runs after all of them.
%
%   See also run_br_app1, hetlearn.run, hetlearn.engine.core, hetlearn.engine.forecast,
%   hetlearn.engine.kalman_history, hetlearn.evaluate_tables, reports/build_br_portfolio_report.py.

root = fileparts(mfilename('fullpath'));
if exist('Model', 'class') ~= 8 || isempty(which('hetlearn.run'))
    addpath(root);
    setup_paths;
end
odir = fullfile(root, 'results', 'br_portfolio');
for sub = {'', 'irf_runs', 'rmse_runs'}
    d = fullfile(odir, sub{1});
    if exist(d, 'dir') ~= 7
        mkdir(d);
    end
end
out = [];
switch cmd
    case 'ids'
        V = variant_table();
        out = {V.id};
    case 'irf'
        ids = pick(varargin);
        for i = 1:numel(ids)
            irf_one(root, odir, ids{i});
        end
        fprintf('run_br_portfolio irf: session done (%d scenarios)\n', numel(ids));
    case 'rmse'
        ids = pick(varargin);
        for i = 1:numel(ids)
            rmse_one(odir, ids{i});
        end
        fprintf('run_br_portfolio rmse: session done (%d scenarios)\n', numel(ids));
    case 'check'
        out = check_irf(odir);
    case 'csv'
        write_irf_tables(odir);
        write_rmse_tables(odir);
    case 'csv_irf'
        write_irf_tables(odir);
    case 'csv_rmse'
        write_rmse_tables(odir);
    otherwise
        error('run_br_portfolio:cmd', 'Unknown command ''%s''.', cmd);
end
end


% =========================================================================
function ids = pick(args)
V = variant_table();
ids = {V.id};
if ~isempty(args) && ~isempty(args{1})
    ids = cellstr(args{1});
end
end


function V = variant_table()
% Report order of run_br_app1 (references, then the families of the design).
C = {
'a1_re',                   'RE',  'ref'
'a1_learn',                'BL',  'ref'
'br05b_cd_learn',          '5b',  'disc'
'br07_myopia_anchoring',   '7',   'info'
'br10_diagnostic',         '10',  'info'
'br23_intercept_only',     '23',  'learn'
'br24_mean_only',          '24',  'learn'
'br26_experience',         '26',  'learn'
'br19_target_believers',   '19',  'dist'
};
V = struct('id', C(:, 1), 'no', C(:, 2), 'family', C(:, 3));
end


function c = sw_shocks()
c = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};
end


function c = irf_vars()
c = {'pinfobs', 'dy', 'robs', 'dc', 'pinf_exp1'};
end


% =========================================================================
% IRFs
% =========================================================================
function irf_one(root, odir, id)
VARS = irf_vars();
o0 = qq(2019, 4);
HZ = 20;
t1 = qq(2020, 1);
tAll = tic;
R = struct('id', id, 'kind', 'irf', 'started', datestr(now, 'yyyy-mm-dd HH:MM:SS'), 'status', '', ... %#ok<TNOW1,DATST>
    'error_id', '', 'message', '', 'stop_date', '', 'origin', '2019Q4', 'horizon', HZ, 'vars', {VARS}, ...
    'runtime_s', NaN, 'gate_base', NaN, 'gate_srf', NaN, 'gate_srf_vars', {{}});
fprintf('\n==== %s  irf  %s\n', id, R.started);
cfg = feval(id);
cfg.compare_with = {};
cfg.forecast.origin = o0;
cfg.forecast.horizon = HZ;
try
    opts = hetlearn.load_options(cfg);
    spec = hetlearn.load_spec(opts.model);
    [m, info] = hetlearn.load_model(spec, opts);
    if logical(opts.history.realtime) && strcmp(opts.history.mode, 're_smoother')
        Hf = hetlearn.re_filter(spec, opts, 'end', opts.forecast.origin(1));     % as hetlearn.run
    else
        Hf = hetlearn.re_filter(spec, opts);
    end
    Hf = hetlearn.policy.prepare(Hf, info, opts);
    ctx = struct('opts', opts, 'spec', spec, 'info', info, 'results_dir', fullfile(root, 'results'), 'quiet', true);
    [res0, F] = hetlearn.engine.core(ctx, m, Hf);
catch err
    R.status = stop_or_error(err.identifier);
    R.error_id = err.identifier;
    R.message = one_line(err.message);
    R.stop_date = stop_date_of(err.message);
    R.runtime_s = toc(tAll);
    save(fullfile(odir, 'irf_runs', [id '.mat']), 'R');
    fprintf('  %s: %s (%s) %s\n', id, R.status, err.identifier, R.message);
    return
end
hz = F.ctx.horizon;
R.dates = reshape(hetlearn.util.date_str(hz), [], 1);
R.mode = opts.expectations.mode;
R.facility = res0.meta.projection_facility;
R.learnVars = reshape(res0.meta.learnVars, 1, []);
R.scale = struct();
for v = VARS
    R.scale.(v{1}) = scale_of(spec, v{1});
end
R.types = type_info(F.ctx, opts);
R.hist_events = events_cell(res0.events(strcmp(res0.events.stage, 'history'), :));
R.history_runtime_s = res0.meta.history_runtime_s;
R.state = state_at(res0, o0);
R.model_values = struct();
if isfield(res0.meta, 'model_values')
    R.model_values = res0.meta.model_values;
end
shocks = sw_shocks();
shocks = shocks(ismember(shocks, F.ctx.eList));
R.shocks = shocks;
R.sd = struct();
for k = 1:numel(shocks)
    R.sd.(shocks{k}) = shock_std(m, info, shocks{k});
end
% unshocked path through the same call as the shocked ones
B = fc(F, F.d0, hz, VARS);
R.base = B;
g = 0;
for v = VARS
    g = max(g, max(abs(B.paths.(v{1}) - reshape(res0.paths.(v{1})(hz), [], 1))));
end
R.gate_base = g;
R.core_events_forecast = events_cell(res0.events(strcmp(res0.events.stage, 'forecast'), :));
runs = struct('shock', {}, 'sign', {}, 'size', {}, 'run', {});
for k = 1:numel(shocks)
    s = shocks{k};
    for sg = [1, -1]
        d = F.d0;
        cur = d.(s)(t1);
        cur(~isfinite(cur)) = 0;
        d.(s)(t1) = cur + sg * R.sd.(s);
        X = fc(F, d, hz, VARS);
        runs(end+1) = struct('shock', s, 'sign', sg, 'size', sg * R.sd.(s), 'run', X); %#ok<AGROW>
        if ~strcmp(X.status, 'ok')
            fprintf('  %s %s %+d sd: %s, %s (%d quarters solved)\n', id, s, sg, X.status, X.message, X.n_solved);
        end
    end
end
R.runs = runs;
% gate (section 4): RE(t-1) GIRF = IRIS srf of its solved model (one sd by default)
if strcmp(opts.expectations.mode, 'rational')
    gs = 0;
    used = {};
    for k = 1:numel(shocks)
        s = shocks{k};
        sr = srf(F.warm.m, 1:HZ, 'select', {s});
        j = find(strcmp({runs.shock}, s) & [runs.sign] == 1, 1);
        for v = VARS
            if ~isfield(sr, v{1})
                continue
            end
            used = union(used, v, 'stable');
            gv = runs(j).run.paths.(v{1}) - B.paths.(v{1});
            gs = max(gs, max(abs(gv - reshape(sr.(v{1})(1:HZ), [], 1))));
        end
    end
    R.gate_srf = gs;
    R.gate_srf_vars = used;
end
R.status = 'ok';
R.runtime_s = toc(tAll);
save(fullfile(odir, 'irf_runs', [id '.mat']), 'R');
nbad = sum(~strcmp(arrayfun(@(r) r.run.status, runs, 'UniformOutput', false), 'ok'));
nfac = sum(arrayfun(@(r) sum(startsWith(r.run.events(:, 2), 'projection')), runs));
fprintf(['  %s: ok in %.1f s (history %.1f s); %d shocks x 2 signs, %d not ok; forecast-stage facility events %d ' ...
    '(unshocked %d); history events %d; gate_base %.3g; gate_srf %.3g (%s)\n'], id, R.runtime_s, R.history_runtime_s, ...
    numel(shocks), nbad, nfac, size(B.events, 1), size(R.hist_events, 1), R.gate_base, R.gate_srf, strjoin(R.gate_srf_vars, ','));
end


function X = fc(F, d, hz, VARS)
% One forecast stage from the bundle F (hetlearn.engine.core) with the databank d.
nH = numel(hz);
X = struct('status', 'ok', 'error_id', '', 'message', '', 'stop_date', '', 'n_solved', nH, ...
    'paths', struct(), 'shares', struct(), 'events', {cell(0, 4)}, 'n_solve', NaN);
fopt = struct('warm', F.warm);
k = nH;
ok = false;
try
    rec = hetlearn.engine.record([], nH, F.ctx);
    [~, rec, ev, d1, fi] = hetlearn.engine.forecast(F.ctx, F.S0, d, rec, 0, F.m, F.C, fopt);
    ok = true;
catch err
    X.error_id = err.identifier;
    X.message = one_line(err.message);
    X.status = stop_or_error(err.identifier);
    X.stop_date = stop_date_of(err.message);
    k = 0;
    if strcmp(X.status, 'stopped') && ~isempty(X.stop_date)
        k = find(strcmp(hetlearn.util.date_str(hz), X.stop_date), 1) - 1;    % quarters before the stop
        if isempty(k)
            k = 0;
        end
    end
    if k >= 1
        try
            c2 = F.ctx;
            c2.horizon = hz(1:k);
            rec = hetlearn.engine.record([], k, c2);
            [~, rec, ev, d1, fi] = hetlearn.engine.forecast(c2, F.S0, d, rec, 0, F.m, F.C(1:k), fopt);
            ok = true;
        catch err2
            X.message = [X.message ' | rerun to the quarter before the stop failed: ' one_line(err2.message)];
            k = 0;
        end
    end
end
X.n_solved = k;
for v = VARS
    x = NaN(nH, 1);
    if ok && k >= 1
        x(1:k) = reshape(d1.(v{1})(hz(1:k)), [], 1);
    end
    X.paths.(v{1}) = x;
end
if ok
    X.shares = rec_shares(F.ctx, rec, nH, k);
    X.events = ev_cell(ev);
    X.n_solve = fi.n_solve;
end
end


function S = rec_shares(ctx, rec, nH, k)
% Shares by learning variable and type from a forecast record: .<x>.names, .n_end (nH x nT), .n_model.
S = struct();
isNT = isfield(ctx, 'nt') && ~isempty(ctx.nt);
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    r = rec.var.(x);
    if isNT
        nm = ctx.nt.byvar.(x).names;
        ne = NaN(nH, numel(nm));
        nmod = ne;
        for j = 1:numel(nm)
            ne(1:k, j) = reshape(r.(['n_' nm{j}])(1:k), [], 1);
            nmod(1:k, j) = reshape(r.(['n_model_' nm{j}])(1:k), [], 1);
        end
    else
        nm = {'RE', 'BR'};
        ne = NaN(nH, 2);
        nmod = ne;
        ne(1:k, :) = [reshape(r.n1(1:k), [], 1), reshape(r.n2(1:k), [], 1)];
        nmod(1:k, :) = [reshape(r.n1_model(1:k), [], 1), 1 - reshape(r.n1_model(1:k), [], 1)];
    end
    S.(x) = struct('names', {reshape(nm, 1, [])}, 'n_end', ne, 'n_model', nmod);
end
end


function T = type_info(ctx, opts)
% Types of each learning variable and whether they are in the population (share group).
T = struct();
isNT = isfield(ctx, 'nt') && ~isempty(ctx.nt);
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    if isNT
        b = ctx.nt.byvar.(x);
        pop = arrayfun(@(j) logical(ctx.nt.types(j).inpop), b.types);
        T.(x) = struct('names', {reshape(b.names, 1, [])}, 'inpop', reshape(pop, 1, []));
    else
        T.(x) = struct('names', {{'RE', 'BR'}}, 'inpop', [true, ~strcmp(opts.expectations.mode, 'rational')]);
    end
end
end


function S = state_at(res, t)
% Shares, beliefs and gains at date t: rows {variable, type, item, value}.
S = cell(0, 4);
L = res.learning;
f = fieldnames(L);
for i = 1:numel(f)
    e = L.(f{i});
    if ~isstruct(e)
        continue
    end
    if isfield(e, 'params') && ~(isfield(e, 'isAux') && logical(e.isAux))
        tp = 'BR';
        vr = f{i};
        if isfield(e, 'type')
            tp = e.type;
            vr = e.variable;
        end
        for j = 1:numel(e.params)
            S(end+1, :) = {vr, tp, e.params{j}, val_at(e.(e.params{j}), t)}; %#ok<AGROW>
        end
        if isfield(e, 'gain')
            S(end+1, :) = {vr, tp, 'gain', val_at(e.gain, t)}; %#ok<AGROW>
        end
    end
    if isfield(e, 'types')
        for j = 1:numel(e.types)
            S(end+1, :) = {f{i}, e.types{j}, 'share_end', val_at(e.(['n_' e.types{j}]), t)}; %#ok<AGROW>
        end
    elseif isfield(e, 'n1')
        S(end+1, :) = {f{i}, 'RE', 'share_end', val_at(e.n1, t)}; %#ok<AGROW>
        S(end+1, :) = {f{i}, 'BR', 'share_end', val_at(e.n2, t)}; %#ok<AGROW>
    end
end
end


function v = val_at(s, t)
v = NaN;
try
    v = double(s(t));
catch
end
end


function sd = shock_std(m, info, s)
nm = ['std_' s];
sd = NaN;
if isfield(info, 'params') && isstruct(info.params) && isfield(info.params, nm)
    sd = double(info.params.(nm));
end
if ~isfinite(sd)
    sd = double(m.(nm));
end
end


function sc = scale_of(spec, name)
sc = 1;
if strcmp(name, 'pinf_exp1')
    name = 'pinfobs';                 % the expectation of inflation, annualised like inflation
end
if isfield(spec, 'report') && isfield(spec.report, 'scale') && isfield(spec.report.scale, name)
    sc = double(spec.report.scale.(name));
end
end


% =========================================================================
% gate: forecast-stage reruns = full hetlearn.run calls
% =========================================================================
function T = check_irf(odir)
% the references, one pair per transform kind (multiplier, equation copy, diagnostic), the three-type
% run, the re_mean type and the mean-only PLM; together they cover six of the seven shocks
P = {'a1_learn', 'epinf'; 'a1_re', 'em'; 'br05b_cd_learn', 'em'; 'br07_myopia_anchoring', 'epinf'; ...
    'br10_diagnostic', 'eb'; 'br19_target_believers', 'ew'; 'br23_intercept_only', 'ea'; ...
    'br24_mean_only', 'eqs'};
VARS = irf_vars();
rows = cell(0, 9);
for i = 1:size(P, 1)
    id = P{i, 1};
    s = P{i, 2};
    t0 = tic;
    tmp = load(fullfile(odir, 'irf_runs', [id '.mat']), 'R');
    R = tmp.R;
    j = find(strcmp({R.runs.shock}, s) & [R.runs.sign] == 1, 1);
    c = feval(id);
    c.compare_with = {};
    c.forecast.origin = qq(2019, 4);
    c.forecast.horizon = R.horizon;
    r0 = hetlearn.run(c, 'save', false, 'quiet', true);
    c.shocks.add = {{s, qq(2020, 1), R.runs(j).size}};
    r1 = hetlearn.run(c, 'save', false, 'quiet', true);
    hz = r0.dates.horizon;
    dPath = 0;
    dBase = 0;
    for v = VARS
        g1 = reshape(r1.paths.(v{1})(hz) - r0.paths.(v{1})(hz), [], 1);
        g2 = R.runs(j).run.paths.(v{1}) - R.base.paths.(v{1});
        dPath = max(dPath, max(abs(g1 - g2)));
        dBase = max(dBase, max(abs(reshape(r0.paths.(v{1})(hz), [], 1) - R.base.paths.(v{1}))));
    end
    dSh = 0;
    for x = reshape(R.learnVars, 1, [])
        S = R.runs(j).run.shares.(x{1});
        L1 = r1.learning.(x{1});
        for q = 1:numel(S.names)
            if isfield(L1, 'types')
                a = reshape(L1.(['n_' S.names{q}])(hz), [], 1);
            elseif q == 1
                a = reshape(L1.n1(hz), [], 1);
            else
                a = reshape(L1.n2(hz), [], 1);
            end
            dSh = max(dSh, max(abs(a - S.n_end(:, q))));
        end
    end
    nev = sum(startsWith(r1.events.type, 'projection') & strcmp(r1.events.stage, 'forecast'));
    rows(end+1, :) = {id, s, R.runs(j).size, dPath, dBase, dSh, nev, size(R.runs(j).run.events, 1), toc(t0)}; %#ok<AGROW>
    fprintf(['check %-22s %-8s GIRF diff %.3g, unshocked path diff %.3g, shares diff %.3g, forecast facility events ' ...
        'full run %d / rerun events %d (%.1f s)\n'], id, s, dPath, dBase, dSh, nev, size(R.runs(j).run.events, 1), toc(t0));
end
hdr = {'variant', 'shock', 'size', 'girf_maxdiff', 'base_maxdiff', 'shares_maxdiff', 'facility_events_full', ...
    'events_rerun', 'runtime_s'};
write_cols(fullfile(odir, 'irf_check.csv'), hdr, cells_to_cols(rows));
T = rows;
end


% =========================================================================
% RMSE
% =========================================================================
function rmse_one(odir, id)
tAll = tic;
R = struct('id', id, 'kind', 'rmse', 'started', datestr(now, 'yyyy-mm-dd HH:MM:SS'), 'status', '', ... %#ok<TNOW1,DATST>
    'error_id', '', 'message', '', 'stop_date', '', 'runtime_s', NaN);
fprintf('\n==== %s  rmse  %s\n', id, R.started);
c = feval(id);
c.compare_with = {};
c.forecast.origin = qq(2026, 2);
c.forecast.horizon = 4;
c.history.mode = 'kalman';
c.history.re_states = 'smoothed';             % required with 'kalman' (one-sided already)
try
    r = hetlearn.run(c, 'save', false, 'quiet', true);
catch err
    R.status = stop_or_error(err.identifier);
    R.error_id = err.identifier;
    R.message = one_line(err.message);
    R.stop_date = stop_date_of(err.message);
    R.runtime_s = toc(tAll);
    save(fullfile(odir, 'rmse_runs', [id '.mat']), 'R');
    fprintf('  %s: %s (%s) %s\n', id, R.status, err.identifier, R.message);
    return
end
K = r.kalman;
R.status = 'ok';
R.mode = r.cfg.expectations.mode;
R.facility = r.meta.projection_facility;
R.init = K.init;
R.dates = reshape(hetlearn.util.date_str(K.dates), [], 1);
R.loglik_start = char(hetlearn.util.date_str(K.loglik_start));
R.origin = char(hetlearn.util.date_str(K.origin));
R.observables = reshape(cellstr(K.observables), 1, []);
R.y = K.y;
R.pred = K.pred;
R.err = K.err;
nT = numel(K.dates);
R.Fdiag = NaN(numel(K.observables), nT);
for k = 1:nT
    R.Fdiag(:, k) = diag(K.F(:, :, k));
end
R.llt = reshape(K.llt, 1, []);
R.n_obs = reshape(K.n_obs, 1, []);
R.loglik = K.loglik;
R.n_solve = K.n_solve;
R.kalman_runtime_s = K.runtime_s;
R.gap_br = NaN;
if isfield(K, 'fbr_model_maxdiff')
    R.gap_br = K.fbr_model_maxdiff;
end
R.gap_types = struct();
if isfield(K, 'ftypes_model_maxdiff') && isstruct(K.ftypes_model_maxdiff)
    R.gap_types = K.ftypes_model_maxdiff;
end
T = hetlearn.engine.kalman_history('rmse', r);
R.rmse_rows = reshape(T.table.Properties.RowNames, 1, []);
R.rmse_cols = reshape(T.table.Properties.VariableNames, 1, []);
R.rmse_tab = table2array(T.table);
R.rmse_n = table2array(T.n);
R.loglik_sub = table2array(T.loglik);
R.events = events_cell(r.events);
R.learnVars = reshape(r.meta.learnVars, 1, []);
R.shares = cell(0, 4);                        % {variable, type, date, end-of-quarter share}
for x = R.learnVars
    L = r.learning.(x{1});
    for dt = [qq(2019, 4), qq(2026, 2)]
        ds = char(hetlearn.util.date_str(dt));
        if isfield(L, 'types')
            for j = 1:numel(L.types)
                R.shares(end+1, :) = {x{1}, L.types{j}, ds, val_at(L.(['n_' L.types{j}]), dt)};
            end
        else
            R.shares(end+1, :) = {x{1}, 'RE', ds, val_at(L.n1, dt)};
            R.shares(end+1, :) = {x{1}, 'BR', ds, val_at(L.n2, dt)};
        end
    end
end
R.types = struct();
if isfield(r.meta, 'types')
    R.types = r.meta.types;
end
R.runtime_s = toc(tAll);
save(fullfile(odir, 'rmse_runs', [id '.mat']), 'R');
ip = strcmp(R.rmse_rows, 'pinfobs');
nfac = sum(startsWith(R.events(:, 2), 'projection'));
gmax = gap_of(R);
fprintf('  %s: ok in %.1f s; loglik %.3f from %s; RMSE pinfobs full %.4f; solves %d; facility events %d; model gap %.3g\n', ...
    id, R.runtime_s, R.loglik, R.loglik_start, R.rmse_tab(ip, 1), R.n_solve, nfac, gmax);
end


% =========================================================================
% tables
% =========================================================================
function write_irf_tables(odir)
V = variant_table();
assert(isequal({V.id}, run_br_app1('ids')), 'run_br_portfolio: the variant list differs from run_br_app1(''ids'').');
VARS = irf_vars();
L = {};          % irf_long column blocks
G = {};          % irf_runs rows
ST = {};         % states_2019Q4 rows
hG = {'variant', 'no', 'family', 'shock', 'sign', 'size', 'status', 'error_id', 'message', 'stop_date', 'n_solved', ...
    'n_solve', 'facility_events', 'facility_types', 'facility_first', 'facility_last', 'other_events', 'asym_max', ...
    'asym_rel', 'runtime_s', 'gate_base', 'gate_srf', 'hist_facility_events', 'hist_facility_types', ...
    'hist_facility_first', 'hist_facility_last'};
tG = {'variant', 'no', 'family', 'shock', 'status', 'error_id', 'message', 'stop_date', 'facility_types', ...
    'facility_first', 'facility_last', 'hist_facility_types', 'hist_facility_first', 'hist_facility_last'};
R = struct();
for i = 1:numel(V)
    f = fullfile(odir, 'irf_runs', [V(i).id '.mat']);
    if exist(f, 'file') == 2
        tmp = load(f, 'R');
        R.(V(i).id) = tmp.R;
    end
end
for i = 1:numel(V)
    id = V(i).id;
    g0 = setr(blank(hG, tG), hG, 'variant', id, 'no', V(i).no, 'family', V(i).family, 'shock', 'none', 'sign', 0);
    if ~isfield(R, id)
        G(end+1, :) = setr(g0, hG, 'status', 'missing', 'message', 'not run'); %#ok<AGROW>
        continue
    end
    r = R.(id);
    if ~strcmp(r.status, 'ok')
        G(end+1, :) = setr(g0, hG, 'status', r.status, 'error_id', r.error_id, 'message', r.message, ...
            'stop_date', r.stop_date, 'runtime_s', r.runtime_s); %#ok<AGROW>
        continue
    end
    hz = r.dates;
    nH = numel(hz);
    hh = (0:nH - 1)';
    B = r.base;
    shareVars = share_list(r);                      % {x, type} of the switching population
    % unshocked run, with the facility events of the history stage up to 2019Q4 (the state of every run)
    [nf, ft, f1, f2] = fac_summary(B.events);
    [hn, ht, h1, h2] = fac_summary(r.hist_events);
    G(end+1, :) = setr(g0, hG, 'size', 0, 'status', B.status, 'error_id', B.error_id, 'message', B.message, ...
        'stop_date', B.stop_date, 'n_solved', B.n_solved, 'n_solve', B.n_solve, 'facility_events', nf, ...
        'facility_types', ft, 'facility_first', f1, 'facility_last', f2, 'other_events', size(B.events, 1) - nf, ...
        'runtime_s', r.runtime_s, 'gate_base', r.gate_base, 'gate_srf', r.gate_srf, 'hist_facility_events', hn, ...
        'hist_facility_types', ht, 'hist_facility_first', h1, 'hist_facility_last', h2); %#ok<AGROW>
    for j = 1:numel(r.runs)
        X = r.runs(j).run;
        s = r.runs(j).shock;
        sg = r.runs(j).sign;
        for v = VARS
            gv = X.paths.(v{1}) - B.paths.(v{1});
            L{end+1} = long_block(id, V(i), s, sg, r.runs(j).size, v{1}, hh, hz, gv, gv * r.scale.(v{1}), ...
                B.paths.(v{1}), 'pp, % annualised', X.status); %#ok<AGROW>
        end
        for q = 1:size(shareVars, 1)
            x = shareVars{q, 1};
            k = find(strcmp(B.shares.(x).names, shareVars{q, 2}), 1);
            for w = {'n_end', 'n_model'}
                if ~isfield(X.shares, x)
                    gv = NaN(nH, 1);
                else
                    gv = X.shares.(x).(w{1})(:, k) - B.shares.(x).(w{1})(:, k);
                end
                L{end+1} = long_block(id, V(i), s, sg, r.runs(j).size, share_name(w{1}, shareVars{q, 2}, x), hh, hz, ...
                    gv, 100 * gv, B.shares.(x).(w{1})(:, k), 'share (0-1); report: pp of the population', X.status); %#ok<AGROW>
            end
        end
        [nf, ft, f1, f2] = fac_summary(X.events);
        [am, ar] = asymmetry(r, s, VARS);
        G(end+1, :) = setr(g0, hG, 'shock', s, 'sign', sg, 'size', r.runs(j).size, 'status', X.status, ...
            'error_id', X.error_id, 'message', X.message, 'stop_date', X.stop_date, 'n_solved', X.n_solved, ...
            'n_solve', X.n_solve, 'facility_events', nf, 'facility_types', ft, 'facility_first', f1, ...
            'facility_last', f2, 'other_events', size(X.events, 1) - nf, 'asym_max', am, 'asym_rel', ar); %#ok<AGROW>
    end
    % 2019Q4 state, the shares in force in 2020Q1 (unshocked run) and the shock sizes
    for q = 1:size(r.state, 1)
        ST(end+1, :) = [{id, V(i).no, V(i).family}, r.state(q, :)]; %#ok<AGROW>
    end
    for x = reshape(fieldnames(B.shares), 1, [])
        S = B.shares.(x{1});
        for k = 1:numel(S.names)
            ST(end+1, :) = {id, V(i).no, V(i).family, x{1}, S.names{k}, 'share_model_2020Q1', S.n_model(1, k)}; %#ok<AGROW>
        end
    end
    for s = r.shocks
        ST(end+1, :) = {id, V(i).no, V(i).family, '', '', ['sd_' s{1}], r.sd.(s{1})}; %#ok<AGROW>
    end
end
hdr = {'variant', 'no', 'family', 'shock', 'sign', 'size', 'variable', 'h', 'date', 'value_model', 'value_report', ...
    'base_model', 'unit', 'status'};
write_cols(fullfile(odir, 'irf_long.csv'), hdr, cat_blocks(L));
write_cols(fullfile(odir, 'irf_runs.csv'), hG, cells_to_cols(G));
hdr = {'variant', 'no', 'family', 'variable', 'type', 'item', 'value'};
write_cols(fullfile(odir, 'states_2019Q4.csv'), hdr, cells_to_cols(ST));
fprintf('run_br_portfolio csv_irf: %d scenarios read; irf_long.csv (%d rows), irf_runs.csv, states_2019Q4.csv in %s\n', ...
    numel(fieldnames(R)), sum(cellfun(@(b) numel(b{8}), L)), odir);
end


function b = long_block(id, v, s, sg, sz, var, hh, hz, gm, gr, base, unit, st)
n = numel(hh);
b = {repmat({id}, n, 1), repmat({v.no}, n, 1), repmat({v.family}, n, 1), repmat({s}, n, 1), repmat(sg, n, 1), ...
    repmat(sz, n, 1), repmat({var}, n, 1), hh, reshape(hz, [], 1), reshape(gm, [], 1), reshape(gr, [], 1), ...
    reshape(base, [], 1), repmat({unit}, n, 1), repmat({st}, n, 1)};
end


function nm = share_name(w, type, x)
if strcmp(w, 'n_model')
    nm = sprintf('n_model_%s_%s', type, x);
else
    nm = sprintf('n_%s_%s', type, x);
end
end


function Q = share_list(r)
% {variable, type} pairs whose shares move: switching mode, types in the population.
Q = cell(0, 2);
if ~strcmp(r.mode, 'switching')
    return
end
for x = reshape(r.learnVars, 1, [])
    T = r.types.(x{1});
    for k = 1:numel(T.names)
        if T.inpop(k)
            Q(end+1, :) = {x{1}, T.names{k}}; %#ok<AGROW>
        end
    end
end
end


function [am, ar] = asymmetry(r, s, VARS)
% max_h |GIRF(+) + GIRF(-)| in report units over the paths, and its ratio to max_h |GIRF(+)|.
jp = find(strcmp({r.runs.shock}, s) & [r.runs.sign] == 1, 1);
jm = find(strcmp({r.runs.shock}, s) & [r.runs.sign] == -1, 1);
am = NaN;
ar = NaN;
if isempty(jp) || isempty(jm)
    return
end
a = 0;
p = 0;
for v = VARS
    gp = (r.runs(jp).run.paths.(v{1}) - r.base.paths.(v{1})) * r.scale.(v{1});
    gm = (r.runs(jm).run.paths.(v{1}) - r.base.paths.(v{1})) * r.scale.(v{1});
    a = max(a, max(abs(gp + gm)));
    p = max(p, max(abs(gp)));
end
am = a;
ar = a / p;
end


function [n, ty, f1, f2] = fac_summary(E)
% facility events (projection_*) in an events cell {date, type, variable, detail(, stage)}
n = 0;
ty = '';
f1 = '';
f2 = '';
if isempty(E)
    return
end
isF = startsWith(E(:, 2), 'projection');
n = sum(isF);
if n == 0
    return
end
u = unique(E(isF, 2));
ty = strjoin(cellfun(@(t) sprintf('%s %d', t, sum(strcmp(E(isF, 2), t))), u', 'UniformOutput', false), '; ');
d = sort(E(isF, 1));
f1 = d{1};
f2 = d{end};
end


function write_rmse_tables(odir)
V = variant_table();
assert(isequal({V.id}, run_br_app1('ids')), 'run_br_portfolio: the variant list differs from run_br_app1(''ids'').');
R = struct();
for i = 1:numel(V)
    f = fullfile(odir, 'rmse_runs', [V(i).id '.mat']);
    if exist(f, 'file') == 2
        tmp = load(f, 'R');
        R.(V(i).id) = tmp.R;
    end
end
assert(isfield(R, 'a1_learn') && strcmp(R.a1_learn.status, 'ok') && isfield(R, 'a1_re') && strcmp(R.a1_re.status, 'ok'), ...
    'run_br_portfolio: the references a1_learn and a1_re must have run (rmse).');
obs = R.a1_learn.observables;
SMP = {'full', R.a1_learn.loglik_start, R.a1_learn.origin; 'y1966_1983', '1966Q1', '1983Q4'; ...
    'y1984_2007', '1984Q1', '2007Q4'; 'y2008_2019', '2008Q1', '2019Q4'; 'y2020Q4_2026Q2', '2020Q4', '2026Q2'};
KMAP = {'full', 'y1966_1983', 'y1984_2007', 'y2008_2019', 'y2020Q4_end'};    % kalman_history('rmse') names
ok = {};
for i = 1:numel(V)
    if isfield(R, V(i).id) && strcmp(R.(V(i).id).status, 'ok')
        ok{end+1} = V(i).id; %#ok<AGROW>
    end
end
% ---- long error table from beliefs.init.date (target = t, origin = t-1, h = 1) -----------------
parts = cell(numel(ok), 1);
for i = 1:numel(ok)
    r = R.(ok{i});
    d = r.dates;
    i0 = find(strcmp(d, r.loglik_start), 1);
    [kk, tt] = ndgrid(1:numel(r.observables), i0:numel(d));
    e = r.err(:, i0:end);
    msk = isfinite(e);
    kk = kk(msk);
    tt = tt(msk);
    ev = e(msk);
    n = numel(ev);
    parts{i} = table(repmat(ok(i), n, 1), reshape(d(tt - 1), [], 1), reshape(d(tt), [], 1), ones(n, 1), ...
        reshape(r.observables(kk), [], 1), ev(:), 'VariableNames', {'variant', 'origin', 'target', 'h', 'variable', 'error'});
end
Terr = vertcat(parts{:});
subs = struct();
for s = 2:size(SMP, 1)
    subs.(SMP{s, 1}) = [str2dat(SMP{s, 2}), str2dat(SMP{s, 3})];
end
op = struct('variants', {ok}, 'variables', {obs}, 'horizon', 1, 'subsamples', subs, 'dm', true);
op.benchmark = 'a1_learn';
TB = hetlearn.evaluate_tables(Terr, op);
op.benchmark = 'a1_re';
TR = hetlearn.evaluate_tables(Terr, op);
MB = index_of(TB.relative_rmse);
MR = index_of(TR.relative_rmse);
DB = index_of(TB.dm);
DR = index_of(TR.dm);
spec = hetlearn.load_spec('sw07');
% ---- rmse_long ----------------------------------------------------------------------------------
hdr = {'variant', 'no', 'family', 'sample', 'first', 'last', 'variable', 'n', 'rmse_model', 'rmse_report', 'scale', ...
    'rmse_baseline', 'rel_baseline', 'rmse_re', 'rel_re', 'dm_stat', 'dm_p', 'dm_mean_loss_diff', 'dm_re_stat', 'dm_re_p', ...
    'dm_re_mean_loss_diff', 'loglik', 'loglik_baseline', 'loglik_re', 'loglik_minus_baseline', 'model_gap_max', ...
    'facility_events', 'status'};
txt = {'variant', 'no', 'family', 'sample', 'first', 'last', 'variable', 'status'};
rows = cell(0, numel(hdr));
chk = struct();
for i = 1:numel(V)
    id = V(i).id;
    isOk = any(strcmp(ok, id));
    st = 'missing';
    if isfield(R, id)
        st = R.(id).status;
    end
    if isOk
        r = R.(id);
        gmax = gap_of(r);
        nfac = sum(startsWith(r.events(:, 2), 'projection'));
        chk.(id) = 0;
    end
    for s = 1:size(SMP, 1)
        for k = 1:numel(obs)
            row = setr(blank(hdr, txt), hdr, 'variant', id, 'no', V(i).no, 'family', V(i).family, 'sample', SMP{s, 1}, ...
                'first', SMP{s, 2}, 'last', SMP{s, 3}, 'variable', obs{k}, 'scale', scale_of(spec, obs{k}), 'status', st);
            if isOk
                kk = [SMP{s, 1} '|' id '|' obs{k}];
                a = TB.relative_rmse(MB(kk), :);
                b = TR.relative_rmse(MR(kk), :);
                ks = find(strcmp(r.rmse_cols, KMAP{s}), 1);
                ll = r.loglik_sub(ks);
                llb = R.a1_learn.loglik_sub(strcmp(R.a1_learn.rmse_cols, KMAP{s}));
                llr = R.a1_re.loglik_sub(strcmp(R.a1_re.rmse_cols, KMAP{s}));
                row = setr(row, hdr, 'n', a.n, 'rmse_model', a.rmse, 'rmse_report', a.rmse * scale_of(spec, obs{k}), ...
                    'rmse_baseline', a.rmse_benchmark, 'rel_baseline', a.relative_rmse, 'rmse_re', b.rmse_benchmark, ...
                    'rel_re', b.relative_rmse, 'loglik', ll, 'loglik_baseline', llb, 'loglik_re', llr, ...
                    'loglik_minus_baseline', ll - llb, 'model_gap_max', gmax, 'facility_events', nfac);
                if isKey(DB, kk)
                    z = TB.dm(DB(kk), :);
                    row = setr(row, hdr, 'dm_stat', z.dm_stat, 'dm_p', z.p_value, 'dm_mean_loss_diff', z.mean_loss_diff);
                end
                if isKey(DR, kk)
                    z = TR.dm(DR(kk), :);
                    row = setr(row, hdr, 'dm_re_stat', z.dm_stat, 'dm_re_p', z.p_value, 'dm_re_mean_loss_diff', z.mean_loss_diff);
                end
                kr = find(strcmp(r.rmse_rows, obs{k}), 1);         % the run's own table, kalman_history('rmse')
                chk.(id) = max(chk.(id), abs(a.rmse - r.rmse_tab(kr, ks)));
            end
            rows(end+1, :) = row; %#ok<AGROW>
        end
    end
end
write_cols(fullfile(odir, 'rmse_long.csv'), hdr, cells_to_cols(rows));
% ---- rmse_runs ----------------------------------------------------------------------------------
hG = {'variant', 'no', 'family', 'status', 'error_id', 'message', 'stop_date', 'runtime_s', 'mode', 'facility', ...
    'loglik_full', 'loglik_from_init', 'n_solve', 'facility_events', 'facility_types', 'facility_first', 'facility_last', ...
    'other_events', 'model_gap_max', 'model_gap_by_type', 'shares_2019Q4', 'shares_2026Q2', 'rmse_check_maxdiff'};
tG = {'variant', 'no', 'family', 'status', 'error_id', 'message', 'stop_date', 'mode', 'facility', 'facility_types', ...
    'facility_first', 'facility_last', 'model_gap_by_type', 'shares_2019Q4', 'shares_2026Q2'};
G = cell(numel(V), numel(hG));
for i = 1:numel(V)
    id = V(i).id;
    g = setr(blank(hG, tG), hG, 'variant', id, 'no', V(i).no, 'family', V(i).family);
    if ~isfield(R, id)
        G(i, :) = setr(g, hG, 'status', 'missing', 'message', 'not run');
        continue
    end
    r = R.(id);
    if ~strcmp(r.status, 'ok')
        G(i, :) = setr(g, hG, 'status', r.status, 'error_id', r.error_id, 'message', r.message, 'stop_date', r.stop_date, ...
            'runtime_s', r.runtime_s);
        continue
    end
    [gmax, gtxt] = gap_of(r);
    [nf, ft, f1, f2] = fac_summary(r.events);
    G(i, :) = setr(g, hG, 'status', r.status, 'runtime_s', r.runtime_s, 'mode', r.mode, 'facility', r.facility, ...
        'loglik_full', r.loglik_sub(strcmp(r.rmse_cols, 'full')), 'loglik_from_init', r.loglik, 'n_solve', r.n_solve, ...
        'facility_events', nf, 'facility_types', ft, 'facility_first', f1, 'facility_last', f2, ...
        'other_events', size(r.events, 1) - nf, 'model_gap_max', gmax, 'model_gap_by_type', gtxt, 'shares_2019Q4', shares_txt(r.shares, '2019Q4'), ...
        'shares_2026Q2', shares_txt(r.shares, r.origin), 'rmse_check_maxdiff', chk.(id));
end
write_cols(fullfile(odir, 'rmse_runs.csv'), hG, cells_to_cols(G));
fprintf(['run_br_portfolio csv_rmse: %d of %d scenarios ok; rmse_long.csv (%d rows), rmse_runs.csv in %s; ' ...
    'error table %d rows; DM fallbacks %d / %d; RMSE check max %.3g\n'], numel(ok), numel(V), size(rows, 1), odir, ...
    height(Terr), TB.info.dm_fallbacks, TR.info.dm_fallbacks, max(cellfun(@(f) chk.(f), fieldnames(chk))));
end


function M = index_of(T)
% sample|variant|variable -> row of an evaluate_tables table
M = containers.Map();
for i = 1:height(T)
    M([T.sample{i} '|' T.variant{i} '|' T.variable{i}]) = i;
end
end


function s = shares_txt(S, date)
sh = S(strcmp(S(:, 3), date), :);
s = strjoin(cellfun(@(x, t, v) sprintf('%s:%s %.3f', x, t, v), sh(:, 1)', sh(:, 2)', sh(:, 4)', 'UniformOutput', false), '; ');
end


function [gmax, gtxt] = gap_of(r)
% the largest model gap over the types (the BR gap of a two-type run) and the gaps by type
if ~isempty(fieldnames(r.gap_types))
    f = fieldnames(r.gap_types);
    g = cellfun(@(k) r.gap_types.(k), f);
    gmax = max(g);
    gtxt = strjoin(cellfun(@(k, v) sprintf('%s %.3g', k, v), f', num2cell(g'), 'UniformOutput', false), '; ');
else
    gmax = r.gap_br;
    gtxt = sprintf('BR %.3g', r.gap_br);
end
end


% =========================================================================
% helpers
% =========================================================================
function r = blank(hdr, txt)
% one table row: '' for the text columns, NaN for the others
r = cell(1, numel(hdr));
for j = 1:numel(hdr)
    if any(strcmp(txt, hdr{j}))
        r{j} = '';
    else
        r{j} = NaN;
    end
end
end


function r = setr(r, hdr, varargin)
for k = 1:2:numel(varargin)
    j = find(strcmp(hdr, varargin{k}), 1);
    if isempty(j)
        error('run_br_portfolio:column', 'No column %s.', varargin{k});
    end
    r{j} = varargin{k + 1};
end
end


function st = stop_or_error(eid)
if any(strcmp(eid, {'hetlearn:engine:noSolution', 'hetlearn:engine:almUnstable'}))
    st = 'stopped';
else
    st = 'error';
end
end


function d = stop_date_of(msg)
d = '';
tok = regexp(msg, 'Period (\d{4}Q\d)', 'tokens', 'once');
if ~isempty(tok)
    d = tok{1};
end
end


function C = events_cell(T)
% events table -> cell {date, type, variable, detail, stage}
if isempty(T) || height(T) == 0
    C = cell(0, 5);
    return
end
C = [cellstr(T.date), cellstr(T.type), cellstr(T.variable), cellfun(@one_line, cellstr(T.detail), 'UniformOutput', false), ...
    cellstr(T.stage)];
end


function C = ev_cell(ev)
% engine events struct array -> cell {date, type, variable, detail}
if isempty(ev)
    C = cell(0, 4);
    return
end
C = [reshape(hetlearn.util.date_str([ev.date]), [], 1), reshape({ev.type}, [], 1), reshape({ev.variable}, [], 1), ...
    reshape(cellfun(@one_line, {ev.detail}, 'UniformOutput', false), [], 1)];
end


function s = one_line(msg)
s = regexprep(char(msg), '\s+', ' ');
end


function cols = cells_to_cols(C)
cols = cell(1, size(C, 2));
for j = 1:size(C, 2)
    c = C(:, j);
    if all(cellfun(@(x) (isnumeric(x) || islogical(x)) && isscalar(x), c))
        cols{j} = cellfun(@double, c);
    else
        cols{j} = cellfun(@(x) char(string(x)), c, 'UniformOutput', false);
    end
end
end


function T = cat_blocks(B)
nC = numel(B{1});
T = cell(1, nC);
for j = 1:nC
    parts = cellfun(@(b) b{j}, B, 'UniformOutput', false);
    T{j} = vertcat(parts{:});
end
end


function write_cols(file, header, cols)
% CSV with one header row; numbers %.10g (NaN empty), text quoted when it holds a comma or quote.
n = numel(cols{1});
S = strings(n, numel(cols));
for j = 1:numel(cols)
    c = cols{j};
    if isnumeric(c) || islogical(c)
        c = double(c(:));
        s = compose("%.10g", c);
        s(isnan(c)) = "";
    else
        s = string(c(:));
        s(ismissing(s)) = "";
        q = contains(s, ",") | contains(s, """");
        s(q) = """" + replace(s(q), """", """""") + """";
    end
    S(:, j) = s;
end
fid = fopen(file, 'w');
if fid < 0
    error('run_br_portfolio: cannot write %s', file);
end
fprintf(fid, '%s\n', strjoin(header, ','));
if n > 0
    lines = cellstr(join(S, ",", 2));
    fprintf(fid, '%s\n', lines{:});
end
fclose(fid);
end
