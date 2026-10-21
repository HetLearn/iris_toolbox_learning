function out = run_br_app1(cmd, varargin)
%RUN_BR_APP1  Application 1 for the bounded-rationality portfolio: runs and the CSV tables of its report.
%
%   run_br_app1('check')          load the options of the 23 scenarios (no run): syntax and validation
%   run_br_app1('run')            run the references a1_re, a1_learn, then the 21 variants of
%                                 scenarios/sw07/br_portfolio/, in this session
%   run_br_app1('run', ids)       only these scenario ids (cellstr), in the order given
%   run_br_app1('csv')            write results/br_portfolio/app1_*.csv from the saved runs
%   run_br_app1('calib18')        calibration search for variant 18 (De Grauwe): runs, not saved,
%                                 of br18_degrauwe with the bias, intensity and memory set to a
%                                 grid around De Grauwe's published values; writes
%                                 results/br_portfolio/app1_calib18.csv
%   ids = run_br_app1('ids')      the 23 ids in report order (references first)
%
%   Run from the project root (it calls setup_paths if IRIS is not started). Each run is
%   hetlearn.run(feval(id)) and saves results/<id>/ like any scenario (the references
%   overwrite results/a1_re/ and results/a1_learn/ with the same runs). Every run inherits
%   the baseline's projection facility (config/master_options.m: 'alm' since 2026-10-21,
%   'none' on 2026-10-20); its events (projection_alm, projection_alm_shares,
%   projection_level) are recorded. A run that still has no model solution stops with
%   hetlearn:engine:noSolution, :levelNoSolution or :almUnstable and saves nothing: that
%   stop is the result, and the status file records the error, its period and the stage
%   (a message that names no stage: history up to the origin, forecast after it). No
%   other facility is tried. For a stop in the forecast stage after the first forecast
%   quarter, the same scenario runs again with the horizon cut to the quarters before the stop and
%   compare_with off, saved in results/br_portfolio/partial/<id>/. The engine solves the
%   forecast quarter by quarter with the beliefs and shares in force, so that run has the
%   same path and shares up to the last quarter that solves; the tables use it for the
%   shares at the origin and the path up to the stop, flagged complete = 0.
%   Parallel sessions: run the references first (the variants compare with them), then
%   give each session its own variants; br05a and br06 share one generated model file, so
%   keep them in one session.
%
%   Writes (results/br_portfolio/)
%     status/<id>.mat, status/<id>.txt   one per run: status ok | stopped | error, error
%                                         identifier and message, stop period and stage,
%                                         runtime, partial run
%     app1_variants.csv     id, no, family, name, mechanism, key parameters (numbers from the
%                           merged options and res.meta.model_values), literature source,
%                           population, mode
%     app1_summary.csv      per run: status, stop, average inflation 2022Q3-2026Q2, inflation
%                           in 2022Q4, 2023Q4, 2024Q4, average and peak gap to a1_re (RE(t-1)),
%                           policy rate, output and consumption growth averages, the shares at
%                           the end of 2022Q2 as text, the facility and its events (history,
%                           forecast, first and last quarter, types)
%     app1_paths.csv        variant (or data), date, variable (pinfobs, robs, dy, dc), value in
%                           % annualised (model units x spec.report.scale), stage, complete
%     app1_shares.csv       variant, variable, type, date, stage, n_end (discrete-choice share at
%                           the end of the quarter), n_model (share in the model in the quarter;
%                           empty in the history), mode, in_population, complete
%     app1_shares_2022Q2.csv  variant, variable, type, share at the end of 2022Q2 (switching: the
%                           end-of-quarter share; other modes: the share in force in 2022Q3),
%                           n_end, n_model_next, complete
%     app1_events.csv       every engine event of the runs read: variant, date, stage, type,
%                           variable, detail (facility events: projection_*)
%     app1_run_log.csv      the status files as one table
%     app1_calib18.csv      ('calib18') one row per setting: bias g, intensity, memory, status,
%                           facility events, inflation and consumption growth ranges, share
%                           statistics and the pass/fail of the three criteria
%
%   See also hetlearn.run, run_applications, reports/build_br_app1_report.py.

root = fileparts(mfilename('fullpath'));
if exist('Model', 'class') ~= 8 || isempty(which('hetlearn.run'))
    addpath(root);
    setup_paths;
end
odir = fullfile(root, 'results', 'br_portfolio');
for sub = {'', 'status', 'partial'}
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
    case 'check'
        ids = pick(varargin);
        nb = 0;
        for i = 1:numel(ids)
            try
                o = hetlearn.load_options(feval(ids{i}));
                fprintf('OK    %-24s mode %-13s variables %s\n', ids{i}, o.expectations.mode, ...
                    strjoin(cellstr(o.expectations.variables), ','));
            catch err
                nb = nb + 1;
                fprintf('FAIL  %-24s %s: %s\n', ids{i}, err.identifier, one_line(err.message));
            end
        end
        fprintf('check: %d of %d load\n', numel(ids) - nb, numel(ids));
    case 'run'
        ids = pick(varargin);
        for i = 1:numel(ids)
            run_one(odir, ids{i});
        end
        fprintf('run_br_app1: session done (%d runs)\n', numel(ids));
    case 'csv'
        write_tables(root, odir);
    case 'calib18'
        out = calib18(odir, varargin{:});
    otherwise
        error('run_br_app1:cmd', 'Unknown command ''%s''.', cmd);
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
% Report order: the references, then the families of the design (research notes of the
% literature review) in the order of docs/DESIGN_br_extensions.md section 3.
F = {'ref', 'References'; 'depth', 'Depth of reasoning'; 'disc', 'Discounting and horizons'; ...
    'info', 'Information frictions'; 'learn', 'Learning variants and heuristics'; 'dist', 'Belief distortions'};
C = {
% id                       no     fam      name
'a1_re',                   'RE',  'ref',   'RE(t-1) benchmark'
'a1_learn',                'BL',  'ref',   'Baseline: RE agents and AR(1) learners'
'br01a_levelk_egm',        '1a',  'depth', 'Level-k on a learned level 0 (EGM)'
'br01b_levelk_bcl',        '1b',  'depth', 'Level 2 for everyone (BCL)'
'br04_shallow',            '4',   'depth', 'Shallow reasoning'
'br05a_cd',                '5a',  'disc',  'Cognitive discounting, all expectations'
'br05b_cd_learn',          '5b',  'disc',  'Cognitive discounting, learning set'
'br06_hyperbolic',         '6',   'disc',  'As-if hyperbolic discounting'
'br07_myopia_anchoring',   '7',   'info',  'Myopia and anchoring'
'br10_diagnostic',         '10',  'info',  'Diagnostic expectations'
'br17_heuristics',         '17',  'learn', 'Four heuristics (Anufriev-Hommes)'
'br20_sac',                '20',  'learn', 'SAC learning, seven expectations'
'br23_intercept_only',     '23',  'learn', 'Intercept-only learners'
'br24_mean_only',          '24',  'learn', 'Mean-only learners'
'br25a_kf_ar2',            '25a', 'learn', 'Kalman-filter learning, AR(2)'
'br25b_kf_average',        '25b', 'learn', 'Kalman-filter learning, five-model average'
'br26_experience',         '26',  'learn', 'Experience-based gain'
'br18_degrauwe',           '18',  'dist',  'Targeters/extrapolators, optimists/pessimists'
'br19_target_believers',   '19',  'dist',  'Target believers'
'br27_bma',                '27',  'dist',  'Bayesian model averaging'
'br29_wedge',              '29',  'dist',  'Survey belief wedge'
'br31_confidence',         '31',  'dist',  'Confidence shocks'
'br33_farmer',             '33',  'dist',  'Naive nominal-growth belief'
};
V = struct('id', C(:, 1), 'no', C(:, 2), 'family', C(:, 3), 'name', C(:, 4));
for i = 1:numel(V)
    k = find(strcmp(F(:, 1), V(i).family));
    V(i).family_label = F{k, 2};
    V(i).family_order = k - 1;
    V(i).order = i;
end
end


% =========================================================================
function st = run_one(odir, id)
st = struct('id', id, 'status', '', 'error_id', '', 'message', '', 'stop_date', '', 'stop_stage', '', ...
    'n_solved', NaN, 'runtime_s', NaN, 'started', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ...
    'partial_horizon', 0, 'partial_status', '', 'partial_message', ''); %#ok<TNOW1,DATST>
fprintf('\n==== %s  %s\n', id, st.started);
t0 = tic;
cfg = feval(id);
H = cfg.forecast.horizon;
try
    hetlearn.run(cfg);
    st.status = 'ok';
    st.n_solved = H;
catch err
    st.error_id = err.identifier;
    st.message = err.message;
    if any(strcmp(err.identifier, {'hetlearn:engine:noSolution', 'hetlearn:engine:levelNoSolution', ...
            'hetlearn:engine:almUnstable'}))
        st.status = 'stopped';
    else
        st.status = 'error';
    end
    fprintf('  %s (%s): %s\n', st.status, err.identifier, one_line(err.message));
end
st.runtime_s = toc(t0);
pdir = fullfile(odir, 'partial', id);
if strcmp(st.status, 'stopped')
    [st.stop_date, st.stop_stage, k] = stop_where(st.message, cfg.forecast.origin);
    st.n_solved = max(k, 0);
    if strcmp(st.stop_stage, 'forecast') && k >= 1
        c2 = cfg;
        c2.forecast.horizon = k;
        c2.compare_with = {};
        try
            hetlearn.run(c2, 'results_dir', fullfile(odir, 'partial'));
            st.partial_horizon = k;
            st.partial_status = 'ok';
        catch err2
            st.partial_status = 'error';
            st.partial_message = err2.message;
            fprintf('  partial run (horizon %d) failed: %s\n', k, one_line(err2.message));
        end
    end
end
if ~strcmp(st.partial_status, 'ok') && exist(pdir, 'dir') == 7
    rmdir(pdir, 's');                          % a partial run of an earlier session
end
save(fullfile(odir, 'status', [id '.mat']), 'st');
fid = fopen(fullfile(odir, 'status', [id '.txt']), 'w');
fprintf(fid, 'id: %s\nstatus: %s\nstop: %s (%s stage)\nforecast quarters solved: %g\nruntime_s: %.1f\nstarted: %s\npartial: horizon %d, %s %s\nerror: %s\nmessage: %s\n', ...
    id, st.status, st.stop_date, st.stop_stage, st.n_solved, st.runtime_s, st.started, st.partial_horizon, ...
    st.partial_status, one_line(st.partial_message), st.error_id, st.message);
fclose(fid);
fprintf('  %s: %s in %.1f s%s\n', id, st.status, st.runtime_s, ...
    ternary(isempty(st.stop_date), '', sprintf(', stops in %s (%s stage)', st.stop_date, st.stop_stage)));
end


function [d, stg, k] = stop_where(msg, origin)
% Period and stage of a stop from the error message; k = forecast quarters solved before it.
d = '';
stg = '';
k = NaN;
tok = regexp(msg, 'Period (\d{4})Q(\d)(?: \((\w+) stage)?', 'tokens', 'once');
if isempty(tok)
    return
end
y = str2double(tok{1});
q = str2double(tok{2});
d = sprintf('%dQ%d', y, q);
o = char(hetlearn.util.date_str(origin));
oy = str2double(o(1:4));
oq = str2double(o(end));
gap = (4 * y + q) - (4 * oy + oq);
if numel(tok) >= 3 && ~isempty(tok{3})
    stg = tok{3};
elseif gap <= 0
    stg = 'history';
else
    stg = 'forecast';
end
k = gap - 1;
if strcmp(stg, 'history')
    k = 0;
end
end


% =========================================================================
function write_tables(root, odir)
spec = hetlearn.load_spec('sw07');
db = hetlearn.load_database(spec);
sc = spec.report.scale;
V = variant_table();
pv = {'pinfobs', 'robs', 'dy', 'dc'};
dstr = @(d) reshape(cellstr(hetlearn.util.date_str(d)), [], 1);
R = struct();
ST = struct();
for i = 1:numel(V)
    id = V(i).id;
    f = fullfile(odir, 'status', [id '.mat']);
    if exist(f, 'file') ~= 2
        st = struct('id', id, 'status', 'missing', 'error_id', '', 'message', 'not run', 'stop_date', '', ...
            'stop_stage', '', 'n_solved', NaN, 'runtime_s', NaN, 'started', '', 'partial_horizon', 0, ...
            'partial_status', '', 'partial_message', '');
    else
        tmp = load(f, 'st');
        st = tmp.st;
    end
    ST.(id) = st;
    rf = '';
    if strcmp(st.status, 'ok')
        rf = fullfile(root, 'results', id, 'results.mat');
    elseif strcmp(st.partial_status, 'ok')
        rf = fullfile(odir, 'partial', id, 'results.mat');
    end
    if ~isempty(rf) && exist(rf, 'file') == 2
        tmp = load(rf, 'res');
        R.(id) = tmp.res;
    end
end
assert(isfield(R, 'a1_re') && isfield(R, 'a1_learn') && strcmp(ST.a1_re.status, 'ok'), ...
    'run_br_app1: the references a1_re and a1_learn must have run first.');
origin = R.a1_learn.dates.origin;
hz = R.a1_learn.dates.horizon;
hs = dstr(hz);
pd = qq(2018, 1):hz(end);
pds = dstr(pd);
n = numel(pd);
isH = double(pd(:)) <= double(origin) + 1e-6;
stgOf = @(m) ternary_c(m, 'history', 'forecast');
re = R.a1_re.paths.pinfobs(hz) * sc.pinfobs;

% ---- app1_paths ---------------------------------------------------------------------------
P = {};
for v = 1:numel(pv)
    x = db.(pv{v})(pd) * sc.(pv{v});
    P{end+1} = {repmat({'data'}, n, 1), pds, repmat(pv(v), n, 1), x(:), stgOf(isH), ones(n, 1)}; %#ok<AGROW>
end
for i = 1:numel(V)
    id = V(i).id;
    if ~isfield(R, id)
        continue
    end
    cpl = double(strcmp(ST.(id).status, 'ok'));
    for v = 1:numel(pv)
        x = R.(id).paths.(pv{v})(pd) * sc.(pv{v});
        x = x(:);
        keep = isfinite(x);
        P{end+1} = {repmat({id}, nnz(keep), 1), pds(keep), repmat(pv(v), nnz(keep), 1), x(keep), ...
            stgOf(isH(keep)), repmat(cpl, nnz(keep), 1)}; %#ok<AGROW>
    end
end
write_cols(fullfile(odir, 'app1_paths.csv'), {'variant', 'date', 'variable', 'value', 'stage', 'complete'}, cat_blocks(P));

% ---- app1_events ---------------------------------------------------------------------------
E = {};
EV = struct();
for i = 1:numel(V)
    id = V(i).id;
    EV.(id) = struct('fac_hist', NaN, 'fac_fore', NaN, 'first', '', 'last', '', 'types', '', 'other', NaN);
    if ~isfield(R, id)
        continue
    end
    T = R.(id).events;
    k = height(T);
    isFac = startsWith(T.type, 'projection');
    tys = unique(T.type(isFac));
    tt = strjoin(cellfun(@(t) sprintf('%s %d', t, sum(strcmp(T.type, t))), tys', 'UniformOutput', false), ', ');
    dF = sort(cellstr(T.date(isFac)));
    f1 = '';
    f2 = '';
    if ~isempty(dF)
        f1 = dF{1};
        f2 = dF{end};
    end
    EV.(id) = struct('fac_hist', sum(isFac & strcmp(T.stage, 'history')), 'fac_fore', sum(isFac & strcmp(T.stage, 'forecast')), ...
        'first', f1, 'last', f2, 'types', tt, 'other', sum(~isFac));
    if k > 0
        E{end+1} = {repmat({id}, k, 1), cellstr(T.date), cellstr(T.stage), cellstr(T.type), cellstr(T.variable), ...
            cellfun(@one_line, cellstr(T.detail), 'UniformOutput', false)}; %#ok<AGROW>
    end
end
if isempty(E)
    E = {{cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1), cell(0, 1)}};
end
write_cols(fullfile(odir, 'app1_events.csv'), {'variant', 'date', 'stage', 'type', 'variable', 'detail'}, cat_blocks(E));

% ---- app1_shares, app1_shares_2022Q2 ------------------------------------------------------
B = {};
B2 = {};
SH = struct();
for i = 1:numel(V)
    id = V(i).id;
    if ~isfield(R, id) || strcmp(R.(id).cfg.expectations.mode, 'rational')
        continue
    end
    res = R.(id);
    cpl = double(strcmp(ST.(id).status, 'ok'));
    mode = res.cfg.expectations.mode;
    dts = res.dates.record;
    dS = dstr(dts);
    m = numel(dts);
    isHr = double(dts(:)) <= double(origin) + 1e-6;
    io = find(abs(double(dts(:)) - double(origin)) < 1e-6, 1);
    txt = {};
    for x = reshape(res.meta.learnVars, 1, [])
        L = res.learning.(x{1});
        [tn, ne, nm] = type_shares(L, dts);
        parts = {};
        for k = 1:numel(tn)
            ip = 1;
            if isfield(res.meta, 'types')
                j = find(strcmp({res.meta.types.name}, tn{k}), 1);
                if ~isempty(j)
                    ip = double(logical(res.meta.types(j).population));
                end
            end
            B{end+1} = {repmat({id}, m, 1), repmat(x, m, 1), repmat(tn(k), m, 1), dS, stgOf(isHr), ne(:, k), ...
                nm(:, k), repmat({mode}, m, 1), repmat(ip, m, 1), repmat(cpl, m, 1)}; %#ok<AGROW>
            e0 = NaN;
            n1 = NaN;
            if ~isempty(io)
                e0 = ne(io, k);
                if io < m
                    n1 = nm(io + 1, k);
                end
            end
            s0 = ternary(strcmp(mode, 'switching'), e0, n1);
            B2{end+1} = {{id}, x, tn(k), s0, e0, n1, cpl}; %#ok<AGROW>
            parts{end+1} = sprintf('%s %.3f', tn{k}, s0); %#ok<AGROW>
            if strcmp(mode, 'switching') && isfinite(e0) && isfinite(n1) && abs(e0 - n1) > 1e-12
                fprintf('  note %s %s %s: end-of-2022Q2 share %.6g, in force in 2022Q3 %.6g\n', id, x{1}, tn{k}, e0, n1);
            end
        end
        txt{end+1} = [x{1} ': ' strjoin(parts, ', ')]; %#ok<AGROW>
    end
    SH.(id) = strjoin(txt, '; ');
end
write_cols(fullfile(odir, 'app1_shares.csv'), {'variant', 'variable', 'type', 'date', 'stage', 'n_end', ...
    'n_model', 'mode', 'in_population', 'complete'}, cat_blocks(B));
write_cols(fullfile(odir, 'app1_shares_2022Q2.csv'), {'variant', 'variable', 'type', 'share', 'n_end', ...
    'n_model_next', 'complete'}, cat_blocks(B2));

% ---- app1_summary --------------------------------------------------------------------------
cols = {'id', 'no', 'family', 'status', 'complete', 'stop_date', 'stop_stage', 'n_solved', 'error_id', ...
    'error_message', 'avg_pinf', 'pinf_2022Q4', 'pinf_2023Q4', 'pinf_2024Q4', 'gap_avg', 'gap_peak', ...
    'gap_peak_date', 'pinf_min', 'pinf_min_date', 'pinf_max', 'pinf_max_date', 'pinf_end', 'avg_robs', ...
    'avg_dy', 'avg_dc', 'shares_2022Q2', 'mode', 'runtime_s', 'partial_horizon', 'facility', 'fac_events_history', ...
    'fac_events_forecast', 'fac_first', 'fac_last', 'fac_types', 'other_events'};
S = cell(numel(V), numel(cols));
q4 = @(y) find(strcmp(hs, sprintf('%dQ4', y)), 1);
for i = 1:numel(V)
    id = V(i).id;
    st = ST.(id);
    cpl = strcmp(st.status, 'ok');
    row = {id, V(i).no, V(i).family, st.status, double(cpl), st.stop_date, st.stop_stage, st.n_solved, ...
        st.error_id, one_line(st.message)};
    nums = NaN(1, 14);
    pkd = '';
    mnd = '';
    mxd = '';
    if cpl && isfield(R, id)
        p = R.(id).paths.pinfobs(hz) * sc.pinfobs;
        p = p(:);
        g = p - re(:);
        [~, ig] = max(abs(g));
        [pmin, imin] = min(p);
        [pmax, imax] = max(p);
        nums = [mean(p), p(q4(2022)), p(q4(2023)), p(q4(2024)), mean(g), g(ig), pmin, pmax, p(end), ...
            mean(R.(id).paths.robs(hz)) * sc.robs, mean(R.(id).paths.dy(hz)) * sc.dy, ...
            mean(R.(id).paths.dc(hz)) * sc.dc, NaN, NaN];
        pkd = hs{ig};
        mnd = hs{imin};
        mxd = hs{imax};
    end
    mode = '';
    fac = '';
    if isfield(R, id)
        mode = R.(id).cfg.expectations.mode;
        fac = R.(id).cfg.projection.facility;
    else
        try
            o = hetlearn.load_options(feval(id));
            mode = o.expectations.mode;
            fac = o.projection.facility;
        catch
        end
    end
    sh = '';
    if isfield(SH, id)
        sh = SH.(id);
    end
    ev = EV.(id);
    S(i, :) = [row, {nums(1), nums(2), nums(3), nums(4), nums(5), nums(6), pkd, nums(7), mnd, nums(8), mxd, ...
        nums(9), nums(10), nums(11), nums(12), sh, mode, st.runtime_s, st.partial_horizon, fac, ev.fac_hist, ...
        ev.fac_fore, ev.first, ev.last, ev.types, ev.other}];
end
write_cols(fullfile(odir, 'app1_summary.csv'), cols, cells_to_cols(S));

% ---- app1_variants -------------------------------------------------------------------------
cv = {'id', 'no', 'family', 'family_label', 'family_order', 'order', 'name', 'mechanism', 'params', 'source', ...
    'population', 'mode', 'scenario_file'};
M = cell(numel(V), numel(cv));
for i = 1:numel(V)
    id = V(i).id;
    c = feval(id);
    if isfield(R, id)
        o = R.(id).cfg;
    else
        o = hetlearn.load_options(c);
    end
    mv = struct();
    if isfield(R, id) && isfield(R.(id).meta, 'model_values')
        mv = R.(id).meta.model_values;
    end
    [mech, par, src, pop] = describe(id, c, o, mv);
    if startsWith(id, 'br')
        sf = ['scenarios/sw07/br_portfolio/' id '.m'];
    else
        sf = ['scenarios/sw07/app1_peak/' id '.m'];
    end
    M(i, :) = {id, V(i).no, V(i).family, V(i).family_label, V(i).family_order, V(i).order, V(i).name, mech, ...
        par, src, pop, o.expectations.mode, sf};
end
write_cols(fullfile(odir, 'app1_variants.csv'), cv, cells_to_cols(M));

% ---- app1_run_log --------------------------------------------------------------------------
cl = {'id', 'status', 'stop_date', 'stop_stage', 'n_solved', 'runtime_s', 'started', 'partial_horizon', ...
    'partial_status', 'error_id', 'message'};
L = cell(numel(V), numel(cl));
for i = 1:numel(V)
    st = ST.(V(i).id);
    L(i, :) = {st.id, st.status, st.stop_date, st.stop_stage, st.n_solved, st.runtime_s, st.started, ...
        st.partial_horizon, st.partial_status, st.error_id, one_line(st.message)};
end
write_cols(fullfile(odir, 'app1_run_log.csv'), cl, cells_to_cols(L));
fprintf('run_br_app1 csv: %d runs read (%d ok), tables in %s\n', numel(fieldnames(R)), ...
    sum(cellfun(@(f) strcmp(ST.(f).status, 'ok'), fieldnames(ST))), odir);
end


function [tn, ne, nm] = type_shares(L, dts)
% Type names and their end-of-quarter (ne) and in-model (nm) shares, one column per type.
if isfield(L, 'types')
    tn = reshape(cellstr(L.types), 1, []);
    ne = NaN(numel(dts), numel(tn));
    nm = ne;
    for k = 1:numel(tn)
        ne(:, k) = reshape(L.(['n_' tn{k}])(dts), [], 1);
        nm(:, k) = reshape(L.(['n_model_' tn{k}])(dts), [], 1);
    end
else
    tn = {'RE', 'BR'};
    n1 = reshape(L.n1(dts), [], 1);
    m1 = reshape(L.n1_model(dts), [], 1);
    ne = [n1, 1 - n1];
    nm = [m1, 1 - m1];
end
end


% =========================================================================
function T = calib18(odir, rows)
% Calibration search for variant 18 (user request 2026-10-21). De Grauwe (2011, Economic Theory 47;
% CESifo WP 2418, Appendix A) calibrates in decimal units with months as the time unit: fixed
% divergence beta = 0.01, variable divergence delta = 2, intensity gamma = 10000, memory rho = 0.5
% (weights (1 - rho) rho^k, the toolbox's 'normalized' fitness). In % and quarters: bias
% g = beta/2 = 0.5 (delta = 0, the paper's constant-bias case; a level, no time conversion),
% intensity gamma/100^2 = 1 per %^2, memory rho^3 = 0.125 per quarter. Nearby: g with the delta term
% at the RE limit's variance of y - yf ((1 + 0.02 var)/2), 0.25 and 1; intensity 1/9 (inflation
% errors at quarterly instead of monthly rates), 0.5 and 2 (the baseline); memory 0.5 (as
% published, per period) and 0.8 (the baseline); and the design's calibration (g = sd(y - yf)/2,
% intensity 2, memory 0.8). Criteria, fixed before the runs: C1 the run completes; C2 inflation and
% consumption growth (annualised) stay inside their 1966Q1-2019Q4 data ranges in every forecast
% quarter; C3 in each share group the share of the second type (EXT, PES) is outside [0.02, 0.98]
% in at most 10% of the quarters of the record and has a standard deviation of at least 0.02.
% The choice: among the settings that pass, the one closest to the converted published values
% (fewest parameters changed, then the smallest sum of absolute log ratios).
cdir = fullfile(odir, 'calib18');
if exist(cdir, 'dir') ~= 7
    mkdir(cdir);
end
spec = hetlearn.load_spec('sw07');
db = hetlearn.load_database(spec);
sc = spec.report.scale;
base = br18_degrauwe();
% the RE limit's sd(y - yf)/2, from the design's calibration ('model:sd_ygap_half')
cd0 = base;
cd0.expectations.transforms(1).factor.mean = 'model:sd_ygap_half';
cd0.expectations.transforms(2).factor.mean = '-model:sd_ygap_half';
[~, info0] = hetlearn.load_model(spec, hetlearn.load_options(cd0));
sdh = mvnum(info0.nt.model_values, 'sd_ygap_half');
G = calib18_grid(sdh);
if nargin < 2 || isempty(rows)
    rows = 1:numel(G);
end
hd = qq(1966, 1):qq(2019, 4);
rng = struct('pinf', [min(db.pinfobs(hd) * sc.pinfobs), max(db.pinfobs(hd) * sc.pinfobs)], ...
    'dc', [min(db.dc(hd) * sc.dc), max(db.dc(hd) * sc.dc)]);
for r = rows
    c = base;
    c.id = sprintf('br18_calib_%02d', r);
    c.compare_with = {};
    if ischar(G(r).g)
        c.expectations.transforms(1).factor.mean = G(r).g;
        c.expectations.transforms(2).factor.mean = ['-' G(r).g];
    else
        c.expectations.transforms(1).factor.mean = G(r).g;
        c.expectations.transforms(2).factor.mean = -G(r).g;
    end
    c.switching.intensity = G(r).chi;
    c.switching.memory = G(r).omega;
    M = G(r);
    M.g_value = ternary(ischar(G(r).g), sdh, G(r).g);
    M.status = 'ok';
    M.error = '';
    t0 = tic;
    try
        res = hetlearn.run(c, 'save', false, 'quiet', true);
    catch err
        res = [];
        M.status = 'error';
        M.error = one_line(err.message);
    end
    M.runtime_s = toc(t0);
    M.data_pinf_min = rng.pinf(1);
    M.data_pinf_max = rng.pinf(2);
    M.data_dc_min = rng.dc(1);
    M.data_dc_max = rng.dc(2);
    f = {'fac_hist', 'fac_fore', 'pinf_avg', 'pinf_min', 'pinf_max', 'pinf_end', 'dc_min', 'dc_max', ...
        'ext_2022Q2', 'ext_min', 'ext_max', 'ext_sd', 'ext_corner', 'pes_2022Q2', 'pes_min', 'pes_max', ...
        'pes_sd', 'pes_corner'};
    for k = 1:numel(f)
        M.(f{k}) = NaN;
    end
    if ~isempty(res)
        hz = res.dates.horizon;
        p = res.paths.pinfobs(hz) * sc.pinfobs;
        dcv = res.paths.dc(hz) * sc.dc;
        isFac = startsWith(res.events.type, 'projection');
        M.fac_hist = sum(isFac & strcmp(res.events.stage, 'history'));
        M.fac_fore = sum(isFac & strcmp(res.events.stage, 'forecast'));
        M.pinf_avg = mean(p);
        M.pinf_min = min(p);
        M.pinf_max = max(p);
        M.pinf_end = p(end);
        M.dc_min = min(dcv);
        M.dc_max = max(dcv);
        dts = res.dates.record;
        io = find(abs(double(dts(:)) - double(res.dates.origin)) < 1e-6, 1);
        for pr = {{'ext', 'pinf', 'EXT'}, {'pes', 'c', 'PES'}}
            q = pr{1};
            s = reshape(res.learning.(q{2}).(['n_' q{3}])(dts), [], 1);
            M.([q{1} '_2022Q2']) = s(io);
            M.([q{1} '_min']) = min(s);
            M.([q{1} '_max']) = max(s);
            M.([q{1} '_sd']) = std(s);
            M.([q{1} '_corner']) = mean(s < 0.02 | s > 0.98);
        end
    end
    M.c1 = strcmp(M.status, 'ok');
    M.c2 = M.c1 && M.pinf_min >= rng.pinf(1) && M.pinf_max <= rng.pinf(2) && M.dc_min >= rng.dc(1) && M.dc_max <= rng.dc(2);
    M.c3 = M.c1 && M.ext_corner <= 0.10 && M.pes_corner <= 0.10 && M.ext_sd >= 0.02 && M.pes_sd >= 0.02;
    M.pass = M.c1 && M.c2 && M.c3;
    save(fullfile(cdir, sprintf('row_%02d.mat', r)), 'M');
    fprintf('calib18 row %2d %-34s g %.3g chi %.3g omega %.3g: %s, pinf %.2f..%.2f, dc %.1f..%.1f, EXT sd %.3f corner %.2f, PES sd %.3f corner %.2f, fac %g/%g -> %s (%.1f s)\n', ...
        r, M.tag, M.g_value, M.chi, M.omega, M.status, M.pinf_min, M.pinf_max, M.dc_min, M.dc_max, M.ext_sd, ...
        M.ext_corner, M.pes_sd, M.pes_corner, M.fac_hist, M.fac_fore, ternary(M.pass, 'PASS', 'fail'), M.runtime_s);
end
% merge every row saved so far
T = [];
fl = dir(fullfile(cdir, 'row_*.mat'));
if numel(fl) < numel(G)
    fprintf('calib18: %d of %d rows done; app1_calib18.csv is written when all are done.\n', numel(fl), numel(G));
    return
end
A = cell(numel(G), 1);
for r = 1:numel(G)
    tmp = load(fullfile(cdir, sprintf('row_%02d.mat', r)), 'M');
    A{r} = tmp.M;
end
A = [A{:}];
d = arrayfun(@(a) a.dist, A);
pass = arrayfun(@(a) a.pass, A);
best = NaN;
if any(pass)
    dd = d;
    dd(~pass) = Inf;
    [~, best] = min(dd);
end
for r = 1:numel(A)
    A(r).chosen = double(r == best);
end
cols = {'row', 'tag', 'label', 'g_value', 'chi', 'omega', 'published', 'dist', 'status', 'error', 'runtime_s', ...
    'fac_hist', 'fac_fore', 'pinf_avg', 'pinf_min', 'pinf_max', 'pinf_end', 'dc_min', 'dc_max', 'data_pinf_min', ...
    'data_pinf_max', 'data_dc_min', 'data_dc_max', 'ext_2022Q2', 'ext_min', 'ext_max', 'ext_sd', 'ext_corner', ...
    'pes_2022Q2', 'pes_min', 'pes_max', 'pes_sd', 'pes_corner', 'c1', 'c2', 'c3', 'pass', 'chosen'};
C = cell(numel(A), numel(cols));
for r = 1:numel(A)
    for k = 1:numel(cols)
        v = A(r).(cols{k});
        if islogical(v)
            v = double(v);
        end
        C{r, k} = v;
    end
end
write_cols(fullfile(odir, 'app1_calib18.csv'), cols, cells_to_cols(C));
T = A;
if isnan(best)
    fprintf('calib18: no setting passes the three criteria.\n');
else
    fprintf('calib18: chosen row %d (%s): g %.4g, intensity %.4g, memory %.4g\n', best, A(best).tag, ...
        A(best).g_value, A(best).chi, A(best).omega);
end
end


function G = calib18_grid(sdh)
% Row 1 the design's calibration, then g x intensity x memory around the converted published values
% (g 0.5, intensity 1, memory 0.125 = row 2).
gd = (1 + 0.02 * (2 * sdh)^2) / 2;              % (beta + delta var(y - yf))/2 in %, beta 1, delta 0.02 per %
gs = {0.5, 0.25, gd, 1.0};
gl = {'0.5 (beta/2)', '0.25', sprintf('%.3g (beta and delta)', gd), '1.0'};
cs = [1, 1/9, 0.5, 2];
os = [0.125, 0.5, 0.8];
G = struct('row', 1, 'tag', 'design', 'label', 'design calibration (g = sd(y - yf)/2, intensity 2, memory 0.8)', ...
    'g', 'model:sd_ygap_half', 'chi', 2, 'omega', 0.8, 'published', 0, 'dist', Inf);
r = 1;
for i = 1:numel(gs)
    for j = 1:numel(cs)
        for k = 1:numel(os)
            r = r + 1;
            g = gs{i};
            dist = (i ~= 1) + (j ~= 1) + (k ~= 1) + (abs(log(g / 0.5)) + abs(log(cs(j))) + abs(log(os(k) / 0.125))) / 100;
            G(r) = struct('row', r, 'tag', sprintf('g%.3g_chi%.3g_om%.3g', g, cs(j), os(k)), ...
                'label', sprintf('g %s, intensity %.3g, memory %.3g', gl{i}, cs(j), os(k)), 'g', g, 'chi', cs(j), ...
                'omega', os(k), 'published', double(i == 1 && j == 1 && k == 1), 'dist', dist);
        end
    end
end
end


% =========================================================================
function [mech, par, src, pop] = describe(id, c, o, mv)
% Mechanism, key parameters (numbers read from the options and model values), source, population.
g = @(x) sprintf('%g', x);
pop = '';
switch id
    case 'a1_re'
        mech = 'Every agent RE; RE agents see data up to t-1 for inflation';
        par = 'published SW07 mode; no learning';
        src = 'Smets and Wouters (2007)';
        pop = 'RE';
    case 'a1_learn'
        mech = 'RE agents (anchored, t-1 information) and AR(1) learners on inflation; shares switch on past squared errors';
        par = sprintf('KOZ gain from %s; intensity %s, memory %s; initial learners'' share %s', g(o.gain.value), ...
            g(o.switching.intensity), g(o.switching.memory), g(o.shares.init_n2));
        src = 'Ozden (2025, IJCB); gain: Kostyshyna, Ozden and Zhang (2024)';
        pop = 'RE, BR';
    case 'br01a_levelk_egm'
        mech = 'Level-k reasoners on a learned level 0 replace the RE agents; shares switch';
        par = sprintf('levels 1 and 2 (K = %d) on the AR(1) learner; equal initial shares; intensity %s, memory %s', ...
            max(cellfun(@(t) getf(t, 'k', 0), c.expectations.types)), g(o.switching.intensity), g(o.switching.memory));
        src = 'Evans, Gibbs and McGough (2025); K from Beaudry, Carter and Lahiri (2023)';
        pop = 'L0, L1, L2';
    case 'br01b_levelk_bcl'
        mech = 'Everyone forms the level-2 forecast on the learned AR(1) seed';
        par = sprintf('k = %d; shares fixed (L0 %s, L2 %s)', c.expectations.types{2}.k, g(c.shares.fixed.L0), g(c.shares.fixed.L2));
        src = 'Beaudry, Carter and Lahiri (2023)';
        pop = 'L0 (share 0), L2';
    case 'br04_shallow'
        t = c.expectations.transforms;
        mech = 'RE agents scale their forward expectations by a flat lambda, by agent role';
        par = sprintf('lambda households %s, price and wage setters %s, inflation in the real rate %s', ...
            g(t(1).value), g(t(2).value), g(t(3).value));
        src = 'Angeletos and Sastry (2021); values from Gust, Herbst and Lopez-Salido (2020)';
        pop = 'RE, BR';
    case {'br05a_cd', 'br05b_cd_learn'}
        t = c.expectations.transforms;
        if strcmp(id, 'br05a_cd')
            mech = 'Cognitive discounting of every forward expectation (flex block RE), all types';
            src = 'Gabaix (2020); m from Meggiorini (2023)';
        else
            mech = 'Cognitive discounting of the inflation expectation of RE agents and learners';
            src = 'Gabaix (2020); m from Meggiorini and Milani (2021)';
        end
        par = sprintf('m = %s, D(h) = m^h (h = 2 for t-1 inflation forecasts)', g(t(1).value));
        pop = 'RE, BR';
    case 'br06_hyperbolic'
        t = c.expectations.transforms;
        mech = 'As-if hyperbolic discounting of every forward expectation (flex block RE), all types';
        par = sprintf('alpha = %s, D(h) = 1/(1 + alpha h) (proposed: half-life one year)', g(t(1).value));
        src = 'Gabaix and Laibson (NBER WP 23254)';
        pop = 'RE, BR';
    case 'br07_myopia_anchoring'
        t = c.expectations.transforms;
        mech = 'In the price Phillips curve the inflation expectation becomes omega_f E pinf + b pinf(t-1), all types';
        par = sprintf('omega_f = %s, b = %s (omega_b 0.43 / 0.99)', g(t(1).value(1)), g(t(1).value(2)));
        src = 'Angeletos and Huo (2021), Table 1 (Coibion-Gorodnichenko K = 1.193)';
        pop = 'RE, BR';
    case 'br10_diagnostic'
        t = c.expectations.transforms;
        mech = 'Diagnostic agents replace the RE agents, forecasting (1 + theta) E_t - theta E_(t-1) (one-period memory)';
        par = sprintf('theta = %s', g(t(1).value));
        src = 'L''Huillier, Singh and Yoo (2024)';
        pop = 'RE (diagnostic), BR';
    case 'br17_heuristics'
        mech = 'Adaptive, weak-trend, strong-trend and anchoring-and-adjustment rules replace RE agents and learners';
        par = sprintf('rules 0.65/0.35, 0.4, 1.3, 0.5 (LAA anchor: sample mean); intensity %s, memory %s, inertia %s, unnormalized fitness', ...
            g(o.switching.intensity), g(o.switching.memory), g(o.switching.inertia));
        src = 'Anufriev and Hommes (2012)';
        pop = 'ADA, WTR, STR, LAA';
    case 'br18_degrauwe'
        gm = c.expectations.transforms(1).factor.mean;
        if ischar(gm)
            gtxt = sprintf('sd(y - yf)/2 = %s in the RE limit', fmtnum(mvnum(mv, 'sd_ygap_half'), '%.3g'));
        else
            gtxt = g(gm);
        end
        mech = 'Targeters and extrapolators forecast inflation; optimists and pessimists form the consumption expectation';
        par = sprintf(['bias g = %s on expected consumption, intensity %s, memory %s (De Grauwe converted to %% and ' ...
            'quarters: 0.5, 1, 0.125; the closest setting that passes the search)'], gtxt, g(o.switching.intensity), ...
            g(o.switching.memory));
        src = ['De Grauwe (2011, Economic Theory 47; CESifo WP 2418, Appendix A: beta = 0.01, delta = 2, ' ...
            'gamma = 10000, rho = 0.5, decimal units, months)'];
        pop = 'TAR, EXT (inflation); OPT, PES (consumption)';
    case 'br19_target_believers'
        mech = 'Target believers (forecast = steady state) added beside RE agents and learners';
        par = sprintf('initial shares 1/3 each; intensity %s, memory %s', g(o.switching.intensity), g(o.switching.memory));
        src = 'Hommes and Lustenhouwer (2019)';
        pop = 'RE, BR, TB';
    case 'br20_sac'
        mech = 'SAC learning (mean, autocorrelation, variance) of the seven sticky expectations; no RE agents';
        par = sprintf('constant gain %s', g(o.gain.value));
        src = 'Hommes, Mavromatis, Ozden and Zhu (2023), Table 1';
        pop = 'BR (all agents)';
    case 'br23_intercept_only'
        mech = 'Learners forecast the RE forecast plus a learned mean of its error';
        par = sprintf('KOZ gain from %s (baseline)', g(o.gain.value));
        src = 'Gati (2023); Carvalho, Eusepi, Moench and Preston (2023)';
        pop = 'RE, IO';
    case 'br24_mean_only'
        mech = 'Learners'' inflation PLM keeps only the constant (exponential smoothing)';
        par = sprintf('KOZ gain from %s (baseline)', g(o.gain.value));
        src = 'adaptive expectations; gain: Kostyshyna, Ozden and Zhang (2024)';
        pop = 'RE, BR';
    case 'br25a_kf_ar2'
        mech = 'Kalman-filter learning of AR(2) rules for the seven sticky expectations; no RE agents';
        par = sprintf('gamma = %s (constant-gain equivalent; V mapping proposed)', g(o.beliefs.kf.gamma));
        src = 'Slobodyan and Wouters (2012a); gamma from their 2008 draft';
        pop = 'BR (all agents)';
    case 'br25b_kf_average'
        mech = 'Equal-weight average of five small models per sticky expectation, Kalman-filter learning; no RE agents';
        par = sprintf('gamma = %s; fixed weights %s each', g(o.beliefs.kf.gamma), g(c.shares.fixed.M1));
        src = 'Slobodyan and Wouters (2012a); gamma from their 2008 draft';
        pop = 'M1-M5';
    case 'br26_experience'
        mech = 'AR(1) learners with an experience-based constant gain';
        par = sprintf('constant gain %s per quarter', g(o.gain.value));
        src = 'Malmendier and Nagel (2016); Nagel and Xu (2022)';
        pop = 'RE, BR';
    case 'br27_bma'
        s2 = NaN;
        chi = NaN;
        if isfield(mv, 'bma')
            if isfield(mv.bma, 'sigma2') && isstruct(mv.bma.sigma2)
                s2 = mvnum(mv.bma.sigma2, 'pinf');      % sigma2.<learning variable>
            else
                s2 = mvnum(mv.bma, 'sigma2');
            end
            chi = mvnum(mv.bma, 'chi');
        end
        mech = 'Shares are posterior model probabilities (cumulative squared errors, no forgetting)';
        par = sprintf('intensity 1/(2 sigma^2) = %s, sigma^2 = %s (RE(t-1) two-step error variance, proposed); memory %s', ...
            fmtnum(chi, '%.3g'), fmtnum(s2, '%.3g'), g(o.switching.memory));
        src = 'Evans, Honkapohja, Sargent and Williams (2013); Cho and Kasa (2017)';
        pop = 'RE, BR';
    case 'br29_wedge'
        f = c.expectations.transforms(1).factor;
        mech = 'AR(1) belief wedge added to the inflation expectation of every type';
        par = sprintf('rho = %s, shock std %s (BBH volatility / 4, flagged), mean %s', g(f.rho), g(f.std), g(f.mean));
        src = 'Bhandari, Borovicka and Ho (2025); Milani (2011, 2017)';
        pop = 'RE, BR';
    case 'br31_confidence'
        f = c.expectations.transforms(1).factor;
        sd = mvnum(mv, 'acd51');
        ld = '';
        if isfield(mv, 'projection') && isstruct(mv.projection)
            fn = fieldnames(mv.projection);
            fn = fn(cellfun(@(k) isnumeric(mv.projection.(k)), fn));   % the loadings (not the 'economy' note)
            ld = strjoin(cellfun(@(k) sprintf('%s %.3g', k, mvnum(mv.projection, k)), fn', 'UniformOutput', false), ', ');
            ld = ['; loadings ' ld];
        end
        mech = 'Common AR(1) confidence factor biasing expected consumption, investment and hours';
        par = sprintf('rho = %s; shock std %s (51%% of output variance at 6-32 quarters, calibrated)%s', ...
            g(f.rho), fmtnum(sd, '%.3g'), ld);
        src = 'Angeletos, Collard and Dellas (2018)';
        pop = 'RE, BR';
    case 'br33_farmer'
        mech = 'Naive believers expect nominal GDP growth to stay at its last value';
        par = 'no free parameters';
        src = 'Farmer and Nicolo (2018)';
        pop = 'RE, FN';
    otherwise
        mech = '';
        par = '';
        src = '';
end
end


function v = mvnum(s, f)
% A number from a model-values struct: s.(f) if numeric, else its value/std/mean field.
v = NaN;
if ~isstruct(s) || ~isfield(s, f)
    return
end
x = s.(f);
if isnumeric(x) && ~isempty(x)
    v = double(x(1));
elseif isstruct(x)
    for k = {'value', 'std', 'mean', 'sigma', 'g'}
        if isfield(x, k{1}) && isnumeric(x.(k{1})) && ~isempty(x.(k{1}))
            v = double(x.(k{1})(1));
            return
        end
    end
end
end


function s = fmtnum(x, fmt)
if isnan(x)
    s = 'n/a';
else
    s = sprintf(fmt, x);
end
end


function v = getf(s, f, d)
v = d;
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
end
end


function c = ternary_c(mask, a, b)
c = repmat({b}, numel(mask), 1);
c(mask) = {a};
end


function v = ternary(c, a, b)
if c
    v = a;
else
    v = b;
end
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
    error('run_br_app1: cannot write %s', file);
end
fprintf(fid, '%s\n', strjoin(header, ','));
if n > 0
    lines = cellstr(join(S, ",", 2));
    fprintf(fid, '%s\n', lines{:});
end
fclose(fid);
end
