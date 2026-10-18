function T = evaluate_tables(errors, opts)
%EVALUATE_TABLES  Metrics, relative RMSE and Diebold-Mariano tables from forecast errors (DESIGN 17).
%
%   T = hetlearn.evaluate_tables(errors)
%   T = hetlearn.evaluate_tables(errors, opts)
%
%   Recomputes the tables of hetlearn.evaluate from the long error table, so
%   that they can be rebuilt (e.g. with another DM kernel) without
%   re-running any forecast (review finding m2). hetlearn.evaluate itself
%   computes its tables with this function.
%
%   Inputs
%     errors  table with columns variant, origin, target, h, variable, error
%             (errors_long.csv of hetlearn.evaluate), the path of such a
%             file, or an eval_<name> folder holding errors_long.csv
%     opts    struct, every field optional. Defaults come from settings.mat
%             next to the file when there is one, else as listed:
%       .variants      variant ids, output order (settings.ids; else order
%                      of appearance)
%       .variables     observables, output order (settings.observables; else
%                      order of appearance)
%       .horizon       H (settings.horizon; else max h)
%       .origins       origin dates (settings.origins; else the distinct
%                      origins of the table)
%       .benchmark     benchmark id (settings.benchmark; else the first variant)
%       .subsamples    struct of [start, end] target-date ranges
%                      (settings.subsamples; else none)
%       .dm            DM tests (true)
%       .dm_hln        Harvey-Leybourne-Newbold correction, t(n-1) p-values (true)
%       .dm_kernel     long-run variance kernel: '' (default) = 'uniform'
%                      when dm_hln is true, else 'bartlett'
%       .settings      settings struct used instead of settings.mat ([] =
%                      read the file if there is one)
%       .save          write metrics.csv, relative_rmse.csv, dm.csv (false)
%       .folder        output folder (default: the folder of the errors file)
%       .write_errors  also write errors_long.csv (false; used by evaluate)
%
%   Errors: d_t = e_variant^2 - e_benchmark^2 over the origins both variants
%   have, in origin order; n = numel(d), u = d - mean(d), gamma_k =
%   u(k+1:n)'*u(1:n-k)/n, L = min(h-1, n-1).
%     'uniform'  (rectangular window truncated at h-1, the estimator for
%                which Harvey, Leybourne and Newbold (1997) derived their
%                factor): LRV = gamma_0 + 2*sum_{k=1..L} gamma_k. When this
%                LRV is not positive the cell falls back to 'bartlett'
%                (kernel column 'bartlett_fallback', counted in
%                T.info.dm_fallbacks).
%     'bartlett' (Newey-West): LRV = gamma_0 + 2*sum_k (1 - k/(L+1))*gamma_k.
%   DM = mean(d)/sqrt(LRV/n), NaN when n < 2 or LRV <= 0. With dm_hln the
%   statistic is multiplied by sqrt((n + 1 - 2h + h(h-1)/n)/n) and p is the
%   two-sided t(n-1) p-value, else p = erfc(|DM|/sqrt(2)).
%
%   Output T: .metrics (sample, variant, variable, h, n, rmse, me, mae),
%   .relative_rmse (sample, variant, benchmark, variable, h, n, rmse,
%   rmse_benchmark, relative_rmse), .dm (sample, variant, benchmark,
%   variable, h, n, mean_loss_diff, dm_stat, p_value, kernel), .info
%   (dm_kernel, dm_hln, n_dm, dm_fallbacks, benchmark, variants, variables,
%   horizon, origins), .folder ('' if not saved).
%
%   See also hetlearn.evaluate.

if nargin < 2 || isempty(opts)
    opts = struct();
end
def = struct('variants', {{}}, 'variables', {{}}, 'horizon', [], 'origins', [], 'benchmark', '', ...
    'subsamples', [], 'dm', true, 'dm_hln', true, 'dm_kernel', '', 'settings', [], 'save', false, ...
    'folder', '', 'write_errors', false);
f = fieldnames(opts);
for i = 1:numel(f)
    if ~isfield(def, f{i})
        error('hetlearn:evaluate:option', 'Unknown evaluate_tables option "%s".', f{i});
    end
    def.(f{i}) = opts.(f{i});
end
opts = def;

% ---- the error table and its settings ----------------------------------------------------
folder = '';
if ischar(errors) || isstring(errors)
    file = char(errors);
    if exist(file, 'dir') == 7
        file = fullfile(file, 'errors_long.csv');
    end
    if exist(file, 'file') ~= 2
        error('hetlearn:evaluate:file', 'No errors file %s.', file);
    end
    folder = fileparts(file);
    Terr = readtable(file, 'Delimiter', ',', 'TextType', 'char', 'DatetimeType', 'text');
    if isempty(opts.settings) && exist(fullfile(folder, 'settings.mat'), 'file') == 2
        L = load(fullfile(folder, 'settings.mat'), 'settings');
        opts.settings = L.settings;
    end
else
    Terr = errors;
end
st = opts.settings;
if isempty(st)
    st = struct();
end
for c = {'variant', 'origin', 'variable'}
    if ~iscell(Terr.(c{1}))
        Terr.(c{1}) = cellstr(string(Terr.(c{1})));
    end
end
ids = pick(opts.variants, st, 'ids', unique(Terr.variant, 'stable'));
ids = reshape(cellstr(ids), 1, []);
obs = pick(opts.variables, st, 'observables', unique(Terr.variable, 'stable'));
obs = reshape(cellstr(obs), 1, []);
H = pick(opts.horizon, st, 'horizon', max([0; Terr.h]));
bench = pick(opts.benchmark, st, 'benchmark', ids{1});
subs = pick(opts.subsamples, st, 'subsamples', struct());
[uo, ~, io] = unique(Terr.origin);
uNum = cellfun(@(s) double(str2dat(s)), uo);
rowO = reshape(uNum(io), [], 1);
origins = pick(opts.origins, st, 'origins', []);
if isempty(origins)
    oNum = unique(uNum);
else
    oNum = double(hetlearn.util.to_dates(origins));
end
oNum = reshape(oNum, [], 1);
kern = char(opts.dm_kernel);
if isempty(kern)
    if logical(opts.dm_hln)
        kern = 'uniform';
    else
        kern = 'bartlett';
    end
end
if ~any(strcmp(kern, {'uniform', 'bartlett'}))
    error('hetlearn:evaluate:option', 'opts.dm_kernel must be ''uniform'' or ''bartlett'', not ''%s''.', kern);
end
b = find(strcmp(ids, bench), 1);
if isempty(b)
    error('hetlearn:evaluate:benchmark', 'Benchmark %s is not one of the variants.', bench);
end

% ---- dense errors ERR(origin, h, variable, variant) -----------------------------------------
nO = numel(oNum);
nK = numel(obs);
nV = numel(ids);
ERR = NaN(nO, H, nK, nV);
[okV, iv] = ismember(Terr.variant, ids);
[okK, ik] = ismember(Terr.variable, obs);
io = zeros(height(Terr), 1);
for q = 1:numel(uNum)
    j = find(abs(oNum - uNum(q)) < 1e-6, 1);
    if ~isempty(j)
        io(rowO == uNum(q)) = j;
    end
end
use = okV & okK & io > 0 & Terr.h >= 1 & Terr.h <= H & isfinite(Terr.error);
ERR(sub2ind(size(ERR), io(use), Terr.h(use), ik(use), iv(use))) = Terr.error(use);
TG = oNum + (1:H);                                   % target dates (numeric)

% samples: full + subsamples (target-date ranges)
samples = {'full'};
masks = {true(nO, H)};
sf = fieldnames(subs);
for j = 1:numel(sf)
    r = hetlearn.util.to_dates(subs.(sf{j}));
    samples{end+1} = sf{j}; %#ok<AGROW>
    masks{end+1} = TG >= double(r(1)) - 1e-6 & TG <= double(r(end)) + 1e-6; %#ok<AGROW>
end

mt = {};
rr = {};
dm = {};
nFall = 0;
for s = 1:numel(samples)
    msk = masks{s};
    for v = 1:nV
        for k = 1:nK
            for h = 1:H
                e = ERR(:, h, k, v);
                ok = isfinite(e) & msk(:, h);
                ev = e(ok);
                n = numel(ev);
                mt(end+1, :) = {samples{s}, ids{v}, obs{k}, h, n, sqrt(mean(ev .^ 2)), ...
                    mean(ev), mean(abs(ev))}; %#ok<AGROW>
                eb = ERR(:, h, k, b);
                both = isfinite(e) & isfinite(eb) & msk(:, h);
                r1 = sqrt(mean(e(both) .^ 2));
                r0 = sqrt(mean(eb(both) .^ 2));
                rr(end+1, :) = {samples{s}, ids{v}, bench, obs{k}, h, sum(both), r1, r0, r1 / r0}; %#ok<AGROW>
                if logical(opts.dm) && v ~= b
                    [stt, pv, md, used] = dm_test(e(both) .^ 2 - eb(both) .^ 2, h, logical(opts.dm_hln), kern);
                    nFall = nFall + strcmp(used, 'bartlett_fallback');
                    dm(end+1, :) = {samples{s}, ids{v}, bench, obs{k}, h, sum(both), md, stt, pv, used}; %#ok<AGROW>
                end
            end
        end
    end
end
if isempty(mt)
    mt = cell(0, 8);
end
if isempty(rr)
    rr = cell(0, 9);
end
if isempty(dm)
    dm = cell(0, 10);
end
T = struct();
T.metrics = cell2table(mt, 'VariableNames', {'sample', 'variant', 'variable', 'h', 'n', 'rmse', 'me', 'mae'});
T.relative_rmse = cell2table(rr, 'VariableNames', {'sample', 'variant', 'benchmark', 'variable', 'h', 'n', ...
    'rmse', 'rmse_benchmark', 'relative_rmse'});
T.dm = cell2table(dm, 'VariableNames', {'sample', 'variant', 'benchmark', 'variable', 'h', 'n', ...
    'mean_loss_diff', 'dm_stat', 'p_value', 'kernel'});
T.info = struct('dm_kernel', kern, 'dm_hln', logical(opts.dm_hln), 'n_dm', size(dm, 1), ...
    'dm_fallbacks', nFall, 'benchmark', bench, 'variants', {ids}, 'variables', {obs}, 'horizon', H, ...
    'origins', oNum);
T.folder = '';
if logical(opts.save)
    out = opts.folder;
    if isempty(out)
        out = folder;
    end
    if isempty(out)
        error('hetlearn:evaluate:folder', 'opts.folder is required to save tables built from a table.');
    end
    if exist(out, 'dir') ~= 7
        mkdir(out);
    end
    if logical(opts.write_errors)
        write_table(fullfile(out, 'errors_long.csv'), Terr);
    end
    write_table(fullfile(out, 'metrics.csv'), T.metrics);
    write_table(fullfile(out, 'relative_rmse.csv'), T.relative_rmse);
    write_table(fullfile(out, 'dm.csv'), T.dm);
    T.folder = out;
end
end


% =================================================================================================
function v = pick(v, st, field, fallback)
% Explicit option > settings field > fallback.
if isempty(v)
    if isfield(st, field) && ~isempty(st.(field))
        v = st.(field);
    else
        v = fallback;
    end
end
end


function [st, pv, md, used] = dm_test(d, h, hln, kern)
% Diebold-Mariano statistic with h-1 lags, kernel 'uniform' (fallback to
% Bartlett if the variance is not positive) or 'bartlett'; hln: HLN factor
% and t(n-1) p-value.
d = d(:);
n = numel(d);
md = mean(d);
st = NaN;
pv = NaN;
used = kern;
if n < 2
    return
end
u = d - md;
L = min(h - 1, n - 1);
g0 = (u' * u) / n;
g = zeros(L, 1);
for k = 1:L
    g(k) = (u(k+1:end)' * u(1:end-k)) / n;
end
lrv = NaN;
if strcmp(kern, 'uniform')
    lrv = g0;
    for k = 1:L
        lrv = lrv + 2 * g(k);
    end
    if ~(lrv > 0)
        used = 'bartlett_fallback';
    end
end
if ~strcmp(used, 'uniform')
    lrv = g0;
    for k = 1:L
        lrv = lrv + 2 * (1 - k / (L + 1)) * g(k);
    end
end
if ~(lrv > 0)
    return
end
st = md / sqrt(lrv / n);
if hln
    st = st * sqrt(max(n + 1 - 2 * h + h * (h - 1) / n, 0) / n);
    pv = t_pvalue(st, n - 1);
else
    pv = erfc(abs(st) / sqrt(2));
end
end


function p = t_pvalue(x, nu)
% Two-sided p-value of Student t with nu degrees of freedom:
% P(|T| > |x|) = I_{nu/(nu + x^2)}(nu/2, 1/2) (regularised incomplete beta).
if ~(nu > 0) || ~isfinite(x)
    p = NaN;
    return
end
p = betainc(nu / (nu + x^2), nu / 2, 0.5);
end


function write_table(file, T)
% CSV with text columns as is (quoted if needed) and numbers as %.17g (NaN empty).
fid = fopen(file, 'w');
if fid < 0
    error('hetlearn:evaluate:write', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
vn = T.Properties.VariableNames;
fprintf(fid, '%s\n', strjoin(vn, ','));
nR = height(T);
cols = cell(nR, numel(vn));
for j = 1:numel(vn)
    x = T.(vn{j});
    if iscell(x)
        cols(:, j) = cellfun(@quote, x, 'UniformOutput', false);
    else
        cols(:, j) = arrayfun(@num, x, 'UniformOutput', false);
    end
end
for i = 1:nR
    fprintf(fid, '%s\n', strjoin(cols(i, :), ','));
end
end


function s = num(v)
if isnan(v)
    s = '';
else
    s = sprintf('%.17g', v);
end
end


function s = quote(s)
s = char(s);
if any(s == ',' | s == '"')
    s = ['"' strrep(s, '"', '""') '"'];
end
end
