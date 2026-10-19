function H = re_filter(spec, opts, varargin)
%RE_FILTER  RE benchmark Kalman filter/smoother, cached (DESIGN 5.1, 17).
%
%   H = hetlearn.re_filter(spec, opts)
%   H = hetlearn.re_filter(spec, opts, 'force', true)
%   H = hetlearn.re_filter(spec, opts, 'end', date)          % real time
%   H = hetlearn.re_filter(spec, opts, 'end', date, 'model', MA)
%
%   Inputs
%     spec  model spec (hetlearn.load_spec); needs spec.database and
%           spec.filter_range
%     opts  merged options (hetlearn.load_options); only beliefs.plm is used
%           (it selects the generated model file). The filter model always
%           has EVERY br_<x> = true and n1_<x> = 1, belief parameters 0, so
%           every <x>_exp1_RE is in the smoothed history.
%   Options
%     'force'  re-run the filter even if a cache file exists (default false)
%     'end'    last date of data used (default [] = spec.filter_range end).
%              Every database series is clipped at this date and the filter
%              runs over [filter start, end]: the smoothed history then uses
%              data up to that date only (real-time information, used with
%              history.realtime and by hetlearn.evaluate). Must lie in the
%              filter range.
%     'model'  struct('m', m, 'info', info) of the filter model from
%              hetlearn.load_model(spec, opts with expectations.variables =
%              'all'), to skip loading it again (hetlearn.evaluate)
%
%   Output H (struct)
%     .smooth     smoothed databank (two-sided: data over the whole range)
%                 of filter(m, d, range, 'output', 'filter,smooth',
%                 'meanOnly', true): transition and measurement variables
%                 and shocks
%     .filtered   filtered databank of the same call (one-sided: x_{t|t},
%                 data up to t), same names; series start one period before
%                 the range (no presample lags). Read by the history stage
%                 under history.re_states = 'filtered'
%                 (hetlearn.engine.history_db)
%     .range      filter range (date vector)
%     .data       the input databank (hetlearn.load_database; clipped at
%                 'end' when given)
%     .fit_error  max abs error of the observables rebuilt from the smoothed
%                 states and shocks through the measurement equations
%                 (lhsmrhs of the measurement equations with the data on
%                 the left), NaN entries (presample lags) skipped
%     .model      the filter model (solved)
%     .hash       cache key; .file  cache file; .cached  true if read from it
%     .realtime   true when 'end' was given; .end_date  last date used
%
%   Check: with #shocks >= #observables, fit_error must be < 1e-8, else
%   error hetlearn:re_filter:fit. (Comparing the smoothed observables with
%   the data is vacuous: IRIS copies the data into them.)
%
%   Cache: <spec.folder>/generated/refilter_<hash>.mat, hash = MD5 over the
%   extended model text, the parameters, spec.assign, the database file
%   bytes and the filter range. With 'end': refilter_rt_<end>_<hash>.mat,
%   hash over the same items but the clipped data values instead of the file
%   bytes, so a data change after the end date does not touch it. A cache
%   without .filtered (written before 2026-10-19) is not used: the filter is
%   run again and the file rewritten under the same name (.cached = false).

ip = inputParser;
ip.addParameter('force', false);
ip.addParameter('end', []);
ip.addParameter('model', []);
ip.parse(varargin{:});
TOL = 1e-8;

if nargin < 2 || isempty(opts)
    opts = hetlearn.load_options(struct());
end
if isempty(spec.filter_range)
    error('hetlearn:re_filter:range', 'Model %s has no spec.filter_range.', spec.name);
end
if isempty(ip.Results.model)
    optsAll = opts;
    optsAll.expectations.variables = 'all';
    optsAll.policy.mode = 'rule';          % the history is always the estimated rule model (DESIGN 13)
    [m, info] = hetlearn.load_model(spec, optsAll);
else
    m = ip.Results.model.m;
    info = ip.Results.model.info;
    if isfield(info, 'policy') && ~isempty(info.policy) && info.policy.ramsey
        m = info.policy.rule_model;        % a Ramsey model was passed: filter with its rule model
        info.assign = info.policy.rule_assign;
    end
end
[d, dbFile] = hetlearn.load_database(spec);
range = hetlearn.util.to_dates(spec.filter_range);
realtime = ~isempty(ip.Results.end);

if ~realtime
    key = [hetlearn.util.md5(hetlearn.util.file_bytes(info.meta.ext_file)), '|', ...
        hetlearn.util.struct_key(info.params), '|', hetlearn.util.struct_key(info.assign), '|', ...
        hetlearn.util.md5(hetlearn.util.file_bytes(dbFile)), '|', ...
        sprintf('%.6f,', double(range([1 end])))];
    hash = hetlearn.util.md5(key);
    cacheFile = fullfile(spec.folder, 'generated', sprintf('refilter_%s.mat', hash(1:12)));
else
    endDate = ip.Results.end(1);
    if double(endDate) > double(range(end)) + 1e-6 || double(endDate) < double(range(1)) - 1e-6
        error('hetlearn:re_filter:end', 'End date %s is outside the filter range %s-%s.', ...
            char(dat2str(endDate)), char(dat2str(range(1))), char(dat2str(range(end))));
    end
    range = range(1):endDate;
    [d, dataKey] = clip_data(d, endDate);
    key = [hetlearn.util.md5(hetlearn.util.file_bytes(info.meta.ext_file)), '|', ...
        hetlearn.util.struct_key(info.params), '|', hetlearn.util.struct_key(info.assign), '|', ...
        hetlearn.util.md5(dataKey), '|', sprintf('%.6f,', double(range([1 end]))), '|realtime'];
    hash = hetlearn.util.md5(key);
    tag = regexprep(char(dat2str(endDate)), '[^A-Za-z0-9]', '');
    cacheFile = fullfile(spec.folder, 'generated', sprintf('refilter_rt_%s_%s.mat', tag, hash(1:12)));
end

if ~ip.Results.force && exist(cacheFile, 'file') == 2
    L = load(cacheFile, 'H');
    if isfield(L.H, 'filtered')
        H = L.H;
        H.model = m;
        H.file = cacheFile;
        H.cached = true;
        H.realtime = realtime;
        H.end_date = H.range(end);
        return
    end
    % a cache written before 2026-10-19 has no filtered databank: filter
    % again (same inputs, same key; the smoothed history is unchanged) and
    % rewrite the file below
end

% One filter call, both outputs. IRIS 20230622 (model/filter -> hdataobj.hdatafinal):
% with two outputs requested the databank is a struct with fields .filter and
% .smooth (with one it is the databank itself); the smoothed output is the same
% as with 'output', 'smooth' alone (checked: max diff 0 on SW07). The filter
% databank has no presample lag rows; observed measurement variables equal the
% data in both; where data are missing the filtered value is the prediction.
[~, f] = filter(m, d, range, 'output', 'filter,smooth', 'meanOnly', true);
ff = f.filter;
f = f.smooth;

% rebuild observables through the measurement equations: data on the left,
% smoothed transition variables and shocks on the right
yList = info.yList;
db = f;
for i = 1:numel(yList)
    if isfield(d, yList{i})
        db.(yList{i}) = d.(yList{i});
    end
end
Q = lhsmrhs(m, db, range);
Q = Q(1:numel(yList), :);           % measurement equations come first
Q = Q(isfinite(Q));
fitErr = max([0; abs(Q(:))]);
if numel(info.eList) >= numel(yList) && ~(fitErr < TOL)
    error('hetlearn:re_filter:fit', ...
        'RE smoother does not reproduce the data: max abs error %.3g >= %g.', fitErr, TOL);
end

H = struct();
H.smooth = f;
H.filtered = ff;
H.range = range;
H.data = d;
H.fit_error = fitErr;
H.hash = hash;
H.file = cacheFile;
H.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
H.cached = false;
H.model = [];
save(cacheFile, 'H');
H.model = m;
if realtime
    H.realtime = true;
    H.end_date = range(end);
else
    H.realtime = false;
    H.end_date = range(end);
end
end


function [d, key] = clip_data(d, endDate)
% Clip every Series at endDate; key = text of the clipped values (sorted
% by name) for the cache hash.
f = sort(fieldnames(d));
parts = cell(1, numel(f));
for i = 1:numel(f)
    x = d.(f{i});
    if ~isa(x, 'Series')
        continue
    end
    if double(x.Start) > double(endDate)
        x = clip(x, x.Start, x.Start);
        x(x.Start) = NaN;
    else
        x = clip(x, x.Start, endDate);
    end
    d.(f{i}) = x;
    parts{i} = sprintf('%s@%.6f:%s', f{i}, double(x.Start), sprintf('%.17g,', x.Data(:)));
end
key = strjoin(parts(~cellfun(@isempty, parts)), ';');
end
