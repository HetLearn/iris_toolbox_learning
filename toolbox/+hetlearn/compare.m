function T = compare(ids, vars, range, varargin)
%COMPARE  Levels and differences of saved scenarios.
%
%   T = hetlearn.compare(ids)
%   T = hetlearn.compare(ids, vars, range)
%   T = hetlearn.compare(ids, vars, range, 'results_dir', folder)
%
%   Inputs
%     ids    cellstr of scenario ids with results in results/<id>/ (a
%            missing one is run first through its scenario function)
%     vars   cellstr of variable names (default: the observables of the
%            first scenario's model); any series in res.paths works
%     range  dates (default: the forecast horizon of the first scenario)
%
%   Output
%     T      table with a text date column, then for each variable the level
%            in every scenario (<var>__<id>) and the difference of each
%            further scenario from the first (<var>__<id>_minus_<id1>)

ip = inputParser;
ip.addParameter('results_dir', fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'results'));
ip.parse(varargin{:});
ids = cellstr(ids);
R = cell(1, numel(ids));
for i = 1:numel(ids)
    R{i} = hetlearn.engine.load_result(ids{i}, ip.Results.results_dir, true);
end
if nargin < 2 || isempty(vars)
    spec = hetlearn.load_spec(R{1}.meta.model_folder);
    vars = spec.observables;
end
vars = cellstr(vars);
if nargin < 3 || isempty(range)
    range = R{1}.dates.horizon;
end
range = hetlearn.util.to_dates(range);
T = table(hetlearn.util.date_str(range)', 'VariableNames', {'date'});
for j = 1:numel(vars)
    v = vars{j};
    X = NaN(numel(range), numel(ids));
    for i = 1:numel(ids)
        if isfield(R{i}.paths, v)
            X(:, i) = R{i}.paths.(v)(range);
        end
        T.(sprintf('%s__%s', v, ids{i})) = X(:, i);
    end
    for i = 2:numel(ids)
        T.(sprintf('%s__%s_minus_%s', v, ids{i}, ids{1})) = X(:, i) - X(:, 1);
    end
end
end
