function E = evaluate(name, variants, origins, opts)
%EVALUATE  Recursive real-time forecast evaluation of scenario variants (DESIGN 17).
%
%   E = hetlearn.evaluate(name, variants, origins)
%   E = hetlearn.evaluate(name, variants, origins, opts)
%
%   Inputs
%     name      evaluation name; outputs go to <results_dir>/eval_<name>/
%     variants  cellstr of scenario function names (cfg = feval(name)); an
%               element may also be a cfg struct with .id (used by tests)
%     origins   forecast origins: a date vector, or [start, end]
%     opts      struct, every field optional:
%       .horizon      H (default 8)
%       .benchmark    variant id for relative RMSE and DM (default: first)
%       .dm           Diebold-Mariano tests (default true)
%       .dm_hln       Harvey-Leybourne-Newbold small-sample correction and
%                     t(n-1) p-values (default true)
%       .dm_kernel    '' (default: 'uniform' if dm_hln, else 'bartlett') |
%                     'uniform' | 'bartlett'
%       .subsamples   struct of [start, end] TARGET-date ranges, e.g.
%                     struct('pre2020', [qq(2010,1), qq(2019,4)]); metrics,
%                     relative RMSE and DM are also given for each
%       .realtime     history.realtime of every run (default true)
%       .results_dir  parent folder (default <project root>/results)
%       .save         write eval_<name>/ (default true)
%       .quiet        no progress lines (default false)
%
%   Runs. Each variant's cfg gets forecast.horizon = H, zero future shocks
%   (shocks.source 'none', no shocks.add), no conditions, density off,
%   compare_with empty and history.realtime = opts.realtime; then, for each
%   origin, forecast.origin = origin and hetlearn.run(..., 'save', false,
%   'quiet', true) with the model loaded once per variant and the RE filter
%   of that origin (hetlearn.re_filter 'end' = origin, disk cache per end
%   date) computed once and shared by all variants with the same PLM spec.
%   Only the observables' forecasts are kept. A failing run is recorded in
%   settings.failures and its errors are missing.
%   history.mode = 'inversion' (DESIGN 15): the backed-out history is real
%   time by construction (period t uses data up to t), so each such variant
%   gets ONE inversion over [history.inversion.start, last origin] on the
%   full-sample RE filter (it supplies only the state before the start),
%   keeping its learning state at every origin
%   (hetlearn.engine.core, ctx.inv_snapshots); the forecast at each origin
%   then starts from that state and the backed-out databank clipped at the
%   origin (ctx.history_cache). No real-time RE filters are computed for
%   PLM specs used only by inversion variants.
%   N agent types and forecast transforms (docs/DESIGN_br_extensions.md 1.1-1.5;
%   phase P6): supported. Such a variant's RE filter is that of its own RE
%   limit (its generated file, with the type forecasts, transform states and
%   factors), so it shares a filter only with variants of the same generated
%   file, parameter values, toggles and learning set. history.mode = 'inversion' is not
%   available with N types (hetlearn.load_options refuses it); 'kalman'
%   variants run through hetlearn.run like the others.
%
%   Errors: actual - forecast in report units (spec.report.scale.<obs>, 1 if
%   none), every observable, h = 1..H; targets without data are skipped.
%   Metrics by sample x variant x variable x h: n, RMSE, ME (bias), MAE.
%   Relative RMSE = RMSE(variant) / RMSE(benchmark) on the targets both have.
%   DM: d_t = e_variant^2 - e_benchmark^2 (mean < 0: variant more accurate),
%   DM = mean(d) / sqrt(LRV/n) with h-1 autocovariances; NaN when n < 2 or
%   LRV <= 0. Kernel opts.dm_kernel (review finding m2): 'uniform'
%   (default when dm_hln is true) LRV = gamma_0 + 2*sum_{k<h} gamma_k, the
%   rectangular estimator the HLN factor was derived for, with a fallback
%   to Bartlett where it is not positive (counted, settings.dm_fallbacks);
%   'bartlett' (default when dm_hln is false) Newey-West weights 1 - k/h.
%   With opts.dm_hln (default) the statistic is multiplied by
%   sqrt((n + 1 - 2h + h(h-1)/n) / n) (Harvey, Leybourne and Newbold 1997)
%   and the two-sided p-value is from Student t with n-1 degrees of
%   freedom, p = betainc(nu/(nu + DM^2), nu/2, 1/2); without it,
%   p = 2*(1 - Phi(|DM|)) = erfc(|DM|/sqrt(2)). The tables are computed by
%   hetlearn.evaluate_tables, which also rebuilds them from a saved
%   errors_long.csv without re-running the forecasts.
%
%   Output E (struct; files in <results_dir>/eval_<name>/)
%     .errors         errors_long.csv: variant, origin, target, h, variable,
%                     actual, forecast, error (report units)
%     .metrics        metrics.csv: sample, variant, variable, h, n, rmse, me, mae
%     .relative_rmse  relative_rmse.csv: sample, variant, benchmark,
%                     variable, h, n, rmse, rmse_benchmark, relative_rmse
%     .dm             dm.csv: sample, variant, benchmark, variable, h, n,
%                     mean_loss_diff, dm_stat, p_value (variants other than
%                     the benchmark)
%     .settings       settings.mat: name, ids, variants, origins, horizon,
%                     benchmark, realtime, subsamples, failures (table),
%                     runtimes, n_runs
%     .forecasts      struct by variant id: nOrigins x H x nObs (model units);
%                     .actuals nOrigins x H x nObs; .observables
%     .folder         output folder ('' if not saved)
%
%   See also hetlearn.run, hetlearn.re_filter.

tAll = tic;
if nargin < 4 || isempty(opts)
    opts = struct();
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
def = struct('horizon', 8, 'benchmark', '', 'dm', true, 'dm_hln', true, 'dm_kernel', '', 'subsamples', struct(), ...
    'realtime', true, 'results_dir', fullfile(root, 'results'), 'save', true, 'quiet', false);
f = fieldnames(opts);
for i = 1:numel(f)
    if ~isfield(def, f{i})
        error('hetlearn:evaluate:option', 'Unknown evaluate option "%s".', f{i});
    end
    def.(f{i}) = opts.(f{i});
end
opts = def;
quiet = logical(opts.quiet);
H = opts.horizon;
if ~(isnumeric(H) && isscalar(H) && H >= 1 && H == round(H))
    error('hetlearn:evaluate:option', 'opts.horizon must be a positive integer.');
end
origins = hetlearn.util.to_dates(origins);
if isempty(origins)
    error('hetlearn:evaluate:origins', 'No forecast origins.');
end
if ischar(variants) || isstring(variants)
    variants = cellstr(variants);
elseif isstruct(variants)
    variants = num2cell(variants);
end
nV = numel(variants);
nO = numel(origins);

% ---- variants: options and models (loaded once each) ------------------------------------
tLoad = tic;
ids = cell(1, nV);
cfgs = cell(1, nV);
M = cell(1, nV);
plmKey = cell(1, nV);
optsV = cell(1, nV);
invV = false(1, nV);
for v = 1:nV
    c = variants{v};
    if ischar(c) || isstring(c)
        c = feval(char(c));
    end
    c.forecast.origin = origins(1);
    c.forecast.horizon = H;
    c.shocks = struct('source', 'none', 'range', [], 'exclude', {{}}, 'add', {{}});
    c.conditions = struct('variable', {}, 'shock', {}, 'dates', {}, 'values', {}, ...
        'type', {}, 'reference', {});
    c.density.enabled = false;
    c.compare_with = {};
    c.history.realtime = logical(opts.realtime);
    ov = hetlearn.load_options(c);
    invV(v) = strcmp(ov.history.mode, 'inversion'); %#ok<AGROW>
    ids{v} = ov.id;
    spec = hetlearn.load_spec(ov.model);
    [m, info] = hetlearn.load_model(spec, ov);
    M{v} = struct('spec', spec, 'm', m, 'info', info);
    cfgs{v} = c;
    optsV{v} = ov;
    plmKey{v} = [hetlearn.util.struct_key(ov.beliefs.plm) '|params=' ov.model_params];   % no shared filter across parameter sets
    if strcmp(ov.expectations.re_info, 'lagged')
        % DESIGN 19: the RE filter model of a lagged variant is the RE(t-1) model of its own
        % learning set and RE variant, so it shares a filter only with variants that match
        plmKey{v} = sprintf('%s|re_info=lagged|%s|%s', plmKey{v}, strjoin(info.learnVars, ','), ...
            ov.expectations.re_variant);
    end
    if isfield(info, 'nt') && ~isempty(info.nt)
        % N agent types and forecast transforms (phase P6): the RE filter model is the variant's own
        % generated file at its RE limit (type forecasts, transform states and factors, rule constants,
        % wedge stds), so it is shared only with variants of the same file, parameter values, toggles
        % and learning set
        plmKey{v} = sprintf('%s|nt|%s|%s|%s|%s|%s', plmKey{v}, info.meta.ext_file, ...
            hetlearn.util.struct_key(get(m, 'parameters')), hetlearn.util.struct_key(get(m, 'std')), ...
            hetlearn.util.struct_key(info.assign), strjoin(info.learnVars, ','));
    end
    if v > 1 && ~strcmp(M{v}.spec.folder, M{1}.spec.folder)
        error('hetlearn:evaluate:model', 'All variants must use the same model package (%s vs %s).', ...
            M{1}.spec.folder, M{v}.spec.folder);
    end
end
if numel(unique(ids)) < nV
    error('hetlearn:evaluate:ids', 'Variant ids must be unique: %s.', strjoin(ids, ', '));
end
bench = opts.benchmark;
if isempty(bench)
    bench = ids{1};
end
b = find(strcmp(ids, bench), 1);
if isempty(b)
    error('hetlearn:evaluate:benchmark', 'Benchmark %s is not one of the variants.', bench);
end
spec = M{1}.spec;
obs = reshape(spec.observables, 1, []);
nK = numel(obs);
scale = ones(1, nK);
for k = 1:nK
    if isfield(spec, 'report') && isfield(spec.report, 'scale') && isfield(spec.report.scale, obs{k})
        scale(k) = double(spec.report.scale.(obs{k}));
    end
end
if ~quiet
    fprintf('[evaluate] %s: %d variants x %d origins (%s-%s), H = %d, %s; models loaded in %.1f s\n', ...
        name, nV, nO, char(dat2str(origins(1))), char(dat2str(origins(end))), H, ...
        ternary(opts.realtime, 'real-time RE filters', 'full-sample RE filter'), toc(tLoad));
end

% ---- RE filters: one per origin (real time) and PLM spec, shared by variants ----------------
tFilt = tic;
[uk, ~, kOf] = unique(plmKey);
Hc = cell(nO, numel(uk));
Hfull = cell(1, numel(uk));
for u = 1:numel(uk)
    v = find(kOf == u, 1);
    oa = optsV{v};
    if ~strcmp(oa.expectations.re_info, 'lagged')
        oa.expectations.variables = 'all';      % lagged: the variant's learning set (hetlearn.re_filter)
    end
    [mA, infoA] = hetlearn.load_model(spec, oa);
    MA = struct('m', mA, 'info', infoA);
    if any(invV(kOf == u))
        Hfull{u} = hetlearn.re_filter(spec, optsV{v}, 'model', MA);   % inversion: state before the start
    end
    if all(invV(kOf == u))
        continue
    end
    if logical(opts.realtime)
        nNew = 0;
        for i = 1:nO
            Hc{i, u} = hetlearn.re_filter(spec, optsV{v}, 'end', origins(i), 'model', MA);
            nNew = nNew + ~Hc{i, u}.cached;
        end
        if ~quiet
            fprintf('  real-time RE filters: %d origins (%d new, %d cached), %.1f s\n', ...
                nO, nNew, nO - nNew, toc(tFilt));
        end
    else
        Hf = hetlearn.re_filter(spec, optsV{v}, 'model', MA);
        Hc(:, u) = {Hf};
    end
end
tFilt = toc(tFilt);

% ---- runs ------------------------------------------------------------------------------------
tRun = tic;
FC = NaN(nO, H, nK, nV);
nEv = NaN(nO, nV);
fail = cell(0, 3);
tick = max(1, round(nO / 4));
for v = 1:nV
    if invV(v)
        % one inversion to the last origin, the forecast at each origin from its state there
        Hv = Hfull{kOf(v)};
        cF = cfgs{v};
        cF.forecast.origin = origins(end);
        ctxF = struct('opts', hetlearn.load_options(cF), 'spec', M{v}.spec, 'info', M{v}.info, ...
            'results_dir', opts.results_dir, 'quiet', true, 'inv_snapshots', origins);
        hc = [];
        try
            [~, FF] = hetlearn.engine.core(ctxF, M{v}.m, Hv);
            hc = FF.history_cache;
        catch err
            for i = 1:nO
                fail(end+1, :) = {ids{v}, char(dat2str(origins(i))), ['inversion: ' err.message]}; %#ok<AGROW>
            end
        end
        for i = 1:nO * ~isempty(hc)
            c = cfgs{v};
            c.forecast.origin = origins(i);
            tg = origins(i) + (1:H);
            try
                ctxI = ctxF;
                ctxI.opts = hetlearn.load_options(c);
                ctxI.history_cache = hc;
                res = hetlearn.engine.core(ctxI, M{v}.m, Hv);
                for k = 1:nK
                    FC(i, :, k, v) = reshape(res.paths.(obs{k})(tg), 1, []);
                end
                nEv(i, v) = height(res.events);
            catch err
                fail(end+1, :) = {ids{v}, char(dat2str(origins(i))), err.message}; %#ok<AGROW>
            end
            res = []; %#ok<NASGU>
            if ~quiet && (mod(i, tick) == 0 || i == nO)
                fprintf('  %s (inversion): %d/%d origins, %.1f s elapsed\n', ids{v}, i, nO, toc(tRun));
            end
        end
        continue
    end
    for i = 1:nO
        c = cfgs{v};
        c.forecast.origin = origins(i);
        tg = origins(i) + (1:H);
        try
            res = hetlearn.run(c, 'save', false, 'quiet', true, 'model', M{v}, 'filter', Hc{i, kOf(v)});
            for k = 1:nK
                FC(i, :, k, v) = reshape(res.paths.(obs{k})(tg), 1, []);
            end
            nEv(i, v) = height(res.events);
        catch err
            fail(end+1, :) = {ids{v}, char(dat2str(origins(i))), err.message}; %#ok<AGROW>
        end
        res = []; %#ok<NASGU>
        if ~quiet && (mod(i, tick) == 0 || i == nO)
            fprintf('  %s: %d/%d origins, %.1f s elapsed\n', ids{v}, i, nO, toc(tRun));
        end
    end
end
tRun = toc(tRun);

% ---- actuals and errors (report units) -------------------------------------------------------
db = hetlearn.load_database(spec);
A = NaN(nO, H, nK);
for k = 1:nK
    if ~isfield(db, obs{k})
        continue
    end
    x = db.(obs{k});
    for i = 1:nO
        A(i, :, k) = reshape(x(origins(i) + (1:H)), 1, []);
    end
end
ERR = (A - FC) .* reshape(scale, 1, 1, nK);          % nO x H x nK x nV

% errors_long
rows = {};
for v = 1:nV
    for i = 1:nO
        for h = 1:H
            for k = 1:nK
                e = ERR(i, h, k, v);
                if isfinite(e)
                    rows(end+1, :) = {ids{v}, origins(i), origins(i) + h, h, obs{k}, ...
                        scale(k) * A(i, h, k), scale(k) * FC(i, h, k, v), e}; %#ok<AGROW>
                end
            end
        end
    end
end
if isempty(rows)
    rows = cell(0, 8);
end
Terr = table(rows(:, 1), dstr(rows(:, 2)), dstr(rows(:, 3)), cell2mat0(rows(:, 4)), rows(:, 5), ...
    cell2mat0(rows(:, 6)), cell2mat0(rows(:, 7)), cell2mat0(rows(:, 8)), 'VariableNames', ...
    {'variant', 'origin', 'target', 'h', 'variable', 'actual', 'forecast', 'error'});

% metrics, relative RMSE and DM (one implementation: hetlearn.evaluate_tables); saved with errors_long
out = '';
if logical(opts.save)
    out = fullfile(opts.results_dir, ['eval_' name]);
end
TT = hetlearn.evaluate_tables(Terr, struct('variants', {ids}, 'variables', {obs}, 'horizon', H, ...
    'origins', origins, 'benchmark', bench, 'subsamples', opts.subsamples, 'dm', logical(opts.dm), ...
    'dm_hln', logical(opts.dm_hln), 'dm_kernel', opts.dm_kernel, 'settings', struct('none', true), ...
    'save', logical(opts.save), 'folder', out, 'write_errors', true));
Tm = TT.metrics;
Tr = TT.relative_rmse;
Td = TT.dm;

% ---- outputs ----------------------------------------------------------------------------------
settings = struct();
settings.name = name;
settings.ids = ids;
settings.variants = cellfun(@vname, variants, 'UniformOutput', false);
settings.origins = origins;
settings.origin_str = hetlearn.util.date_str(origins);
settings.horizon = H;
settings.benchmark = bench;
settings.realtime = logical(opts.realtime);
settings.subsamples = opts.subsamples;
settings.dm = logical(opts.dm);
settings.dm_hln = logical(opts.dm_hln);
settings.dm_kernel = TT.info.dm_kernel;
settings.dm_fallbacks = TT.info.dm_fallbacks;
settings.history_mode = cellfun(@(o) o.history.mode, optsV, 'UniformOutput', false);
settings.failures = cell2table(fail, 'VariableNames', {'variant', 'origin', 'message'});
settings.events = nEv;
settings.n_runs = nO * nV;
settings.runtime_filters_s = tFilt;
settings.runtime_runs_s = tRun;
settings.model = spec.name;
settings.observables = obs;
settings.scale = scale;
settings.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
E = struct();
E.errors = Terr;
E.metrics = Tm;
E.relative_rmse = Tr;
E.dm = Td;
E.forecasts = struct();
for v = 1:nV
    E.forecasts.(matlab.lang.makeValidName(ids{v})) = FC(:, :, :, v);
end
E.actuals = A;
E.observables = obs;
E.folder = '';
settings.runtime_s = toc(tAll);
E.settings = settings;
if logical(opts.save)
    save(fullfile(out, 'settings.mat'), 'settings');
    E.folder = out;
end
E.settings.runtime_s = toc(tAll);
if ~quiet
    print_table(E, ids, b, obs, H, size(fail, 1));
end
end


% =================================================================================================
function c = dstr(x)
if isempty(x)
    c = cell(0, 1);
else
    c = reshape(hetlearn.util.date_str([x{:}]), [], 1);
end
end


function v = cell2mat0(c)
if isempty(c)
    v = zeros(0, 1);
else
    v = cell2mat(c);
end
end


function s = vname(c)
if ischar(c) || isstring(c)
    s = char(c);
else
    s = sprintf('<cfg %s>', char(c.id));
end
end


function t = ternary(c, a, b)
if c
    t = a;
else
    t = b;
end
end


function print_table(E, ids, b, obs, H, nFail)
T = E.metrics(strcmp(E.metrics.sample, 'full'), :);
R = E.relative_rmse(strcmp(E.relative_rmse.sample, 'full'), :);
hs = 1:H;
fprintf('\nRMSE, report units, full sample (rel = RMSE / RMSE of %s; p = DM p-value)\n', ids{b});
fprintf('%-9s %-24s', 'variable', 'variant');
hl = arrayfun(@(h) sprintf('h=%d', h), hs, 'UniformOutput', false);
fprintf(' %7s', hl{:});
fprintf('\n');
for k = 1:numel(obs)
    for v = 1:numel(ids)
        sel = strcmp(T.variable, obs{k}) & strcmp(T.variant, ids{v});
        r = T.rmse(sel);
        lab = '';
        if v == 1
            lab = obs{k};
        end
        fprintf('%-9s %-24s', lab, shorten(ids{v}, 24));
        fprintf(' %7.3f', r(hs));
        fprintf('\n');
        if v ~= b
            sr = strcmp(R.variable, obs{k}) & strcmp(R.variant, ids{v});
            q = R.relative_rmse(sr);
            fprintf('%-9s %-24s', '', '  rel');
            fprintf(' %7.3f', q(hs));
            fprintf('\n');
            if ~isempty(E.dm)
                D = E.dm(strcmp(E.dm.sample, 'full') & strcmp(E.dm.variable, obs{k}) ...
                    & strcmp(E.dm.variant, ids{v}), :);
                fprintf('%-9s %-24s', '', '  p(DM)');
                fprintf(' %7.3f', D.p_value(hs));
                fprintf('\n');
            end
        end
    end
end
fprintf('%d runs, %d failed; filters %.1f s, runs %.1f s, total %.1f s\n', ...
    E.settings.n_runs, nFail, E.settings.runtime_filters_s, E.settings.runtime_runs_s, ...
    E.settings.runtime_s);
end


function s = shorten(s, n)
if numel(s) > n
    s = [s(1:n-2) '..'];
end
end
