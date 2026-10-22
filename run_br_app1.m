function out = run_br_app1(cmd, varargin)
%RUN_BR_APP1  Application 1 for the bounded-rationality portfolio: runs and the CSV tables of its report.
%
%   run_br_app1('check')          load the options of the 9 scenarios (no run): syntax and validation
%   run_br_app1('run')            run the references a1_re, a1_learn, then the 7 variants of
%                                 scenarios/sw07/br_portfolio/, in this session
%   run_br_app1('run', ids)       only these scenario ids (cellstr), in the order given
%   run_br_app1('csv')            write results/br_portfolio/app1_*.csv from the saved runs
%   ids = run_br_app1('ids')      the 9 ids in report order (references first)
%
%   The variants (portfolio cut to seven on 2026-10-22 after docs/BR_audit.txt): 5b cognitive
%   discounting on the learning set, 7 myopia and anchoring, 10 diagnostic expectations,
%   19 target believers, 23 intercept learning on the RE forecast error, 24 mean-only
%   learners, 26 constant gain 0.018.
%
%   Run from the project root (it calls setup_paths if IRIS is not started). Each run is
%   hetlearn.run(feval(id)) and saves results/<id>/ like any scenario (the references
%   overwrite results/a1_re/ and results/a1_learn/ with the same runs). Every run inherits
%   the baseline's projection facility (config/master_options.m: 'alm' since 2026-10-21,
%   'none' on 2026-10-20); its events (projection_alm, projection_alm_shares) are recorded.
%   A run that still has no model solution stops with hetlearn:engine:noSolution or
%   :almUnstable and saves nothing: that stop is the result, and the status file records the
%   error, its period and the stage (a message that names no stage: history up to the
%   origin, forecast after it). No other facility is tried. For a stop in the forecast stage
%   after the first forecast quarter, the same scenario runs again with the horizon cut to
%   the quarters before the stop and compare_with off, saved in
%   results/br_portfolio/partial/<id>/. The engine solves the forecast quarter by quarter
%   with the beliefs and shares in force, so that run has the same path and shares up to
%   the last quarter that solves; the tables use it for the shares at the origin and the
%   path up to the stop, flagged complete = 0.
%   Sessions: the 9 runs took about two minutes in total on 2026-10-21, so one session is
%   enough. To split them, run the references first (the variants compare with them), then
%   give each session its own variants.
%
%   Writes (results/br_portfolio/)
%     status/<id>.mat, status/<id>.txt   one per run: status ok | stopped | error, error
%                                         identifier and message, stop period and stage,
%                                         runtime, partial run
%     app1_variants.csv     id, no, family, family_label, family_order, order, name, mechanism,
%                           key parameters (numbers from the scenario and the merged options),
%                           literature source, population, mode, scenario_file
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
% literature review) in the order of docs/DESIGN_br_extensions.md section 3. Since 2026-10-22
% only the seven variants that docs/BR_audit.txt keeps; the names follow its labelling advice
% (the name of 26 is set from its gain in describe).
F = {'ref', 'References'; 'disc', 'Discounting and horizons'; 'info', 'Information frictions'; ...
    'learn', 'Learning variants'; 'dist', 'Belief distortions'};
C = {
% id                       no     fam      name
'a1_re',                   'RE',  'ref',   'RE(t-1) benchmark'
'a1_learn',                'BL',  'ref',   'Baseline: RE agents and AR(1) learners'
'br05b_cd_learn',          '5b',  'disc',  'Cognitive discounting, learning set'
'br07_myopia_anchoring',   '7',   'info',  'Myopia and anchoring'
'br10_diagnostic',         '10',  'info',  'Diagnostic expectations'
'br23_intercept_only',     '23',  'learn', 'Intercept learning on the RE forecast error (KOZ gain), close to RE'
'br24_mean_only',          '24',  'learn', 'Mean-only learners'
'br26_experience',         '26',  'learn', 'Constant gain (MN-calibrated)'
'br19_target_believers',   '19',  'dist',  'Target believers'
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
    if any(strcmp(err.identifier, {'hetlearn:engine:noSolution', 'hetlearn:engine:almUnstable'}))
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
    [mech, par, src, pop, nm] = describe(id, c, o, V(i).name);
    if startsWith(id, 'br')
        sf = ['scenarios/sw07/br_portfolio/' id '.m'];
    else
        sf = ['scenarios/sw07/app1_peak/' id '.m'];
    end
    M(i, :) = {id, V(i).no, V(i).family, V(i).family_label, V(i).family_order, V(i).order, nm, mech, ...
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
function [mech, par, src, pop, name] = describe(id, c, o, name)
% Mechanism, key parameters (numbers read from the scenario and the options), source, population;
% the name of the variant table, or one built from the options.
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
    case 'br05b_cd_learn'
        t = c.expectations.transforms;
        mech = 'Cognitive discounting of the inflation expectation of RE agents and learners';
        par = sprintf('m = %s, D(h) = m^h (h = 2 for t-1 inflation forecasts)', g(t(1).value));
        src = 'Gabaix (2020); m from Meggiorini and Milani (2021)';
        pop = 'RE, BR';
    case 'br07_myopia_anchoring'
        t = c.expectations.transforms;
        mech = ['In the price Phillips curve the inflation expectation becomes omega_f E pinf + b pinf(t-1), all types. ' ...
            'SW07 keeps its own price indexation and habit, so this backward weight is added on top of them'];
        par = sprintf('omega_f = %s, b = %s (omega_b 0.43 / 0.99)', g(t(1).value(1)), g(t(1).value(2)));
        src = 'Angeletos and Huo (2021), Table 1 (Coibion-Gorodnichenko K = 1.193)';
        pop = 'RE, BR';
    case 'br10_diagnostic'
        t = c.expectations.transforms;
        mech = ['Diagnostic agents replace the RE agents, forecasting (1 + theta) E_t - theta E_(t-1) (one-period memory). ' ...
            'Only the t+1 expectations are diagnostic, without the current-variable terms of LSY'];
        par = sprintf('theta = %s', g(t(1).value));
        src = 'L''Huillier, Singh and Yoo (2024)';
        pop = 'RE (diagnostic), BR';
    case 'br19_target_believers'
        mech = 'Target believers (forecast = steady state) added beside RE agents and learners';
        par = sprintf('initial shares 1/3 each; intensity %s, memory %s', g(o.switching.intensity), g(o.switching.memory));
        src = 'Hommes and Lustenhouwer (2019)';
        pop = 'RE, BR, TB';
    case 'br23_intercept_only'
        mech = ['Learners forecast the RE forecast plus a learned mean of its error, switching against RE agents; ' ...
            'Gati''s state-dependent anchoring function is left out'];
        par = sprintf('KOZ gain from %s (baseline)', g(o.gain.value));
        src = 'Gati (2023); Carvalho, Eusepi, Moench and Preston (2023)';
        pop = 'RE, IO';
    case 'br24_mean_only'
        mech = 'Learners'' inflation PLM keeps only the constant (exponential smoothing)';
        par = sprintf('KOZ gain from %s (baseline)', g(o.gain.value));
        src = 'adaptive expectations; gain: Kostyshyna, Ozden and Zhang (2024)';
        pop = 'RE, BR';
    case 'br26_experience'
        name = sprintf('Constant gain %s (MN-calibrated)', g(o.gain.value));
        mech = 'AR(1) learners with the constant gain of experience-based learning, in aggregate (no cohorts, no age-dependent gains)';
        par = sprintf('constant gain %s per quarter', g(o.gain.value));
        src = 'Malmendier and Nagel (2016); Nagel and Xu (2022)';
        pop = 'RE, BR';
    otherwise
        mech = '';
        par = '';
        src = '';
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
