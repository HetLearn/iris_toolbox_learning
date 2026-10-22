function c = est_config()
%EST_CONFIG  Settings of the estimation module (edit this file, nothing else).
%
%   c = est_config()
%
%   toolbox_root  folder holding setup_paths.m, toolbox/, config/, scenarios/ and
%                 models/sw07 that every estimation run uses. Default since
%                 2026-10-20: c.project, the live toolbox. The chains and mode searches
%                 of 2026-10-19/20 ran against a frozen snapshot of commit 95ecebd (in a
%                 session folder that no longer exists); G3, G4, G5 and the log
%                 likelihoods and log posteriors at the modes pass against the live
%                 toolbox (est_00_gates_live, results/estimation/gates.txt). After any
%                 change to toolbox/ or models/sw07, re-run est_00_gates_live before
%                 resuming a chain (G4 ties the estimator to the engine).
%   results       output folder (results/estimation of the project, gitignored)
%   threads       maxNumCompThreads inside every RE batch process (threads_learn: learning)
%   like_start    first quarter of the likelihood sum ([year quarter]); the filter
%                 starts at the model's filter_range start (1965Q1), so 1965Q1-Q4
%                 is the presample of both models

c = struct();
c.est_dir = fileparts(mfilename('fullpath'));
c.project = fileparts(c.est_dir);
c.toolbox_root = c.project;      % live toolbox (the frozen snapshot was retired on 2026-10-20)
c.results = fullfile(c.project, 'results', 'estimation');
c.matlab_exe = 'C:\Program Files\MATLAB\R2025a\bin\matlab.exe';
c.threads = 2;
% Learning-model processes run single-threaded: with many processes on the machine, MKL's
% threads in the many small QZ calls (one per quarter) contend; measured 2026-10-20 under
% full load: 1.6-1.8 s per evaluation with 2 threads, 0.46-0.52 s with 1 thread.
c.threads_learn = 1;
c.model = 'sw07';
c.like_start = [1966 1];

% Dynare material for gates G0 and G2 (read only; Dynare is not run).
% dynare_matlab: Dynare 4.6.1's matlab/ folder, from the environment variable
% HETLEARN_DYNARE_DIR, else dynare-4.6.1/matlab next to the project folder; '' if neither
% exists (only est_00_g0_dynare needs it and stops with est_00_g0_dynare:noDynare then).
c.dynare_matlab = dynare_folder(c.project);
c.swx1_out = 'C:\dynare_work\sw_ext\swX1_out.mat';

% MCMC
c.block = 1000;              % draws per checkpoint block file
c.thin_paths = 50;           % learning chains: paths stored for every 50th draw
c.re_chains = 4;
c.re_draws = 100000;
end


function d = dynare_folder(project)
% Dynare matlab/ folder: HETLEARN_DYNARE_DIR, else the sibling dynare-4.6.1/matlab, else ''.
d = getenv('HETLEARN_DYNARE_DIR');
if ~isempty(d)
    if exist(d, 'dir') ~= 7
        error('est_config:noDynare', ...
            'HETLEARN_DYNARE_DIR is set to %s, which is not a folder. Point it to Dynare 4.6.1''s matlab folder.', d);
    end
    return
end
d = fullfile(fileparts(project), 'dynare-4.6.1', 'matlab');
if exist(d, 'dir') ~= 7
    d = '';
end
end
