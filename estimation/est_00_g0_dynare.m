function est_00_g0_dynare()
%EST_00_G0_DYNARE  Dynare side of gates G0 and G2 (run in a MATLAB session WITHOUT IRIS).
%
%   est_00_g0_dynare()
%
%   Reads Dynare 4.6.1's swX1 results (C:\dynare_work\sw_ext\swX1_out.mat: bayestopt_,
%   estim_params_, oo_.dr, options_) and the mode file of the model package, evaluates
%   Dynare's priordens at the swX1 mode and at 200 random points inside the bounds (seed 1),
%   and saves everything est_00_gates needs to results/estimation/gates/g0_dynare.mat:
%   names, pshape, p1-p4, p6, p7, bounds, xmode, fval, hh, lp_mode, X, lp_rand,
%   restrict_names (Dynare's restricted state vector), varobs, lik_init, presample.
%   Dynare is not run; only its priordens function is called.

c = est_config();
if isempty(c.dynare_matlab)
    error('est_00_g0_dynare:noDynare', ['Dynare 4.6.1 not found. Either set the environment variable ' ...
        'HETLEARN_DYNARE_DIR to its matlab folder, e.g. setenv(''HETLEARN_DYNARE_DIR'', ''D:\\dynare-4.6.1\\matlab''), ' ...
        'or put dynare-4.6.1 next to the project folder (%s).'], fileparts(c.project));
end
addpath(c.dynare_matlab);
addpath(fullfile(c.dynare_matlab, 'distributions'));
S = load(c.swx1_out);
M = load(fullfile(c.toolbox_root, 'models', 'sw07', 'estimation', 'swX1_mode.mat'));
bt = S.bayestopt_;
ep = S.estim_params_;
bounds = [];
if ep.nvx > 0
    bounds = [bounds; ep.var_exo(:, 3:4)];
end
if ep.np > 0
    bounds = [bounds; ep.param_vals(:, 3:4)];
end
x = M.xparam1(:);
G = struct();
G.names = bt.name;
G.pshape = bt.pshape;
G.p1 = bt.p1; G.p2 = bt.p2; G.p3 = bt.p3; G.p4 = bt.p4; G.p6 = bt.p6; G.p7 = bt.p7;
G.bounds = bounds;
G.xmode = x;
G.fval = M.fval;
G.hh = M.hh;
G.lp_mode = priordens(x, bt.pshape, bt.p6, bt.p7, bt.p3, bt.p4, true);   % true: initialise its persistent indices
rs = RandStream('mt19937ar', 'Seed', 1);
nR = 200;
G.X = zeros(numel(x), nR);
G.lp_rand = zeros(nR, 1);
for k = 1:nR
    u = rand(rs, numel(x), 1);
    xk = bounds(:, 1) + u.*(bounds(:, 2) - bounds(:, 1));
    G.X(:, k) = xk;
    G.lp_rand(k) = priordens(xk, bt.pshape, bt.p6, bt.p7, bt.p3, bt.p4);
end
dr = S.oo_.dr;
en = cellstr(S.M_.endo_names);
rv = dr.restrict_var_list;
G.restrict_names = en(dr.order_var(rv))';
G.varobs = cellstr(S.options_.varobs);
G.lik_init = S.options_.lik_init;
G.presample = S.options_.presample;
G.riccati_tol = S.options_.riccati_tol;
G.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
out = fullfile(c.results, 'gates');
if exist(out, 'dir') ~= 7
    mkdir(out);
end
save(fullfile(out, 'g0_dynare.mat'), '-struct', 'G');
fprintf('Dynare priordens at the swX1 mode %.12f; fval %.10f; %d random points; restricted vector %d\n', ...
    G.lp_mode, G.fval, nR, numel(G.restrict_names));
end
