function spec = load_spec(name)
%LOAD_SPEC  Read a model package contract models/<name>/model_spec.m (DESIGN 2).
%
%   spec = hetlearn.load_spec(name)
%
%   Inputs
%     name  model folder name under <project root>/models (e.g. 'sw07'), or
%           the path of any folder that contains a model_spec.m (absolute,
%           or relative to the current folder; used for tests/toy_nk).
%
%   Output
%     spec  the struct returned by that folder's model_spec(), with
%           spec.folder set to the absolute folder path.
%
%   The project root is found from the toolbox location
%   (<root>/toolbox/+hetlearn). model_spec() is evaluated with its folder
%   as the current folder, so the right model_spec.m is used even when
%   several are on the path.

if isstring(name)
    name = char(name);
end
if ~ischar(name) || isempty(name)
    error('hetlearn:load_spec:type', 'Model name must be a non-empty character string.');
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
cands = {fullfile(root, 'models', name), name};
folder = '';
for i = 1:numel(cands)
    if exist(fullfile(cands{i}, 'model_spec.m'), 'file') == 2
        folder = cands{i};
        break
    end
end
if isempty(folder)
    error('hetlearn:load_spec:notFound', ...
        'No model_spec.m in %s or %s.', fullfile(root, 'models', name), name);
end
old = cd(folder);
folder = pwd;                              % absolute path
back = onCleanup(@() cd(old));
clear('model_spec');                       % drop a cached model_spec of another folder
spec = feval('model_spec');
clear back
clear('model_spec');
if ~isstruct(spec) || ~isscalar(spec)
    error('hetlearn:load_spec:type', 'model_spec() in %s must return a scalar struct.', folder);
end
spec.folder = folder;
need = {'name', 'model_file', 'params', 'linear'};
miss = need(~isfield(spec, need));
if ~isempty(miss)
    error('hetlearn:load_spec:field', 'model_spec in %s lacks field(s): %s.', folder, strjoin(miss, ', '));
end
defaults = struct('sstate', '', 'assign', struct(), 'database', '', ...
    'filter_range', [], 'observables', {{}}, 'report', struct());
f = fieldnames(defaults);
for i = 1:numel(f)
    if ~isfield(spec, f{i})
        spec.(f{i}) = defaults.(f{i});
    end
end
end
