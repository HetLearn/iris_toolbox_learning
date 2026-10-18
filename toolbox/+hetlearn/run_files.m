function T = run_files(names, varargin)
%RUN_FILES  Run scenario files by name, in order, and summarise.
%
%   T = hetlearn.run_files(names)
%   T = hetlearn.run_files(names, <hetlearn.run options>)
%
%   Inputs
%     names     cellstr (or char) of scenario function names on the path;
%               each is run as cfg = feval(name); res = hetlearn.run(cfg).
%               Nothing is skipped: every scenario is re-run even if results
%               exist. An error in one scenario is reported and the next one
%               runs.
%     varargin  passed to hetlearn.run (e.g. 'results_dir', folder)
%
%   Output
%     T  table: name, id, runtime_s, events, status ('ok' or 'error: ...');
%        also printed

names = cellstr(names);
n = numel(names);
id = repmat({''}, n, 1);
rt = NaN(n, 1);
nev = NaN(n, 1);
status = cell(n, 1);
for i = 1:n
    t0 = tic;
    try
        cfg = feval(names{i});
        id{i} = char(cfg.id);
        res = hetlearn.run(cfg, varargin{:});
        nev(i) = height(res.events);
        status{i} = 'ok';
    catch err
        status{i} = ['error: ' err.message];
        fprintf(2, '[hetlearn] %s failed: %s\n', names{i}, err.message);
    end
    rt(i) = toc(t0);
end
T = table(names(:), id, rt, nev, status, ...
    'VariableNames', {'name', 'id', 'runtime_s', 'events', 'status'});
disp(T);
end
