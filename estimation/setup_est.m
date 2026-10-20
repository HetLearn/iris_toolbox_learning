function c = setup_est()
%SETUP_EST  Put IRIS, the hetlearn toolbox of est_config().toolbox_root and estimation/ on the path.
%
%   c = setup_est()
%
%   Runs <toolbox_root>/setup_paths (IRIS, toolbox, config, scenarios) unless hetlearn is
%   already on the path, adds this folder (package +hlest), creates the results folders
%   and checks that hetlearn comes from toolbox_root and not from another copy (the live
%   project's toolbox must never be on the path of an estimation run).
%   Returns the settings of est_config().

c = est_config();
w = which('hetlearn.load_model');
if isempty(w)
    old = cd(c.toolbox_root);
    back = onCleanup(@() cd(old));
    setup_paths();
    clear back
    w = which('hetlearn.load_model');
end
if isempty(w) || ~strncmpi(w, c.toolbox_root, numel(c.toolbox_root))
    error('setup_est:toolbox', 'hetlearn is taken from %s, not from the configured root %s.', w, c.toolbox_root);
end
addpath(c.est_dir);
subs = {'', 're', 'learn', 'tables', 'logs', 'gates'};
for i = 1:numel(subs)
    f = fullfile(c.results, subs{i});
    if exist(f, 'dir') ~= 7
        mkdir(f);
    end
end
end
