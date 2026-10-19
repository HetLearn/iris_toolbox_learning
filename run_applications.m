function L = run_applications(groups, varargin)
%RUN_APPLICATIONS  Run the SW07 applications, model variants and forecast evaluation.
%
%   run_applications                     every group below, in order ('all')
%   run_applications('app1')             one group
%   run_applications({'app3', 'var2'})   several groups, in the order given
%   run_applications('a5_markup_learn')  one scenario, by its id (any scenario function on the MATLAB path)
%   run_applications('decompose')        only the three shock decompositions of app 6
%   run_applications('eval_part', variants, parts)
%                                        evaluation parts only, e.g. ('eval_part', 'e02_learn', 1:3);
%                                        lets you run parts in parallel MATLAB sessions
%   run_applications('eval_part', variants, parts, K)
%                                        the same with the origins cut into K parts instead of 6
%                                        (folders eval_<variant>_p<k>of<K>); the merge only needs
%                                        each variant's parts to cover every origin exactly once
%   run_applications('eval_merge')       merge the evaluation parts into the final tables
%   L = run_applications(...)            also returns this call's rows of the run log
%
%   Run it from the project root (it calls setup_paths if IRIS is not started).
%   Every scenario is one file in scenarios/sw07/<folder>/<id>.m; open it to see
%   or change its settings (base/sw07_re.m lists every option). Each run
%   overwrites results/<id>/. A failing scenario is reported, logged and
%   skipped, and the next one runs. Every run, decomposition and evaluation
%   part adds one row to results/run_log.csv: logged, group, id, status
%   (ok | error), runtime_s, events, message.
%
%   GROUPS (in dependency order; times measured on 2026-10-18, plus about 15 s to start MATLAB)
%   group  folder             what it runs                                                time
%   app1   app1_peak          a1_re, a1_learn: forecast from the 2022Q2 peak            ~30 s
%   app2   app2_replay        a2_re, a2_learn: replay of the RE-smoothed shocks          ~10 s
%   app3   app3_policy        a3_{loose,tight}_{re,learn}: rate 100 bp a year below /     ~30 s
%                             above the Taylor rule in 2022Q3-2023Q2
%   app4   app4_ramsey        a4_rule_{re,learn} (Taylor rule, 80-quarter loss), then     ~2.5 min
%                             a4_ramsey_{balanced,hawk,dove,smooth}_{re,re_mc,learn}
%                             (_re_mc: model-consistent RE agents, the RE Ramsey benchmark)
%   app5   app5_density       a5_{markup,demand}_re (500 draws, fast RE path, 30 s       ~14 min
%                             each), then a5_{markup,demand}_learn (500 draws, 0.71 s
%                             per draw, 6.5 min each)
%   app6   app6_history       a6_smooth_re, a6_smooth_learn, a6_inv_learn (history to     ~40 s
%                             2026Q2), then the shock decompositions of pinfobs and dy
%                             (results/<id>/decomposition.csv, decomposition_check.csv)
%   var1   var1_re_variant    v1_mc_learn: model-consistent RE agents                     ~10 s
%   var2   var2_plm           v2_ar2, v2_ar1nc, v2_reg, v2_var3, v2_var12: other PLMs    ~70 s
%   var3   var3_allvars       v3_all, v3_all_alm, v3_all_none: learning on all 12        ~35 s
%                             variables under each projection facility
%   var4   var4_gain          v4_koz, v4_koz_full: endogenous gain (KOZ 2024)             ~10 s
%   eval   eval               recursive real-time evaluation of e01_re ... e10_allvars:  ~2.7 hours
%                             origins 1990Q1-2024Q2, horizon 8, benchmark e01_re, in
%                             6 parts of 23 origins per variant, then the merge (per
%                             variant: RE 2.5 min, learning 10-23 min, VAR(1) in 12
%                             variables 41 min; 4 parallel sessions: about 47 min)
%   all    every group above in this order
%
%   Evaluation outputs: results/eval_sw07_v3/parts/eval_<variant>_p<k>/ (one folder
%   per part), merged into results/eval_sw07_v3/errors_long.csv, metrics.csv,
%   relative_rmse.csv, dm.csv (hetlearn.evaluate_tables: RMSE, bias, MAE,
%   relative RMSE, Diebold-Mariano with the HLN correction) and settings.mat.
%   Subsamples by target date: s1990_2007, s2008_2019, s2020_2026. A part takes
%   0.5-7 minutes (later origins are slower: longer histories); run several in
%   parallel sessions only after the model caches exist (run any other group once
%   first), never two sessions on the same part, and keep sessions of variants with
%   the same PLM on different parts until their real-time filter caches exist.
%
%   Summary tables for the report: run('results/summary_v3/build_summary_v3.m')
%   after this function.
%
%   See also hetlearn.run, hetlearn.decompose, hetlearn.evaluate, hetlearn.evaluate_tables.

if nargin < 1 || isempty(groups)
    groups = 'all';
end
groups = cellstr(groups);
root = fileparts(mfilename('fullpath'));
setup_paths();                                % IRIS (started once), toolbox, config, scenarios/
G = group_table();
L = log_table(0);

if any(strcmp(groups{1}, {'eval_part', 'eval_merge'}))
    switch groups{1}
        case 'eval_part'
            if numel(varargin) < 2
                error('run_applications: eval_part needs variants and parts, e.g. (''eval_part'', ''e02_learn'', 1:3).');
            end
            K = [];
            if numel(varargin) >= 3
                K = varargin{3};
            end
            L = eval_parts(root, cellstr(varargin{1}), varargin{2}, K);
        case 'eval_merge'
            L = eval_merge(root);
    end
    return
end
if any(strcmp(groups, 'all'))
    groups = G(:, 1)';
end

for g = 1:numel(groups)
    name = groups{g};
    k = find(strcmp(G(:, 1), name), 1);
    if strcmp(name, 'decompose')
        L = [L; decompose_app6(root)]; %#ok<AGROW>
        continue
    end
    if isempty(k)
        if exist(name, 'file') == 2
            gi = find(cellfun(@(c) any(strcmp(c, name)), G(:, 2)), 1);
            grp = 'single';
            if ~isempty(gi)
                grp = G{gi, 1};
            end
            L = [L; run_ids(root, grp, {name})]; %#ok<AGROW>
            continue
        end
        error('run_applications: unknown group or scenario "%s".', name);
    end
    fprintf('\n==== run_applications: group %s ====\n', name);
    if strcmp(name, 'eval')
        E = eval_settings();
        L = [L; eval_parts(root, E.variants, 1:E.nparts)]; %#ok<AGROW>
        L = [L; eval_merge(root)]; %#ok<AGROW>
        continue
    end
    L = [L; run_ids(root, name, G{k, 2})]; %#ok<AGROW>
    if strcmp(name, 'app6')
        L = [L; decompose_app6(root)]; %#ok<AGROW>
    end
end
fprintf('\nrun_applications: %d runs, %d ok, %d errors (log: results/run_log.csv)\n', height(L), ...
    sum(strcmp(L.status, 'ok')), sum(~strcmp(L.status, 'ok')));
end


% =========================================================================================
function G = group_table()
% group name, scenario ids in dependency order (parents and comparison targets first)
G = {
    'app1', {'a1_re', 'a1_learn'}
    'app2', {'a2_re', 'a2_learn'}
    'app3', {'a3_loose_re', 'a3_tight_re', 'a3_loose_learn', 'a3_tight_learn'}
    'app4', {'a4_rule_re', 'a4_rule_learn', ...
             'a4_ramsey_balanced_re', 'a4_ramsey_hawk_re', 'a4_ramsey_dove_re', 'a4_ramsey_smooth_re', ...
             'a4_ramsey_balanced_re_mc', 'a4_ramsey_hawk_re_mc', 'a4_ramsey_dove_re_mc', 'a4_ramsey_smooth_re_mc', ...
             'a4_ramsey_balanced_learn', 'a4_ramsey_hawk_learn', 'a4_ramsey_dove_learn', 'a4_ramsey_smooth_learn'}
    'app5', {'a5_markup_re', 'a5_demand_re', 'a5_markup_learn', 'a5_demand_learn'}
    'app6', {'a6_smooth_re', 'a6_smooth_learn', 'a6_inv_learn'}
    'var1', {'v1_mc_learn'}
    'var2', {'v2_ar2', 'v2_ar1nc', 'v2_reg', 'v2_var3', 'v2_var12'}
    'var3', {'v3_all', 'v3_all_alm', 'v3_all_none'}
    'var4', {'v4_koz', 'v4_koz_full'}
    'eval', {}
    };
end


function E = eval_settings()
% The forecast evaluation: change it here.
E = struct();
E.name = 'sw07_v3';                                   % results/eval_sw07_v3/
E.variants = {'e01_re', 'e02_learn', 'e03_learn_mc', 'e04_learn_all_learners', 'e05_ar2', ...
    'e06_ar1nc', 'e07_reg', 'e08_var3', 'e09_var12', 'e10_allvars'};
E.benchmark = 'e01_re';
E.origins = qq(1990, 1):qq(2024, 2);                  % 138 origins
E.horizon = 8;
E.nparts = 6;                                         % parts per variant (23 origins each)
E.subsamples = struct('s1990_2007', [qq(1990, 1), qq(2007, 4)], ...
    's2008_2019', [qq(2008, 1), qq(2019, 4)], 's2020_2026', [qq(2020, 1), qq(2026, 2)]);
E.opts = struct('horizon', E.horizon, 'subsamples', E.subsamples, 'realtime', true, ...
    'dm', true, 'dm_hln', true, 'quiet', true);
end


% =========================================================================================
function L = run_ids(root, group, ids)
L = log_table(0);
for i = 1:numel(ids)
    id = ids{i};
    fprintf('\n---- %s: %s ----\n', group, id);
    t0 = tic;
    try
        res = hetlearn.run(feval(id));
        nev = height(res.events);
        L = [L; log_row(root, group, id, 'ok', toc(t0), nev, '')]; %#ok<AGROW>
        fprintf('%s: ok, %.1f s, %d events\n', id, toc(t0), nev);
    catch err
        msg = one_line(err);
        fprintf(2, '%s: ERROR after %.1f s: %s\n', id, toc(t0), msg);
        L = [L; log_row(root, group, id, 'error', toc(t0), NaN, msg)]; %#ok<AGROW>
    end
end
end


function L = decompose_app6(root)
% Shock decompositions of inflation and output growth, 1966Q1-2026Q2, the groups of app 6.
groups = struct('demand', {{'eb', 'eg', 'eqs'}}, 'monetary', {{'em'}}, 'supply', {{'ea'}}, ...
    'price_markup', {{'epinf'}}, 'wage_markup', {{'ew'}});
ids = {'a6_smooth_re', 'a6_smooth_learn', 'a6_inv_learn'};
rng = [qq(1966, 1), qq(2026, 2)];
L = log_table(0);
for i = 1:numel(ids)
    t0 = tic;
    try
        D = hetlearn.decompose(ids{i}, {'pinfobs', 'dy'}, rng, struct('groups', groups));
        ck = D.check;
        T = table({ids{i}}, {D.method}, getf(ck, 'additivity_maxerr'), getf(ck, 'recon_maxerr'), ...
            getf(ck, 'n_solve'), getf(ck, 'n_backward'), D.runtime_s, 'VariableNames', ...
            {'scenario', 'method', 'additivity_maxerr', 'recon_maxerr', 'n_solve', 'n_backward', 'runtime_s'});
        disp(T);
        writetable(T, fullfile(root, 'results', ids{i}, 'decomposition_check.csv'));
        L = [L; log_row(root, 'app6', ['decompose:' ids{i}], 'ok', toc(t0), NaN, '')]; %#ok<AGROW>
    catch err
        msg = one_line(err);
        fprintf(2, 'decompose %s: ERROR: %s\n', ids{i}, msg);
        L = [L; log_row(root, 'app6', ['decompose:' ids{i}], 'error', toc(t0), NaN, msg)]; %#ok<AGROW>
    end
end
end


function v = getf(s, f)
v = NaN;
if isfield(s, f) && ~isempty(s.(f))
    v = double(s.(f));
end
end


% =========================================================================================
function L = eval_parts(root, variants, parts, K)
% Evaluation parts: part k of variant v = the k-th of K consecutive blocks of origins (K =
% E.nparts by default; folder eval_<variant>_p<k>, or eval_<variant>_p<k>of<K> for another K).
E = eval_settings();
if nargin < 4 || isempty(K)
    K = E.nparts;
end
pdir = fullfile(root, 'results', ['eval_' E.name], 'parts');
if exist(pdir, 'dir') ~= 7
    mkdir(pdir);
end
L = log_table(0);
for v = 1:numel(variants)
    for k = reshape(parts, 1, [])
        org = E.origins(part_index(numel(E.origins), K, k));
        name = sprintf('%s_p%d', variants{v}, k);
        if K ~= E.nparts
            name = sprintf('%s_p%dof%d', variants{v}, k, K);
        end
        fprintf('\n---- eval part %s: %s-%s (%d origins) ----\n', name, char(dat2str(org(1))), ...
            char(dat2str(org(end))), numel(org));
        t0 = tic;
        try
            o = E.opts;
            o.results_dir = pdir;
            R = hetlearn.evaluate(name, variants(v), org, o);
            nf = height(R.settings.failures);
            st = 'ok';
            msg = '';
            if nf > 0
                st = 'error';
                msg = sprintf('%d failed origins, first %s: %s', nf, R.settings.failures.origin{1}, ...
                    R.settings.failures.message{1});
            end
            L = [L; log_row(root, 'eval', ['eval:' name], st, toc(t0), sum(R.settings.events(:)), msg)]; %#ok<AGROW>
            fprintf('eval part %s: %s, %.1f s\n', name, st, toc(t0));
        catch err
            msg = one_line(err);
            fprintf(2, 'eval part %s: ERROR: %s\n', name, msg);
            L = [L; log_row(root, 'eval', ['eval:' name], 'error', toc(t0), NaN, msg)]; %#ok<AGROW>
        end
    end
end
end


function idx = part_index(n, K, k)
if k < 1 || k > K
    error('run_applications: part %d outside 1-%d.', k, K);
end
idx = (round((k - 1) * n / K) + 1):round(k * n / K);
end


function L = eval_merge(root)
% Merge the parts: check that each variant's parts partition the origins, concatenate the
% errors, and compute the tables with hetlearn.evaluate_tables (the function hetlearn.evaluate uses).
E = eval_settings();
t0 = tic;
gdir = fullfile(root, 'results', ['eval_' E.name]);
d = dir(fullfile(gdir, 'parts', 'eval_*'));
d = d([d.isdir]);
oStr = reshape(hetlearn.util.date_str(E.origins), [], 1);
nO = numel(oStr);
nV = numel(E.variants);
cover = zeros(nO, nV);
nEv = NaN(nO, nV);
hmode = repmat({''}, 1, nV);
errs = cell(0, 1);
fail = cell(0, 3);
pinfo = cell(0, 6);
obs = {};
scale = [];
for p = 1:numel(d)
    pf = fullfile(d(p).folder, d(p).name);
    if exist(fullfile(pf, 'settings.mat'), 'file') ~= 2
        continue
    end
    S = load(fullfile(pf, 'settings.mat'));
    s = S.settings;
    v = find(strcmp(E.variants, s.ids{1}), 1);
    if isempty(v) || numel(s.ids) ~= 1
        continue
    end
    if s.horizon ~= E.horizon || ~s.realtime || ~s.dm_hln
        error('run_applications: part %s has other settings (H %d, realtime %d, dm_hln %d).', ...
            d(p).name, s.horizon, s.realtime, s.dm_hln);
    end
    [ok, io] = ismember(reshape(s.origin_str, [], 1), oStr);
    if ~all(ok)
        error('run_applications: part %s has origins outside the evaluation list.', d(p).name);
    end
    if any(cover(io, v) > 0)
        error('run_applications: variant %s has overlapping parts (%s).', E.variants{v}, d(p).name);
    end
    cover(io, v) = 1;
    nEv(io, v) = s.events(:, 1);
    hmode{v} = s.history_mode{1};
    if isempty(obs)
        obs = s.observables;
        scale = s.scale;
    end
    T = readtable(fullfile(pf, 'errors_long.csv'), 'Delimiter', ',', 'TextType', 'char', ...
        'DatetimeType', 'text');
    T.origin = cellstr(T.origin);
    T.target = cellstr(T.target);
    errs{end+1, 1} = T; %#ok<AGROW>
    f = s.failures;
    for r = 1:height(f)
        fail(end+1, :) = {f.variant{r}, f.origin{r}, f.message{r}}; %#ok<AGROW>
    end
    pinfo(end+1, :) = {s.ids{1}, d(p).name, s.origin_str{1}, s.origin_str{end}, numel(s.origin_str), ...
        s.runtime_s}; %#ok<AGROW>
end
if isempty(errs)
    error('run_applications: no evaluation parts in %s.', fullfile(gdir, 'parts'));
end
Terr = vertcat(errs{:});
[~, iv] = ismember(Terr.variant, E.variants);
[~, io] = ismember(Terr.origin, oStr);
[~, ik] = ismember(Terr.variable, obs);
[~, ord] = sortrows([iv, io, Terr.h, ik]);
Terr = Terr(ord, {'variant', 'origin', 'target', 'h', 'variable', 'actual', 'forecast', 'error'});
missing = cell(0, 2);
for v = 1:nV
    if any(cover(:, v) == 0)
        missing(end+1, :) = {E.variants{v}, sum(cover(:, v) == 0)}; %#ok<AGROW>
    end
end
TT = hetlearn.evaluate_tables(Terr, struct('variants', {E.variants}, 'variables', {obs}, ...
    'horizon', E.horizon, 'origins', E.origins, 'benchmark', E.benchmark, ...
    'subsamples', E.subsamples, 'dm', true, 'dm_hln', true, 'save', true, 'folder', gdir, ...
    'write_errors', true));
settings = struct('name', E.name, 'ids', {E.variants}, 'variants', {E.variants}, ...
    'origins', E.origins, 'origin_str', {oStr'}, 'horizon', E.horizon, 'benchmark', E.benchmark, ...
    'realtime', true, 'subsamples', E.subsamples, 'dm', true, 'dm_hln', true, ...
    'dm_kernel', TT.info.dm_kernel, 'dm_fallbacks', TT.info.dm_fallbacks, 'history_mode', {hmode}, ...
    'failures', cell2table(fail, 'VariableNames', {'variant', 'origin', 'message'}), ...
    'events', nEv, 'coverage', cover, 'n_runs', sum(cover(:)), 'missing_runs', sum(cover(:) == 0), ...
    'missing', {missing}, 'parts', cell2table(pinfo, 'VariableNames', {'variant', 'part', ...
    'first_origin', 'last_origin', 'n_origins', 'runtime_s'}), 'model', 'sw07', ...
    'observables', {obs}, 'scale', scale, 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
save(fullfile(gdir, 'settings.mat'), 'settings');
st = 'ok';
msg = '';
if settings.missing_runs > 0 || ~isempty(fail)
    st = 'error';
    msg = sprintf('%d missing runs, %d failures', settings.missing_runs, size(fail, 1));
end
fprintf('eval merge: %d parts, %d variants x %d origins, %d runs, %d missing, %d failures\n', ...
    size(pinfo, 1), nV, nO, settings.n_runs, settings.missing_runs, size(fail, 1));
L = log_row(root, 'eval', 'eval:merge', st, toc(t0), sum(nEv(:), 'omitnan'), msg);
end


% =========================================================================================
function L = log_table(n)
L = table(cell(n, 1), cell(n, 1), cell(n, 1), cell(n, 1), zeros(n, 1), zeros(n, 1), cell(n, 1), ...
    'VariableNames', {'logged', 'group', 'id', 'status', 'runtime_s', 'events', 'message'});
end


function L = log_row(root, group, id, status, rt, nev, msg)
% Append one row to results/run_log.csv and return it as a table row.
L = log_table(1);
L.logged = {datestr(now, 'yyyy-mm-dd HH:MM:SS')}; %#ok<TNOW1,DATST>
L.group = {group};
L.id = {id};
L.status = {status};
L.runtime_s = rt;
L.events = nev;
L.message = {msg};
f = fullfile(root, 'results', 'run_log.csv');
isNew = exist(f, 'file') ~= 2;
if exist(fileparts(f), 'dir') ~= 7
    mkdir(fileparts(f));
end
fid = fopen(f, 'a');
if fid < 0
    warning('run_applications: cannot write %s', f);
    return
end
if isNew
    fprintf(fid, 'logged,group,id,status,runtime_s,events,message\n');
end
ev = '';
if isfinite(nev)
    ev = sprintf('%d', nev);
end
fprintf(fid, '%s,%s,%s,%s,%.2f,%s,%s\n', L.logged{1}, group, id, status, rt, ev, csvq(msg));
fclose(fid);
end


function s = one_line(err)
s = err.message;
if ~isempty(err.identifier)
    s = [err.identifier ': ' s];
end
s = regexprep(s, '\s+', ' ');
end


function s = csvq(s)
s = char(s);
if any(s == ',' | s == '"')
    s = ['"' strrep(s, '"', '""') '"'];
end
end
