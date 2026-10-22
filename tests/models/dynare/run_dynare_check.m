function run_dynare_check()
%RUN_DYNARE_CHECK  Run the Dynare 4.6.1 cross-check of the lagged RE information model (test_re_info T2).
%
%   run_dynare_check()      in a MATLAB session WITHOUT IRIS on the path
%
%   Writes the swX1 parameter values (models/sw07/sw07_params.m) and shock
%   standard deviations as include files next to a copy of
%   sw07_re_lagged_pinf.mod in C:\dynare_work\re_info_check\ (Dynare fails on
%   OneDrive paths), runs Dynare there (stoch_simul, order 1, 40-quarter IRFs
%   to one-std shocks, the convention of IRIS srf) and saves
%   tests/reference/re_info_dynare_irfs.mat:
%     irfs       struct: irfs.<var>_<shock> (40 x 1), every endogenous
%                variable of the .mod (Dynare's auxiliary variables excluded)
%     endo       cellstr of those variables, shocks  cellstr of the shocks
%     steady     struct of steady-state values by variable
%     dynare_version, created
%   Run once (2026-10-19); test_re_info T2 compares the toolbox against the file.
%   Dynare's matlab/ folder: the environment variable HETLEARN_DYNARE_DIR, else
%   dynare-4.6.1/matlab next to the project folder, else an error.

here = fileparts(mfilename('fullpath'));
root = fileparts(fileparts(fileparts(here)));
work = 'C:\dynare_work\re_info_check';
dyn = dynare_folder(root);
if exist(work, 'dir') ~= 7
    mkdir(work);
end
addpath(fullfile(root, 'models', 'sw07'));
P = sw07_params();
rmpath(fullfile(root, 'models', 'sw07'));
% parameter values
f = fieldnames(P);
fid = fopen(fullfile(work, 'sw07_params.inc'), 'w');
for i = 1:numel(f)
    if strncmp(f{i}, 'std_', 4)
        continue
    end
    fprintf(fid, '%s = %.17g;\n', f{i}, P.(f{i}));
end
fclose(fid);
% shocks
shk = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};
fid = fopen(fullfile(work, 'sw07_shocks.inc'), 'w');
fprintf(fid, 'shocks;\n');
for j = 1:numel(shk)
    fprintf(fid, 'var %s;\nstderr %.17g;\n', shk{j}, P.(['std_' shk{j}]));
end
fprintf(fid, 'end;\n');
fclose(fid);
copyfile(fullfile(here, 'sw07_re_lagged_pinf.mod'), fullfile(work, 'sw07_re_lagged_pinf.mod'));
old = cd(work);
c = onCleanup(@() cd(old));
addpath(dyn);
evalin('base', 'dynare sw07_re_lagged_pinf noclearall nograph;');
oo = evalin('base', 'oo_');
M = evalin('base', 'M_');
endo = cellstr(M.endo_names);
endo = endo(1:M.orig_endo_nbr);           % Dynare's auxiliary variables come after the declared ones
irfs = struct();
for j = 1:numel(shk)
    for i = 1:numel(endo)
        nm = [endo{i} '_' shk{j}];
        if isfield(oo.irfs, nm)
            irfs.(nm) = oo.irfs.(nm)(:);
        else
            irfs.(nm) = zeros(40, 1);         % below Dynare's storage threshold
        end
    end
end
steady = struct();
for i = 1:numel(endo)
    steady.(endo{i}) = oo.steady_state(i);
end
shocks = shk; %#ok<NASGU>
dynare_version = evalin('base', 'dynare_version()'); %#ok<NASGU>
created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST,NASGU>
aux_nbr = M.endo_nbr - M.orig_endo_nbr; %#ok<NASGU>
out = fullfile(root, 'tests', 'reference', 're_info_dynare_irfs.mat');
save(out, 'irfs', 'endo', 'shocks', 'steady', 'dynare_version', 'created', 'aux_nbr');
fprintf('DYNARE_CHECK saved %s: %d variables x %d shocks, %d Dynare auxiliary variables\n', out, numel(endo), ...
    numel(shk), M.endo_nbr - M.orig_endo_nbr);
end


function d = dynare_folder(root)
% Dynare matlab/ folder: HETLEARN_DYNARE_DIR, else the sibling dynare-4.6.1/matlab.
d = getenv('HETLEARN_DYNARE_DIR');
if ~isempty(d)
    if exist(d, 'dir') ~= 7
        error('run_dynare_check:noDynare', ...
            'HETLEARN_DYNARE_DIR is set to %s, which is not a folder. Point it to Dynare 4.6.1''s matlab folder.', d);
    end
    return
end
d = fullfile(fileparts(root), 'dynare-4.6.1', 'matlab');
if exist(d, 'dir') ~= 7
    error('run_dynare_check:noDynare', ['Dynare 4.6.1 not found. Either set the environment variable ' ...
        'HETLEARN_DYNARE_DIR to its matlab folder, e.g. setenv(''HETLEARN_DYNARE_DIR'', ''D:\\dynare-4.6.1\\matlab''), ' ...
        'or put dynare-4.6.1 next to the project folder (looked in %s).'], d);
end
end
