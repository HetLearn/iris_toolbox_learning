function res = load_result(id, resultsDir, runIfMissing)
%LOAD_RESULT  Read results/<id>/results.mat, optionally running the scenario first.
%
%   res = hetlearn.engine.load_result(id, resultsDir, runIfMissing)
%
%   Inputs
%     id            scenario id; the scenario function of the same name is
%                   run (cfg = feval(id); hetlearn.run(cfg)) when the file
%                   is missing and runIfMissing is true
%     resultsDir    folder holding <id>/results.mat
%     runIfMissing  logical (default false)
%
%   Output
%     res           the saved result struct

if nargin < 3
    runIfMissing = false;
end
file = fullfile(resultsDir, id, 'results.mat');
if exist(file, 'file') ~= 2
    if ~runIfMissing
        error('hetlearn:engine:noResult', 'No results for scenario %s: %s', id, file);
    end
    if isempty(which(id))
        error('hetlearn:engine:noResult', ...
            'No results for scenario %s and no scenario function %s on the path.', id, id);
    end
    fprintf('  scenario %s has no results yet: running it first\n', id);
    hetlearn.run(feval(id), 'results_dir', resultsDir);
end
L = load(file, 'res');
res = L.res;
end
