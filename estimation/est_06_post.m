function est_06_post(mode, varargin)
%EST_06_POST  Post-processing of the RE and learning estimates: the tables of the estimation report.
%
%   est_06_post('interim')    % learning chains still running: completed 1,000-draw blocks only
%   est_06_post('final')      % every learning chain finished (progress.txt: status done)
%   est_06_post('modes')      % posterior modes only: no learning chain is read (MCMC paused), every table at the modes
%   est_06_post(mode, 'draws', 'stage2')   % learning draws of the stage-2 chains (est_07_mcmc_stage2)
%   est_06_post(mode, 'parts', {'params', 'mdd'}, 'n_fx', 600, 'n_re', 4000, 'min_age_s', 120)
%
%   'modes' (added 2026-10-20, when the MCMC was paused at the user's request) reads no learning
%   chain and writes the same files with status 'modes', learn_draws 0 and draws 'none', with
%   what the modes give: params.csv mode and sd_hessian for re, learn, learn_current, learn_calib
%   (no mean, sd, quantiles), plus source re_posterior (mean, sd, q05, q50, q95 of the converged RE
%   chains, from re/posterior_summary.csv; the page quotes it once), compare
%   diff_mode_in_re_sd_hessian, flag_mode_2sd_hessian (|learning mode - RE mode| > 2 RE Hessian
%   sds) and mover_rank (the movers ranked in RE Hessian sds), prior sd_local_learn_mode
%   (1/sqrt(-d2 log prior/dx2) at the learning mode); mdd.csv Laplace only,
%   the variants (c) fixed initial beliefs and (d) 'freeze' as likelihoods at the baseline mode
%   (log_likelihood_at_baseline_mode, log_posterior_at_baseline_mode, log_likelihood_minus_
%   baseline), no MHM; prior_post_long.csv densities prior, re_laplace, learn_laplace (the normal
%   N(mode, Hessian sd^2), not truncated); lpd_long.csv the l_t at the modes, their difference
%   and its cumulative sum (no band); paths_long.csv source mode, data and calibrated (with the
%   calibrated fRE and fBR of results/a1_learn/learning.csv); rmse.csv, irfs_long.csv and
%   app1_long.csv as always (they are at the modes anyway); app1_post via
%   est_06b_app1_post('modes') (at the modes; for RE also the posterior over 200 thinned draws of
%   the finished RE chains); diagnostics.csv the mode searches (starts, how many reached the
%   mode), Hessians, facility events at the modes, the progress of every chain (progress.txt and
%   the list of block files; no chain file is opened) and the rows of learn/mcmc_paused.txt.
%
%   'interim' reads the block files of the running chains with hlest.read_blocks (never
%   state.mat; files younger than min_age_s seconds are skipped, so a block being written
%   cannot crash it), applies the burn-in to what is there and writes status 'interim' and
%   the draw count into every table. 'final' first checks that every learning chain is done.
%   'draws' (learning model only; the RE draws are always re/chains with a 50% burn-in):
%     'stage1'  (default) learn/chains, burn-in the first 50% of every chain
%     'stage2'  learn/chains2 (est_07_mcmc_stage2), stage 1 treated as adaptation: burn-in the
%               first 10% of every stage-2 chain; 'final' checks the stage-2 chains
%   Which draws were used is written into every table (column draws = stage1 | stage2) and into
%   post_meta.csv (learn_sample, burn_in). R-hat and ESS: chains truncated to the shortest.
%
%   Writes results/estimation/tables/ (long format; every file also has the columns status,
%   learn_draws = learning draws read, all chains, before burn-in, and draws):
%     params.csv          name, group, label, source, stat, value, text: 39 parameters x
%                         sources published_sw07, swx1 (mode, sd_hessian), re and learn (mode,
%                         sd_hessian, mean, sd, q05, q50, q95), learn_current, learn_calib (mode,
%                         sd_hessian), prior (mean, sd, lb, ub; text = shape), prior_calib,
%                         ijcb_survey and ijcb_nosurvey (mean, lo, hi), calibration (value),
%                         compare (diff_mean_in_re_sd, flag_mean_2sd, diff_mode_in_re_sd,
%                         flag_mode_2sd: learning minus RE in RE posterior sds), mover_rank
%     mdd.csv             model, method, p, value, note: Laplace and MHM (p = 0.1..0.9) log MDD,
%                         log posterior/likelihood/prior at the modes, variants, log Bayes factors
%                         (natural log and log10), like with like
%     prior_post_long.csv param, density (prior | re | learn), x, value: prior and kernel
%                         posterior densities for gain, omega, chi and the 4 structural parameters
%                         that move most between the modes (in RE posterior sds)
%     lpd_long.csv        date, series, value: l_t at the modes, their difference and its
%                         cumulative sum from 1966Q1, posterior quantiles of the cumulative
%                         difference (learning path draws paired with re-evaluated RE draws)
%     rmse.csv            model, variable, sample, rmse, n, units: one-step-ahead prediction
%                         errors of the two filters at the modes
%     paths_long.csv      date, variable, source, stat, value: n2, n2_model, alpha, beta, pmean,
%                         fRE, fBR (mode, post q05/q50/q95), the calibrated a1_learn history,
%                         inflation data
%     irfs_long.csv       model, shock, variable, h, value, units: IRFs at the modes (one sd)
%     app1_long.csv       scenario, source, variable, date, stage, value: application 1 through
%                         the engine at the modes (e1_re, e1_learn, e1_learn_re, e1_learn_smoothed;
%                         a sensitivity since 2026-10-20) and calibrated (a1_re, a1_learn), data
%     diagnostics.csv     model, chain, parameter, metric, value, text (with the go/no-go rows of
%                         learn/gonogo.txt, learn/gonogo_override.txt and learn/gonogo2.txt)
%     post_meta.csv       key, value
%   and runs application 1 at the modes through the engine (estimation/models/sw07_est_*,
%   estimation/scenarios/e1_*.m, all generated here) with results in results/estimation/app1/.
%
%   Part 'app1_post' (after 'app1', whose engine runs it reads) runs est_06b_app1_post(mode, 'draws', ..., 'max_blocks',
%   ...): application 1 consistent with the likelihood at the modes and 200 posterior draws per model
%   (tables/app1_post_long.csv, app1_post_summary.csv) and the share sensitivity (share_sensitivity.csv).
%   Run time (interim, 6 x ~26,000 learning draws): about 10 minutes with one thread.

if nargin < 1 || isempty(mode)
    mode = 'interim';
end
if ~any(strcmp(mode, {'interim', 'final', 'modes'}))
    error('est_06_post:mode', 'mode must be ''interim'', ''final'' or ''modes''.');
end
modes = strcmp(mode, 'modes');
ip = inputParser;
ip.addParameter('parts', {'params', 'mdd', 'prior_post', 'lpd', 'rmse', 'paths', 'irfs', 'app1', 'app1_post', 'diag'});
ip.addParameter('n_fx', 600);
ip.addParameter('n_re', 4000);
ip.addParameter('min_age_s', 120);
ip.addParameter('max_blocks', Inf);     % interim: read at most this many blocks per learning chain (aligns runs)
ip.addParameter('seed', 606);
ip.addParameter('draws', 'stage1');
ip.parse(varargin{:});
o = ip.Results;
parts = cellstr(o.parts);
switch o.draws
    case 'stage1'
        ldir = 'chains';
        burnL = 0.5;
        labL = 'stage 1 (learn/chains), first 50% of every chain dropped';
    case 'stage2'
        ldir = 'chains2';
        burnL = 0.1;
        labL = ['stage 2 (learn/chains2, est_07_mcmc_stage2; proposal = covariance of the stage-1 draws), ' ...
            'first 10% of every stage-2 chain dropped (stage 1 treated as adaptation)'];
    otherwise
        error('est_06_post:draws', 'draws must be ''stage1'' or ''stage2''.');
end
tAll = tic;
c = setup_est();
maxNumCompThreads(c.threads_learn);
tdir = fullfile(c.results, 'tables');
if exist(tdir, 'dir') ~= 7
    mkdir(tdir);
end
fprintf('est_06_post(''%s'') started %s\n', mode, datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>

% ---- chains ---------------------------------------------------------------------------------
G = struct();
G.status = mode;
if modes
    % posterior modes only (the MCMC is paused): no learning chain is read, every table is at the modes (part
    % app1_post reads the finished RE chains once, for the RE posterior of application 1)
    RE = struct('name', {}, 'C', {}, 'target', {}, 'note', {});
    LE = RE;
    PR = struct();
    PL = struct();
    G.learn_draws = 0;
    G.draws = 'none';
    labL = 'none: posterior modes only (no learning chain is read)';
    burnL = NaN;
    fprintf('modes only: no learning chain is read\n');
else
    final = strcmp(mode, 'final');
    RE = read_set(fullfile(c.results, 're', 'chains'), false, 0, true);
    % 'final': the chains have stopped, so no block can be in the middle of being written (min age 0)
    LE = read_set(fullfile(c.results, 'learn', ldir), true, ternary(final, 0, o.min_age_s), final, o.max_blocks);
    if numel(LE) < 2
        error('est_06_post:chains', 'Fewer than 2 learning chains with 2 or more completed blocks in learn/%s.', ldir);
    end
    PR = pool(RE, false, 0.5);
    PL = pool(LE, true, burnL);
    G.learn_draws = sum(PL.n);
    G.draws = o.draws;
    fprintf('RE: %d chains, draws %s; learning (%s): %d chains, draws %s (%d read), %d path draws after burn-in\n', ...
        numel(RE), mat2str(PR.n), labL, numel(LE), mat2str(PL.n), G.learn_draws, numel(PL.paths));
end

% ---- problems and modes -----------------------------------------------------------------------
pbR = hlest.problem('re');
pbL = hlest.problem('learn');
MR = load(fullfile(c.results, 're', 'mode.mat'));
ML = load(fullfile(c.results, 'learn', 'mode.mat'));
HL = load(fullfile(c.results, 'learn', 'hessian.mat'));
MC = load(fullfile(c.results, 'learn_current', 'mode.mat'));
HC = load(fullfile(c.results, 'learn_current', 'hessian.mat'));
MK = load(fullfile(c.results, 'learn_calib', 'mode.mat'));
HK = load(fullfile(c.results, 'learn_calib', 'hessian.mat'));
RB = load(fullfile(c.results, 'learn', 'robust.mat'));
assert(isequal(MR.names(:), pbR.tab.name(:)) && isequal(ML.names(:), pbL.tab.name(:)), 'est_06_post: parameter order');
assert(abs(pbL.dates(1) - double(qq(1965, 1))) < 1e-6, 'est_06_post: the filter does not start in 1965Q1');
Q = qlabels(pbL.nT);
X = struct('c', c, 'o', o, 'G', G, 'tdir', tdir, 'RE', {RE}, 'LE', {LE}, 'PR', PR, 'PL', PL, 'pbR', pbR, 'pbL', pbL, ...
    'MR', MR, 'ML', ML, 'HL', HL, 'MC', MC, 'HC', HC, 'MK', MK, 'HK', HK, 'RB', RB, 'Q', {Q}, 'labL', labL, 'burnL', burnL);
X.modes = modes;
X.movers = movers(X);

% ---- parts ----------------------------------------------------------------------------------
meta = {};
failed = {};
for k = 1:numel(parts)
    t0 = tic;
    try
        switch parts{k}
            case 'params',     m = part_params(X);         % both branch on X.modes inside
            case 'mdd',        m = part_mdd(X);
            case 'prior_post', m = part_prior_post(X);
            case 'lpd',        m = part_lpd(X);
            case 'rmse',       m = part_rmse(X);           % at the modes in every mode
            case 'paths',      m = part_paths(X);
            case 'irfs',       m = part_irfs(X);           % at the modes in every mode
            case 'app1',       m = part_app1(X);           % at the modes in every mode
            case 'app1_post',  m = part_app1_post(X, mode);
            case 'diag',       m = part_diag(X);
            otherwise
                error('est_06_post:part', 'Unknown part %s.', parts{k});
        end
        meta = [meta; m]; %#ok<AGROW>
        fprintf('  %-10s done (%.0f s)\n', parts{k}, toc(t0));
    catch err
        failed{end+1} = parts{k}; %#ok<AGROW>
        fprintf('  %-10s FAILED: %s\n', parts{k}, getReport(err));
    end
end

% ---- post_meta.csv --------------------------------------------------------------------------
if modes
    kv = {'status', mode; 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS'); ... %#ok<TNOW1,DATST>
        'toolbox_root', c.toolbox_root; 'learn_draws_source', 'none'; 'learn_sample', labL; ...
        'learn_draws', '0'; 'movers', strjoin(X.movers, ' '); ...
        'movers_measure', '|learning mode - RE mode| in RE Hessian sds (re/mode.mat Sigma)'; ...
        're_mode_created', X.MR.created; 'learn_mode_created', X.ML.created; ...
        're_posterior', re_posterior_note(c); ...
        'parts_run', strjoin(parts, ' '); 'parts_failed', strjoin(failed, ' ')};
else
    kv = {'status', mode; 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS'); ... %#ok<TNOW1,DATST>
        'toolbox_root', c.toolbox_root; ...
        'burn_in', ternary(strcmp(o.draws, 'stage1'), 'first 50% of every chain', ...
        'learning: first 10% of every stage-2 chain (stage 1 = adaptation); RE: first 50% of every chain'); ...
        'learn_draws_source', o.draws; 'learn_sample', labL; 'learn_burn_share', sprintf('%.2f', burnL); ...
        'learn_chains', sprintf('%d', numel(LE)); 'learn_draws_per_chain', strjoin(arrayfun(@(x) sprintf('%d', x), PL.n, 'UniformOutput', false), ' '); ...
        'learn_draws', sprintf('%d', G.learn_draws); 'learn_post_draws', sprintf('%d', size(PL.X, 1)); ...
        'learn_path_draws', sprintf('%d', numel(PL.paths)); 'learn_chain_notes', strjoin({LE.note}, ' | '); ...
        're_chains', sprintf('%d', numel(RE)); 're_draws_per_chain', strjoin(arrayfun(@(x) sprintf('%d', x), PR.n, 'UniformOutput', false), ' '); ...
        're_post_draws', sprintf('%d', size(PR.X, 1)); 'movers', strjoin(X.movers, ' '); ...
        'parts_run', strjoin(parts, ' '); 'parts_failed', strjoin(failed, ' ')};
end
kv = [kv; meta];
kv(end+1, :) = {'runtime_s', sprintf('%.0f', toc(tAll))};
st = repmat({mode}, size(kv, 1), 1);
fm = fullfile(tdir, 'post_meta.csv');
if exist(fm, 'file') == 2
    % keep the keys of earlier runs (other parts) that this run did not write, with their status
    io = detectImportOptions(fm, 'Delimiter', ',');
    io = setvartype(io, {'key', 'value', 'status'}, 'char');
    T0 = readtable(fm, io);
    old = ~ismember(T0.key, kv(:, 1));
    if modes
        old = old & strcmp(T0.status, 'modes');     % never carry keys of a chain-based run into a modes table
    end
    kv = [kv; [T0.key(old), cellfun(@num2str_keep, T0.value(old), 'UniformOutput', false)]];
    st = [st; T0.status(old)];
end
write_long(fm, struct('status', {st}, 'learn_draws', G.learn_draws), 'key', kv(:, 1), 'value', kv(:, 2));
fprintf('est_06_post(''%s'') finished in %.0f s; tables in %s\n', mode, toc(tAll), tdir);
if ~isempty(failed)
    error('est_06_post:failed', 'Parts failed: %s (the other tables were written).', strjoin(failed, ', '));
end
end


% =============================================================================================
% chains
% =============================================================================================
function S = read_set(base, withPaths, minAge, needDone, maxBlocks)
if nargin < 5
    maxBlocks = Inf;
end
dd = dir(fullfile(base, 'chain_*'));
dd = dd([dd.isdir]);
S = struct('name', {}, 'C', {}, 'target', {}, 'note', {});
for k = 1:numel(dd)
    cdir = fullfile(dd(k).folder, dd(k).name);
    C = hlest.read_blocks(cdir, withPaths, minAge);
    if C.nblocks > maxBlocks
        C = cap_blocks(C, maxBlocks);
    end
    tgt = NaN;
    if needDone
        [tgt, st] = progress_of(cdir);
        if ~strcmp(st, 'done') || C.n < tgt
            error('est_06_post:final', ['chain %s is not complete (%d of %d draws read, status %s); ' ...
                'run est_06_post(''interim'') instead.'], dd(k).name, C.n, tgt, st);
        end
    end
    if C.nblocks >= 2
        S(end+1) = struct('name', dd(k).name, 'C', C, 'target', tgt, 'note', ...
            sprintf('%s %d blocks %s', dd(k).name, C.nblocks, C.note)); %#ok<AGROW>
    end
end
end


function C = cap_blocks(C, nb)
% The first nb blocks of a chain read by hlest.read_blocks (option max_blocks).
n = nb*size(C.draws, 1)/C.nblocks;
C.draws = C.draws(1:n, :);
C.lp = C.lp(1:n);
C.ll = C.ll(1:n);
C.acc = C.acc(1:n);
C.ev = C.ev(1:n, :);
if ~isempty(C.pidx)
    k = C.pidx <= n;
    C.pidx = C.pidx(k);
    C.paths = C.paths(k);
end
C.n = n;
C.nblocks = nb;
C.note = strtrim(sprintf('%s capped at %d blocks', C.note, nb));
end


function [tgt, st] = progress_of(cdir)
tgt = NaN;
st = '';
f = fullfile(cdir, 'progress.txt');
if exist(f, 'file') ~= 2
    return
end
txt = fileread(f);
t = regexp(txt, 'ndraws = (\d+)', 'tokens', 'once');
if ~isempty(t)
    tgt = str2double(t{1});
end
t = regexp(txt, 'status = (\w+)', 'tokens', 'once');
if ~isempty(t)
    st = t{1};
end
end


function P = pool(S, withPaths, burn)
% Every chain after its first burn share (0.5: the second half) pooled; diagnostics on the chains
% truncated to the shortest, with the same burn share.
if nargin < 3
    burn = 0.5;
end
m = numel(S);
d = size(S(1).C.draws, 2);
P = struct('n', arrayfun(@(s) s.C.n, S), 'acc', arrayfun(@(s) mean(s.C.acc), S));
Xc = cell(m, 1); LPc = Xc; LLc = Xc; EVc = Xc; CHc = Xc;
PAc = Xc; PTc = Xc; PCc = Xc; PIc = Xc;
for k = 1:m
    C = S(k).C;
    h = floor(burn*C.n);
    Xc{k} = C.draws(h+1:end, :);
    LPc{k} = C.lp(h+1:end);
    LLc{k} = C.ll(h+1:end);
    EVc{k} = C.ev(h+1:end, :);
    CHc{k} = k*ones(C.n - h, 1);
    if withPaths
        keep = C.pidx > h;
        PAc{k} = C.paths(keep);
        PTc{k} = C.draws(C.pidx(keep), :);
        PCc{k} = k*ones(nnz(keep), 1);
        PIc{k} = C.pidx(keep);
    end
end
P.X = vertcat(Xc{:});
P.LP = vertcat(LPc{:});
P.LL = vertcat(LLc{:});
P.EV = vertcat(EVc{:});
P.chain = vertcat(CHc{:});
P.paths = {};
if withPaths
    P.paths = vertcat(PAc{:});
    P.ptheta = vertcat(PTc{:});
    P.pchain = vertcat(PCc{:});
    P.pidx = vertcat(PIc{:});
end
n = min(P.n);
h = floor(burn*n);
P.burn = burn;
X3 = zeros(n - h, m, d);
for k = 1:m
    X3(:, k, :) = reshape(S(k).C.draws(h+1:n, :), n - h, 1, d);
end
P.diag = hlest.diagnostics(X3);
P.n_diag = n;
P.burn_diag = h;
P.mean = mean(P.X, 1)';
P.sd = std(P.X, 0, 1)';
q = quantiles(P.X, [0.05 0.5 0.95]);
P.q05 = q(:, 1);
P.q50 = q(:, 2);
P.q95 = q(:, 3);
end


function mv = movers(X)
% The 4 structural parameters whose modes differ most between learning and RE, in RE posterior sds
% ('modes': in RE Hessian sds, the inverse Hessian at the RE mode).
if X.modes
    z = abs(X.ML.xm(1:36) - X.MR.xm)./sqrt(diag(X.MR.Sigma));
else
    z = abs(X.ML.xm(1:36) - X.MR.xm)./X.PR.sd;
end
[~, o] = sort(z, 'descend');
mv = reshape(X.pbR.tab.name(o(1:4)), 1, []);
end


% =============================================================================================
% params.csv
% =============================================================================================
function meta = part_params(X)
if X.modes
    meta = part_params_modes(X);
    return
end
T = readtable(fullfile(X.pbR.spec.folder, 'estimation', 'mode_original_vs_extended.csv'), 'TextType', 'char');
info = param_info();
tabL = X.pbL.tab;
tabK = hlest.param_table('learn', 'calib', X.pbL.Pbase);
R = {};
sdHR = sqrt(diag(X.MR.Sigma));
sdHL = sqrt(diag(X.HL.Sigma));
sdHC = sqrt(diag(X.HC.Sigma));
sdHK = sqrt(diag(X.HK.Sigma));
shapes = {'beta', 'gamma', 'normal', 'inv_gamma_1'};
ijcbS = struct('gain', [0.0585 0.0584 0.0587], 'omega', [0.62 0.49 0.74], 'chi', [0.51 0.38 0.66]);
ijcbN = struct('gain', [0.0036 0.0017 0.0137], 'omega', [0.78 0.67 0.94], 'chi', [4.63 1.36 7.45]);
calib = struct('gain', 0.0585, 'omega', 0.6, 'chi', 0.51);
for i = 1:tabL.n
    nm = tabL.name{i};
    gi = find(strcmp(info(:, 1), nm));
    grp = info{gi, 2};
    lab = info{gi, 3};
    add = @(src, stat, v, txt) {nm, grp, lab, src, stat, v, txt};
    isS = i <= 36;
    if isS
        r = find(strcmp(T.parameter, nm));
        R(end+1, :) = add('published_sw07', 'mode', T.published_sw07(r), ''); %#ok<AGROW>
        R(end+1, :) = add('swx1', 'mode', T.ext_mode_1966_2026(r), ''); %#ok<AGROW>
        R(end+1, :) = add('swx1', 'sd_hessian', T.ext_sd(r), ''); %#ok<AGROW>
        R = [R; stats_rows(add, 're', X.MR.xm(i), sdHR(i), X.PR, i)]; %#ok<AGROW>
    end
    R = [R; stats_rows(add, 'learn', X.ML.xm(i), sdHL(i), X.PL, i)]; %#ok<AGROW>
    R(end+1, :) = add('learn_current', 'mode', X.MC.xm(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_current', 'sd_hessian', sdHC(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_calib', 'mode', X.MK.xm(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_calib', 'sd_hessian', sdHK(i), ''); %#ok<AGROW>
    R(end+1, :) = add('prior', 'mean', tabL.p1(i), shapes{tabL.shape(i)}); %#ok<AGROW>
    R(end+1, :) = add('prior', 'sd', tabL.p2(i), shapes{tabL.shape(i)}); %#ok<AGROW>
    R(end+1, :) = add('prior', 'lb', tabL.lb(i), ''); %#ok<AGROW>
    R(end+1, :) = add('prior', 'ub', tabL.ub(i), ''); %#ok<AGROW>
    if isS
        dMean = (X.PL.mean(i) - X.PR.mean(i))/X.PR.sd(i);
        dMode = (X.ML.xm(i) - X.MR.xm(i))/X.PR.sd(i);
        R(end+1, :) = add('compare', 'diff_mean_in_re_sd', dMean, ''); %#ok<AGROW>
        R(end+1, :) = add('compare', 'flag_mean_2sd', double(abs(dMean) > 2), ''); %#ok<AGROW>
        R(end+1, :) = add('compare', 'diff_mode_in_re_sd', dMode, ''); %#ok<AGROW>
        R(end+1, :) = add('compare', 'flag_mode_2sd', double(abs(dMode) > 2), ''); %#ok<AGROW>
        rk = find(strcmp(X.movers, nm));
        if ~isempty(rk)
            R(end+1, :) = add('compare', 'mover_rank', rk, ''); %#ok<AGROW>
        end
    else
        R(end+1, :) = add('prior_calib', 'mean', tabK.p1(i), shapes{tabK.shape(i)}); %#ok<AGROW>
        R(end+1, :) = add('prior_calib', 'sd', tabK.p2(i), shapes{tabK.shape(i)}); %#ok<AGROW>
        s = ijcbS.(nm);
        n = ijcbN.(nm);
        R(end+1, :) = add('ijcb_survey', 'mean', s(1), 'IJCB Table 1 (HE model, with survey expectations)'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_survey', 'lo', s(2), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_survey', 'hi', s(3), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'mean', n(1), 'IJCB Table G.1 (HE model, no expectations data)'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'lo', n(2), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'hi', n(3), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('calibration', 'value', calib.(nm), 'toolbox calibration (config/master_options.m)'); %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'params.csv'), X.G, 'name', R(:, 1), 'group', R(:, 2), 'label', R(:, 3), ...
    'source', R(:, 4), 'stat', R(:, 5), 'value', cell2mat(R(:, 6)), 'text', R(:, 7));
nf = 0;
for i = 1:36
    nf = nf + double(abs((X.PL.mean(i) - X.PR.mean(i))/X.PR.sd(i)) > 2);
end
meta = {'params_flagged_mean_2sd', sprintf('%d', nf)};
end


function meta = part_params_modes(X)
% params.csv at the modes: mode and Hessian sd of every model, no posterior moments; learning minus
% RE in RE Hessian sds; the local prior sd at the learning mode.
T = readtable(fullfile(X.pbR.spec.folder, 'estimation', 'mode_original_vs_extended.csv'), 'TextType', 'char');
info = param_info();
tabL = X.pbL.tab;
tabK = hlest.param_table('learn', 'calib', X.pbL.Pbase);
R = {};
sdHR = sqrt(diag(X.MR.Sigma));
sdHL = sqrt(diag(X.HL.Sigma));
sdHC = sqrt(diag(X.HC.Sigma));
sdHK = sqrt(diag(X.HK.Sigma));
sdLoc = prior_local_sd(tabL, X.ML.xm);
shapes = {'beta', 'gamma', 'normal', 'inv_gamma_1'};
% the converged RE posterior (re/posterior_summary.csv, est_02_mcmc_re('post'): re/chains, second half
% of every chain); the modes page quotes it once, to place the RE mode in its own posterior
fps = fullfile(X.c.results, 're', 'posterior_summary.csv');
TP = [];
if exist(fps, 'file') == 2
    TP = readtable(fps, 'TextType', 'char');
    assert(isequal(TP.name(:), X.pbR.tab.name(:)), 'params: re/posterior_summary.csv parameter order');
    assert(max(abs(TP.mode - X.MR.xm)) < 1e-12, 'params: re/posterior_summary.csv is not at the current RE mode');
end
% as part_params (IJCB Table 1 and Table G.1; config/master_options.m)
ijcbS = struct('gain', [0.0585 0.0584 0.0587], 'omega', [0.62 0.49 0.74], 'chi', [0.51 0.38 0.66]);
ijcbN = struct('gain', [0.0036 0.0017 0.0137], 'omega', [0.78 0.67 0.94], 'chi', [4.63 1.36 7.45]);
calib = struct('gain', 0.0585, 'omega', 0.6, 'chi', 0.51);
nf = 0;
for i = 1:tabL.n
    nm = tabL.name{i};
    gi = find(strcmp(info(:, 1), nm));
    grp = info{gi, 2};
    lab = info{gi, 3};
    add = @(src, stat, v, txt) {nm, grp, lab, src, stat, v, txt};
    isS = i <= 36;
    if isS
        r = find(strcmp(T.parameter, nm));
        R(end+1, :) = add('published_sw07', 'mode', T.published_sw07(r), ''); %#ok<AGROW>
        R(end+1, :) = add('swx1', 'mode', T.ext_mode_1966_2026(r), ''); %#ok<AGROW>
        R(end+1, :) = add('swx1', 'sd_hessian', T.ext_sd(r), ''); %#ok<AGROW>
        R(end+1, :) = add('re', 'mode', X.MR.xm(i), ''); %#ok<AGROW>
        R(end+1, :) = add('re', 'sd_hessian', sdHR(i), ''); %#ok<AGROW>
        if ~isempty(TP)
            for st = {'mean', 'sd', 'q05', 'q50', 'q95'}
                R(end+1, :) = add('re_posterior', st{1}, TP.(st{1})(i), ...
                    're/posterior_summary.csv (converged RE chains, second halves)'); %#ok<AGROW>
            end
        end
    end
    R(end+1, :) = add('learn', 'mode', X.ML.xm(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn', 'sd_hessian', sdHL(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_current', 'mode', X.MC.xm(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_current', 'sd_hessian', sdHC(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_calib', 'mode', X.MK.xm(i), ''); %#ok<AGROW>
    R(end+1, :) = add('learn_calib', 'sd_hessian', sdHK(i), ''); %#ok<AGROW>
    R(end+1, :) = add('prior', 'mean', tabL.p1(i), shapes{tabL.shape(i)}); %#ok<AGROW>
    R(end+1, :) = add('prior', 'sd', tabL.p2(i), shapes{tabL.shape(i)}); %#ok<AGROW>
    R(end+1, :) = add('prior', 'lb', tabL.lb(i), ''); %#ok<AGROW>
    R(end+1, :) = add('prior', 'ub', tabL.ub(i), ''); %#ok<AGROW>
    R(end+1, :) = add('prior', 'sd_local_learn_mode', sdLoc(i), ...
        '1/sqrt(-d2 log prior/dx2) at the learning mode (central differences)'); %#ok<AGROW>
    if isS
        dMode = (X.ML.xm(i) - X.MR.xm(i))/sdHR(i);
        R(end+1, :) = add('compare', 'diff_mode_in_re_sd_hessian', dMode, ''); %#ok<AGROW>
        R(end+1, :) = add('compare', 'flag_mode_2sd_hessian', double(abs(dMode) > 2), ''); %#ok<AGROW>
        nf = nf + double(abs(dMode) > 2);
        rk = find(strcmp(X.movers, nm));
        if ~isempty(rk)
            R(end+1, :) = add('compare', 'mover_rank', rk, 'rank of |learning mode - RE mode| in RE Hessian sds'); %#ok<AGROW>
        end
    else
        R(end+1, :) = add('prior_calib', 'mean', tabK.p1(i), shapes{tabK.shape(i)}); %#ok<AGROW>
        R(end+1, :) = add('prior_calib', 'sd', tabK.p2(i), shapes{tabK.shape(i)}); %#ok<AGROW>
        s = ijcbS.(nm);
        n = ijcbN.(nm);
        R(end+1, :) = add('ijcb_survey', 'mean', s(1), 'IJCB Table 1 (HE model, with survey expectations)'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_survey', 'lo', s(2), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_survey', 'hi', s(3), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'mean', n(1), 'IJCB Table G.1 (HE model, no expectations data)'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'lo', n(2), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('ijcb_nosurvey', 'hi', n(3), 'interval as printed in IJCB'); %#ok<AGROW>
        R(end+1, :) = add('calibration', 'value', calib.(nm), 'toolbox calibration (config/master_options.m)'); %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'params.csv'), X.G, 'name', R(:, 1), 'group', R(:, 2), 'label', R(:, 3), ...
    'source', R(:, 4), 'stat', R(:, 5), 'value', cell2mat(R(:, 6)), 'text', R(:, 7));
meta = {'params_flagged_mode_2sd_hessian', sprintf('%d', nf)};
end


function s = prior_local_sd(tab, x)
% 1/sqrt(-d2 log p_i/dx_i2) of each marginal prior at x (central differences; NaN where the
% curvature is not negative).
n = numel(x);
s = NaN(n, 1);
for i = 1:n
    h = 1e-4*max(abs(x(i)), 1e-2);
    xx = x;
    v = zeros(1, 3);
    for j = -1:1
        xx(i) = x(i) + j*h;
        [~, lpi] = hlest.prior_logpdf(tab, xx);
        v(j + 2) = lpi(i);
    end
    d2 = (v(1) - 2*v(2) + v(3))/h^2;
    if isfinite(d2) && d2 < 0
        s(i) = 1/sqrt(-d2);
    end
end
end


function R = stats_rows(add, src, xm, sdh, P, i)
R = {};
R(end+1, :) = add(src, 'mode', xm, '');
R(end+1, :) = add(src, 'sd_hessian', sdh, '');
R(end+1, :) = add(src, 'mean', P.mean(i), '');
R(end+1, :) = add(src, 'sd', P.sd(i), '');
R(end+1, :) = add(src, 'q05', P.q05(i), '');
R(end+1, :) = add(src, 'q50', P.q50(i), '');
R(end+1, :) = add(src, 'q95', P.q95(i), '');
end


function G = param_info()
G = {
    'ea',         'shocks',    'sd of the productivity shock'
    'eb',         'shocks',    'sd of the risk premium shock'
    'eg',         'shocks',    'sd of the spending shock'
    'eqs',        'shocks',    'sd of the investment shock'
    'em',         'shocks',    'sd of the monetary policy shock'
    'epinf',      'shocks',    'sd of the price mark-up shock'
    'ew',         'shocks',    'sd of the wage mark-up shock'
    'crhoa',      'shocks',    'AR(1) of productivity'
    'crhob',      'shocks',    'AR(1) of the risk premium'
    'crhog',      'shocks',    'AR(1) of spending'
    'crhoqs',     'shocks',    'AR(1) of investment'
    'crhoms',     'shocks',    'AR(1) of the monetary policy shock'
    'crhopinf',   'shocks',    'AR(1) of the price mark-up'
    'crhow',      'shocks',    'AR(1) of the wage mark-up'
    'cmap',       'shocks',    'MA(1) of the price mark-up'
    'cmaw',       'shocks',    'MA(1) of the wage mark-up'
    'cgy',        'shocks',    'productivity shock in spending'
    'csadjcost',  'frictions', 'investment adjustment cost'
    'csigma',     'frictions', 'inverse elasticity of substitution'
    'chabb',      'frictions', 'habit persistence'
    'cprobw',     'frictions', 'Calvo probability of wages'
    'csigl',      'frictions', 'inverse Frisch elasticity'
    'cprobp',     'frictions', 'Calvo probability of prices'
    'cindw',      'frictions', 'wage indexation'
    'cindp',      'frictions', 'price indexation'
    'czcap',      'frictions', 'capacity utilisation cost'
    'cfc',        'frictions', 'fixed cost (gross mark-up)'
    'crpi',       'policy',    'Taylor rule: inflation'
    'crr',        'policy',    'Taylor rule: smoothing'
    'cry',        'policy',    'Taylor rule: output gap'
    'crdy',       'policy',    'Taylor rule: change in the output gap'
    'constepinf', 'trends',    'steady-state inflation (% per quarter)'
    'constebeta', 'trends',    'discount rate 100(1/beta - 1)'
    'constelab',  'trends',    'hours constant'
    'ctrend',     'trends',    'trend growth (% per quarter)'
    'calfa',      'trends',    'capital share'
    'gain',       'learning',  'constant gain'
    'omega',      'learning',  'memory of the fitness measure'
    'chi',        'learning',  'intensity of choice'
    };
end


% =============================================================================================
% mdd.csv
% =============================================================================================
function meta = part_mdd(X)
if X.modes
    meta = part_mdd_modes(X);
    return
end
[mhR, p] = hlest.mdd_mhm(X.PR.X, X.PR.LP);
mhL = hlest.mdd_mhm(X.PL.X, X.PL.LP);
nR = size(X.PR.X, 1);
nL = size(X.PL.X, 1);
R = {};
noteR = sprintf('%d chains, %d post burn-in draws', numel(X.RE), nR);
noteL = sprintf('%d chains, %d post burn-in draws (%s)', numel(X.LE), nL, X.G.status);
R = [R; mode_rows('re', X.MR.lp, X.MR.ll, X.MR.lpr, 'RE, 36 parameters')];
R(end+1, :) = {'re', 'laplace', NaN, X.MR.laplace, 'Laplace at the mode (Hessian PD)'};
for k = 1:numel(p)
    R(end+1, :) = {'re', 'mhm', p(k), mhR(k), noteR}; %#ok<AGROW>
end
R(end+1, :) = {'swx1_new_conventions', 'log_posterior_at_mode', NaN, X.MR.lp_swx1, 'swX1 mode under this likelihood (covid NaN, stochastic start)'};
R(end+1, :) = {'swx1_new_conventions', 'log_likelihood_at_mode', NaN, X.MR.ll_swx1, 'swX1 mode under this likelihood'};
R = [R; mode_rows('learn', X.ML.lp, X.ML.ll, X.ML.lpr, 'learning (lagged), 39 parameters')];
R(end+1, :) = {'learn', 'laplace', NaN, X.ML.laplace, sprintf('Laplace at the mode (Hessian PD %d)', X.HL.info.pd)};
for k = 1:numel(p)
    R(end+1, :) = {'learn', 'mhm', p(k), mhL(k), noteL}; %#ok<AGROW>
end
R = [R; mode_rows('learn_current', X.MC.lp, X.MC.ll, X.MC.lpr, 'beliefs.info current, mode from 2 starts')];
R(end+1, :) = {'learn_current', 'laplace', NaN, X.MC.laplace, 'Laplace at its own mode, 2 starts'};
R = [R; mode_rows('learn_calib', X.MK.lp, X.MK.ll, X.MK.lpr, 'priors centred on the calibration, mode from 1 start')];
R(end+1, :) = {'learn_calib', 'laplace', NaN, X.MK.laplace, 'Laplace at its own mode, 1 start; a different prior, so not a test of the model'};
R(end+1, :) = {'learn_fixed_beliefs', 'log_likelihood_at_mode', NaN, X.RB.c_ll, 'at the baseline learning mode, not re-optimised'};
R(end+1, :) = {'learn_fixed_beliefs', 'log_posterior_at_mode', NaN, X.RB.c_lp, 'at the baseline learning mode, not re-optimised'};
R(end+1, :) = {'learn_fixed_beliefs', 'laplace_baseline_hessian', NaN, X.RB.c_laplace_approx, ...
    'approximation: log posterior at the baseline mode with the baseline Hessian'};
R(end+1, :) = {'learn_freeze', 'log_likelihood_at_mode', NaN, X.RB.d_ll, 'at the baseline learning mode, not re-optimised'};
R(end+1, :) = {'learn_freeze', 'log_posterior_at_mode', NaN, X.RB.d_lp, 'at the baseline learning mode, not re-optimised'};
R(end+1, :) = {'learn_freeze', 'laplace_baseline_hessian', NaN, X.RB.d_laplace_approx, ...
    'approximation: log posterior at the baseline mode with the baseline Hessian'};
% log Bayes factors, like with like
l10 = log(10);
bf = {'learn_vs_re', X.ML.laplace - X.MR.laplace; 'learn_current_vs_re', X.MC.laplace - X.MR.laplace; ...
    'learn_vs_learn_current', X.ML.laplace - X.MC.laplace};
for k = 1:size(bf, 1)
    R(end+1, :) = {bf{k, 1}, 'laplace_logbf', NaN, bf{k, 2}, 'Laplace minus Laplace'}; %#ok<AGROW>
    R(end+1, :) = {bf{k, 1}, 'laplace_log10bf', NaN, bf{k, 2}/l10, 'Laplace minus Laplace, log10'}; %#ok<AGROW>
end
for k = 1:numel(p)
    R(end+1, :) = {'learn_vs_re', 'mhm_logbf', p(k), mhL(k) - mhR(k), 'MHM minus MHM at the same p'}; %#ok<AGROW>
    R(end+1, :) = {'learn_vs_re', 'mhm_log10bf', p(k), (mhL(k) - mhR(k))/l10, 'MHM minus MHM at the same p, log10'}; %#ok<AGROW>
end
write_long(fullfile(X.tdir, 'mdd.csv'), X.G, 'model', R(:, 1), 'method', R(:, 2), 'p', cell2mat(R(:, 3)), ...
    'value', cell2mat(R(:, 4)), 'note', R(:, 5));
meta = {'mhm_re_range', sprintf('%.4f %.4f', min(mhR), max(mhR)); 'mhm_learn_range', sprintf('%.4f %.4f', min(mhL), max(mhL))};
end


function meta = part_mdd_modes(X)
% mdd.csv at the modes: the Laplace approximation only (no draws), like with like. The variants
% (c) fixed initial beliefs and (d) 'freeze' are likelihoods at the baseline learning mode, not
% marginal likelihoods, and are written as such.
assert(abs(X.RB.ll_base - X.ML.ll) < 1e-8, 'mdd: learn/robust.mat was not computed at the current learning mode');
R = {};
R = [R; mode_rows('re', X.MR.lp, X.MR.ll, X.MR.lpr, 'RE, 36 parameters')];
R(end+1, :) = {'re', 'laplace', NaN, X.MR.laplace, sprintf('Laplace at the mode (Hessian PD %d)', X.MR.hess_info.pd)};
R(end+1, :) = {'swx1_new_conventions', 'log_posterior_at_mode', NaN, X.MR.lp_swx1, 'swX1 mode under this likelihood (covid NaN, stochastic start)'};
R(end+1, :) = {'swx1_new_conventions', 'log_likelihood_at_mode', NaN, X.MR.ll_swx1, 'swX1 mode under this likelihood'};
R = [R; mode_rows('learn', X.ML.lp, X.ML.ll, X.ML.lpr, 'learning (lagged), 39 parameters')];
R(end+1, :) = {'learn', 'laplace', NaN, X.ML.laplace, sprintf('Laplace at the mode (Hessian PD %d)', X.HL.info.pd)};
R = [R; mode_rows('learn_current', X.MC.lp, X.MC.ll, X.MC.lpr, sprintf('beliefs.info current, mode from %d starts', numel(X.MC.starts)))];
R(end+1, :) = {'learn_current', 'laplace', NaN, X.MC.laplace, sprintf('Laplace at its own mode (Hessian PD %d)', X.HC.info.pd)};
R = [R; mode_rows('learn_calib', X.MK.lp, X.MK.ll, X.MK.lpr, sprintf('priors centred on the calibration, mode from %d start(s)', numel(X.MK.starts)))];
R(end+1, :) = {'learn_calib', 'laplace', NaN, X.MK.laplace, 'Laplace at its own mode; a different prior, so not a test of the model'};
nb = 'at the baseline learning mode, not re-optimised: a likelihood, not a marginal likelihood';
for v = {{'learn_fixed_beliefs', X.RB.c_ll, X.RB.c_lp}, {'learn_freeze', X.RB.d_ll, X.RB.d_lp}}
    R(end+1, :) = {v{1}{1}, 'log_likelihood_at_baseline_mode', NaN, v{1}{2}, nb}; %#ok<AGROW>
    R(end+1, :) = {v{1}{1}, 'log_posterior_at_baseline_mode', NaN, v{1}{3}, nb}; %#ok<AGROW>
    R(end+1, :) = {v{1}{1}, 'log_likelihood_minus_baseline', NaN, v{1}{2} - X.ML.ll, ...
        'same parameters (the baseline learning mode), baseline log likelihood subtracted'}; %#ok<AGROW>
end
l10 = log(10);
bf = {'learn_vs_re', X.ML.laplace - X.MR.laplace; 'learn_current_vs_re', X.MC.laplace - X.MR.laplace; ...
    'learn_vs_learn_current', X.ML.laplace - X.MC.laplace};
for k = 1:size(bf, 1)
    R(end+1, :) = {bf{k, 1}, 'laplace_logbf', NaN, bf{k, 2}, 'Laplace minus Laplace'}; %#ok<AGROW>
    R(end+1, :) = {bf{k, 1}, 'laplace_log10bf', NaN, bf{k, 2}/l10, 'Laplace minus Laplace, log10'}; %#ok<AGROW>
end
write_long(fullfile(X.tdir, 'mdd.csv'), X.G, 'model', R(:, 1), 'method', R(:, 2), 'p', cell2mat(R(:, 3)), ...
    'value', cell2mat(R(:, 4)), 'note', R(:, 5));
meta = {'mdd_methods', 'laplace only (posterior modes)'; 'mdd_laplace_logbf_learn_vs_re', sprintf('%.4f', bf{1, 2})};
end


function R = mode_rows(model, lp, ll, lpr, note)
R = {model, 'log_posterior_at_mode', NaN, lp, note; model, 'log_likelihood_at_mode', NaN, ll, note; ...
    model, 'log_prior_at_mode', NaN, lpr, note};
end


% =============================================================================================
% prior_post_long.csv
% =============================================================================================
function meta = part_prior_post(X)
if X.modes
    meta = part_prior_post_modes(X);
    return
end
tab = X.pbL.tab;
names = [{'gain', 'omega', 'chi'}, X.movers];
ng = 201;
R = {};
for k = 1:numel(names)
    i = find(strcmp(tab.name, names{k}));
    xL = X.PL.X(:, i);
    hasR = i <= 36;
    lo = quantiles(xL, 0.001);
    hi = quantiles(xL, 0.999);
    if hasR
        xR = X.PR.X(:, i);
        lo = min(lo, quantiles(xR, 0.001));
        hi = max(hi, quantiles(xR, 0.999));
    end
    if tab.learn(i)
        % learning parameters (identification): the whole prior, 0.5% to 99.5%
        lo = min(lo, prior_quantile(tab, i, 0.005));
        hi = max(hi, prior_quantile(tab, i, 0.995));
    else
        % structural movers: the two posteriors, widened by their range on each side
        w = hi - lo;
        lo = lo - w;
        hi = hi + w;
    end
    lo = max(lo, tab.lb(i));
    hi = min(hi, tab.ub(i));
    g = linspace(lo, hi, ng)';
    pd = zeros(ng, 1);
    xx = X.ML.xm;
    for j = 1:ng
        xx(i) = g(j);
        [~, lpi] = hlest.prior_logpdf(tab, xx);
        pd(j) = exp(lpi(i));
    end
    R = [R; dens_rows(names{k}, 'prior', g, pd)]; %#ok<AGROW>
    R = [R; dens_rows(names{k}, 'learn', g, kde(xL, g, tab.lb(i), tab.ub(i)))]; %#ok<AGROW>
    if hasR
        R = [R; dens_rows(names{k}, 're', g, kde(xR, g, tab.lb(i), tab.ub(i)))]; %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'prior_post_long.csv'), X.G, 'param', R(:, 1), 'density', R(:, 2), ...
    'x', cell2mat(R(:, 3)), 'value', cell2mat(R(:, 4)));
meta = {'prior_post_params', strjoin(names, ' ')};
end


function meta = part_prior_post_modes(X)
% prior_post_long.csv at the modes: the prior density next to the Laplace approximation at each
% mode, the normal density with the mode as mean and the Hessian sd (not truncated at the bounds;
% densities re_laplace and learn_laplace). Grid: mode +- 4 Hessian sd of both models (and, for the
% learning parameters, the prior's 0.5%-99.5% range), cut at the bounds.
tab = X.pbL.tab;
names = [{'gain', 'omega', 'chi'}, X.movers];
ng = 201;
sdR = sqrt(diag(X.MR.Sigma));
sdL = sqrt(diag(X.HL.Sigma));
npdf = @(g, m, s) exp(-0.5*((g - m)/s).^2)/(s*sqrt(2*pi));
R = {};
for k = 1:numel(names)
    i = find(strcmp(tab.name, names{k}));
    hasR = i <= 36;
    lo = X.ML.xm(i) - 4*sdL(i);
    hi = X.ML.xm(i) + 4*sdL(i);
    if hasR
        lo = min(lo, X.MR.xm(i) - 4*sdR(i));
        hi = max(hi, X.MR.xm(i) + 4*sdR(i));
    end
    if tab.learn(i)
        lo = min(lo, prior_quantile(tab, i, 0.005));
        hi = max(hi, prior_quantile(tab, i, 0.995));
    end
    lo = max(lo, tab.lb(i));
    hi = min(hi, tab.ub(i));
    g = linspace(lo, hi, ng)';
    pd = zeros(ng, 1);
    xx = X.ML.xm;
    for j = 1:ng
        xx(i) = g(j);
        [~, lpi] = hlest.prior_logpdf(tab, xx);
        pd(j) = exp(lpi(i));
    end
    R = [R; dens_rows(names{k}, 'prior', g, pd)]; %#ok<AGROW>
    R = [R; dens_rows(names{k}, 'learn_laplace', g, npdf(g, X.ML.xm(i), sdL(i)))]; %#ok<AGROW>
    if hasR
        R = [R; dens_rows(names{k}, 're_laplace', g, npdf(g, X.MR.xm(i), sdR(i)))]; %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'prior_post_long.csv'), X.G, 'param', R(:, 1), 'density', R(:, 2), ...
    'x', cell2mat(R(:, 3)), 'value', cell2mat(R(:, 4)));
meta = {'prior_post_params', strjoin(names, ' '); ...
    'prior_post_kind', 'prior and the Laplace approximation N(mode, Hessian sd^2) at each mode'};
end


function R = dens_rows(nm, kind, g, v)
n = numel(g);
R = [repmat({nm}, n, 1), repmat({kind}, n, 1), num2cell(g(:)), num2cell(v(:))];
end


function f = kde(x, g, lb, ub)
% Gaussian kernel density, Silverman's bandwidth, reflected at finite bounds.
x = x(:);
if numel(x) > 50000
    x = x(round(linspace(1, numel(x), 50000)));
end
n = numel(x);
s = std(x);
iq = diff(quantiles(x, [0.25 0.75]));
h = 0.9*min(s, iq/1.34)*n^(-1/5);
if ~(h > 0)
    h = max(s, 1e-6)*n^(-1/5);
end
f = zeros(numel(g), 1);
c0 = 1/(n*h*sqrt(2*pi));
for j = 1:numel(g)
    z = (g(j) - x)/h;
    v = sum(exp(-0.5*z.^2));
    if isfinite(lb)
        v = v + sum(exp(-0.5*((g(j) - (2*lb - x))/h).^2));
    end
    if isfinite(ub)
        v = v + sum(exp(-0.5*((g(j) - (2*ub - x))/h).^2));
    end
    f(j) = c0*v;
end
f(g < lb | g > ub) = 0;
end


function x = prior_quantile(T, i, q)
a = T.h1(i);
b = T.h2(i);
switch T.shape(i)
    case 1
        x = T.p3(i) + (T.p4(i) - T.p3(i))*betaincinv(q, a, b);
    case 2
        x = T.p3(i) + b*gammaincinv(q, a);
    case 3
        x = a + b*sqrt(2)*erfinv(2*q - 1);
    case 4
        x = T.p3(i) + 1/sqrt((2/a)*gammaincinv(1 - q, b/2));
end
end


% =============================================================================================
% lpd_long.csv
% =============================================================================================
function meta = part_lpd(X)
if X.modes
    meta = part_lpd_modes(X);
    return
end
pbR = X.pbR;
il = pbR.ilike;
nT = pbR.nT;
[llR, oR] = hlest.loglik_re(pbR, X.MR.xm);
assert(abs(llR - X.MR.ll) < 1e-6, 'lpd: RE log likelihood at the mode %.8f differs from mode.mat %.8f', llR, X.MR.ll);
lR = oR.llt;
lL = X.ML.out.llt;
assert(abs(sum(lL(il:end)) - X.ML.ll) < 1e-6, 'lpd: stored learning l_t do not sum to the mode likelihood');
% learning path draws (post burn-in) and RE re-evaluations
nLd = numel(X.PL.paths);
LLt = zeros(nLd, nT);
for k = 1:nLd
    LLt(k, :) = double(X.PL.paths{k}.llt);
end
nRE = min(X.o.n_re, max(nLd, 500));
iR = unique(round(linspace(1, size(X.PR.X, 1), nRE)));
nRE = numel(iR);
RLt = zeros(nRE, nT);
bad = 0;
for k = 1:nRE
    [llk, ok] = hlest.loglik_re(pbR, X.PR.X(iR(k), :)');
    if ~isfinite(llk)
        bad = bad + 1;
        RLt(k, :) = NaN;
    else
        RLt(k, :) = ok.llt;
    end
end
rs = RandStream('mt19937ar', 'Seed', X.o.seed);
pr = randperm(rs, nRE);
cumD = zeros(nLd, nT - il + 1);
for k = 1:nLd
    j = pr(1 + mod(k - 1, nRE));
    cumD(k, :) = cumsum(LLt(k, il:end) - RLt(j, il:end));
end
cumD = cumD(all(isfinite(cumD), 2), :);
qd = quantiles(cumD, [0.05 0.5 0.95]);
dq = X.Q(il:end);
dm = lL(il:end) - lR(il:end);
R = {};
R = [R; ser_rows(dq, 'llt_re_mode', lR(il:end))];
R = [R; ser_rows(dq, 'llt_learn_mode', lL(il:end))];
R = [R; ser_rows(dq, 'llt_diff_mode', dm)];
R = [R; ser_rows(dq, 'cum_diff_mode', cumsum(dm))];
R = [R; ser_rows(dq, 'cum_diff_q05', qd(:, 1))];
R = [R; ser_rows(dq, 'cum_diff_q50', qd(:, 2))];
R = [R; ser_rows(dq, 'cum_diff_q95', qd(:, 3))];
R = [R; ser_rows(dq, 'llt_re_post_mean', mean(RLt(:, il:end), 1, 'omitnan'))];
R = [R; ser_rows(dq, 'llt_learn_post_mean', mean(LLt(:, il:end), 1))];
write_long(fullfile(X.tdir, 'lpd_long.csv'), X.G, 'date', R(:, 1), 'series', R(:, 2), 'value', cell2mat(R(:, 3)));
meta = {'lpd_learn_draws', sprintf('%d', size(cumD, 1)); 'lpd_re_draws', sprintf('%d', nRE); ...
    'lpd_re_failed', sprintf('%d', bad)};
end


function meta = part_lpd_modes(X)
% lpd_long.csv at the modes: l_t of each model, their difference and its cumulative sum (no band).
pbR = X.pbR;
il = pbR.ilike;
[llR, oR] = hlest.loglik_re(pbR, X.MR.xm);
assert(abs(llR - X.MR.ll) < 1e-6, 'lpd: RE log likelihood at the mode %.8f differs from mode.mat %.8f', llR, X.MR.ll);
lR = oR.llt;
lL = X.ML.out.llt;
assert(abs(sum(lL(il:end)) - X.ML.ll) < 1e-6, 'lpd: stored learning l_t do not sum to the mode likelihood');
dq = X.Q(il:end);
dm = lL(il:end) - lR(il:end);
R = {};
R = [R; ser_rows(dq, 'llt_re_mode', lR(il:end))];
R = [R; ser_rows(dq, 'llt_learn_mode', lL(il:end))];
R = [R; ser_rows(dq, 'llt_diff_mode', dm)];
R = [R; ser_rows(dq, 'cum_diff_mode', cumsum(dm))];
write_long(fullfile(X.tdir, 'lpd_long.csv'), X.G, 'date', R(:, 1), 'series', R(:, 2), 'value', cell2mat(R(:, 3)));
meta = {'lpd_check_re_mode', sprintf('%.3g', abs(llR - X.MR.ll)); 'lpd_total_diff_mode', sprintf('%.4f', sum(dm))};
end


function R = ser_rows(dq, name, v)
n = numel(dq);
R = [reshape(dq, [], 1), repmat({name}, n, 1), num2cell(double(v(:)))];
end


% =============================================================================================
% rmse.csv
% =============================================================================================
function meta = part_rmse(X)
pbR = X.pbR;
pbL = X.pbL;
[~, oR] = hlest.loglik_re(pbR, X.MR.xm, true);
vR = oR.F.v;
[llL, oL] = hlest.loglik_learn_pe(pbL, X.ML.xm, 'paths', true);
dChk = max(abs(oL.llt - X.ML.out.llt));
assert(dChk < 1e-9, 'rmse: loglik_learn_pe l_t differ from loglik_learn at the mode by %.3g', dChk);
assert(abs(llL - X.ML.ll) < 1e-6, 'rmse: learning likelihood at the mode');
vL = oL.v;
sc = pbR.spec.report.scale;
un = pbR.spec.report.units;
smp = {'1966Q1-2026Q2', 1966, 1, 2026, 2; '1966Q1-1983Q4', 1966, 1, 1983, 4; '1984Q1-2007Q4', 1984, 1, 2007, 4; ...
    '2008Q1-2019Q4', 2008, 1, 2019, 4; '2020Q4-2026Q2', 2020, 4, 2026, 2};
R = {};
for i = 1:numel(pbR.yl)
    v = pbR.yl{i};
    for s = 1:size(smp, 1)
        t1 = qidx(smp{s, 2}, smp{s, 3});
        t2 = qidx(smp{s, 4}, smp{s, 5});
        for mdl = {'re', 'learn'}
            if strcmp(mdl{1}, 're')
                e = vR(i, t1:t2);
            else
                e = vL(i, t1:t2);
            end
            e = e(isfinite(e))*sc.(v);
            R(end+1, :) = {mdl{1}, v, smp{s, 1}, sqrt(mean(e.^2)), numel(e), un.(v)}; %#ok<AGROW>
        end
    end
end
write_long(fullfile(X.tdir, 'rmse.csv'), X.G, 'model', R(:, 1), 'variable', R(:, 2), 'sample', R(:, 3), ...
    'rmse', cell2mat(R(:, 4)), 'n', cell2mat(R(:, 5)), 'units', R(:, 6));
meta = {'rmse_check_llt_pe_vs_learn', sprintf('%.3g', dChk)};
end


% =============================================================================================
% paths_long.csv
% =============================================================================================
function meta = part_paths(X)
if X.modes
    meta = part_paths_modes(X);
    return
end
pbL = X.pbL;
nT = pbL.nT;
t0 = pbL.t0;
Q = X.Q;
iC = find(strcmp(pbL.tab.name, 'constepinf'));
out = X.ML.out;
cm = X.ML.xm(iC);
R = {};
% mode
mv = struct('n2', 1 - out.n1, 'n2_model', 1 - out.n1m, 'alpha', out.phi(1, :), 'beta', out.phi(2, :), ...
    'pmean', 4*(out.phi(1, :)./(1 - out.phi(2, :)) + cm), 'fRE', 4*(out.fRE + cm), 'fBR', 4*(out.fBR + cm), ...
    'pinf_filtered', 4*(out.pinf + cm));
fn = fieldnames(mv);
for k = 1:numel(fn)
    R = [R; prow(Q(t0:nT), fn{k}, 'mode', 'value', mv.(fn{k})(t0:nT))]; %#ok<AGROW>
end
% posterior: stored paths of the post burn-in draws
nP = numel(X.PL.paths);
A = struct('n2', zeros(nP, nT), 'n2_model', zeros(nP, nT), 'alpha', zeros(nP, nT), 'beta', zeros(nP, nT), ...
    'pmean', zeros(nP, nT));
for k = 1:nP
    p = X.PL.paths{k};
    A.n2(k, :) = double(p.n2);
    A.n2_model(k, :) = 1 - double(p.n1m);
    A.alpha(k, :) = double(p.alpha);
    A.beta(k, :) = double(p.beta);
    A.pmean(k, :) = 4*(A.alpha(k, :)./(1 - A.beta(k, :)) + X.PL.ptheta(k, iC));
end
fa = fieldnames(A);
for k = 1:numel(fa)
    qv = quantiles(A.(fa{k})(:, t0:nT), [0.05 0.5 0.95]);
    R = [R; prow(Q(t0:nT), fa{k}, 'post', 'q05', qv(:, 1))]; %#ok<AGROW>
    R = [R; prow(Q(t0:nT), fa{k}, 'post', 'q50', qv(:, 2))]; %#ok<AGROW>
    R = [R; prow(Q(t0:nT), fa{k}, 'post', 'q95', qv(:, 3))]; %#ok<AGROW>
end
% f^RE, f^BR: re-evaluated at n_fx of the path draws (the chains do not store them)
nF = min(X.o.n_fx, nP);
iF = unique(round(linspace(1, nP, nF)));
nF = numel(iF);
FR = NaN(nF, nT);
FB = NaN(nF, nT);
dN2 = 0;
for k = 1:nF
    th = X.PL.ptheta(iF(k), :)';
    [ll, ok] = hlest.loglik_learn(pbL, th, 'paths', 'light');
    if ~isfinite(ll)
        continue
    end
    FR(k, :) = 4*(ok.fRE + th(iC));
    FB(k, :) = 4*(ok.fBR + th(iC));
    s = double(X.PL.paths{iF(k)}.n2);
    dd = abs(s(t0:nT) - (1 - ok.n1(t0:nT)));
    dN2 = max(dN2, max(dd(isfinite(dd))));
end
okF = all(isfinite(FR(:, t0:nT)), 2);
for nm = {'fRE', 'fBR'}
    if strcmp(nm{1}, 'fRE')
        M = FR(okF, t0:nT);
    else
        M = FB(okF, t0:nT);
    end
    qv = quantiles(M, [0.05 0.5 0.95]);
    R = [R; prow(Q(t0:nT), nm{1}, 'post', 'q05', qv(:, 1))]; %#ok<AGROW>
    R = [R; prow(Q(t0:nT), nm{1}, 'post', 'q50', qv(:, 2))]; %#ok<AGROW>
    R = [R; prow(Q(t0:nT), nm{1}, 'post', 'q95', qv(:, 3))]; %#ok<AGROW>
end
% data: inflation (GDP deflator, % annualised)
ipo = find(strcmp(pbL.yl, 'pinfobs'));
R = [R; prow(Q(1:nT), 'pinfobs', 'data', 'value', 4*pbL.Y(ipo, :))];
% calibrated engine history of a1_learn (results/summary_v3/learning_long.csv)
f = fullfile(X.c.project, 'results', 'summary_v3', 'learning_long.csv');
Tl = readtable(f, 'TextType', 'char', 'Delimiter', ',');
sel = strcmp(Tl.scenario, 'a1_learn') & strcmp(Tl.variable, 'pinf') & strcmp(Tl.stage, 'history');
map = {'n2', 'n2'; 'alpha_pinf', 'alpha'; 'beta_pinf', 'beta'; 'perceived_mean_report', 'pmean'};
for k = 1:size(map, 1)
    s = sel & strcmp(Tl.field, map{k, 1});
    R = [R; prow(Tl.date(s), map{k, 2}, 'calibrated', 'value', Tl.value(s))]; %#ok<AGROW>
end
write_long(fullfile(X.tdir, 'paths_long.csv'), X.G, 'date', R(:, 1), 'variable', R(:, 2), 'source', R(:, 3), ...
    'stat', R(:, 4), 'value', cell2mat(R(:, 5)));
meta = {'paths_post_draws', sprintf('%d', nP); 'paths_fx_draws', sprintf('%d', nnz(okF)); ...
    'paths_check_n2_stored_vs_recomputed', sprintf('%.3g', dN2)};
end


function meta = part_paths_modes(X)
% paths_long.csv at the learning mode (filtered paths stored in learn/mode.mat), the inflation data
% and the calibrated a1_learn history, including the two groups' forecasts f^RE and f^BR.
pbL = X.pbL;
nT = pbL.nT;
t0 = pbL.t0;
Q = X.Q;
iC = find(strcmp(pbL.tab.name, 'constepinf'));
out = X.ML.out;
cm = X.ML.xm(iC);
R = {};
mv = struct('n2', 1 - out.n1, 'n2_model', 1 - out.n1m, 'alpha', out.phi(1, :), 'beta', out.phi(2, :), ...
    'pmean', 4*(out.phi(1, :)./(1 - out.phi(2, :)) + cm), 'fRE', 4*(out.fRE + cm), 'fBR', 4*(out.fBR + cm), ...
    'pinf_filtered', 4*(out.pinf + cm));
fn = fieldnames(mv);
for k = 1:numel(fn)
    R = [R; prow(Q(t0:nT), fn{k}, 'mode', 'value', mv.(fn{k})(t0:nT))]; %#ok<AGROW>
end
ipo = find(strcmp(pbL.yl, 'pinfobs'));
R = [R; prow(Q(1:nT), 'pinfobs', 'data', 'value', 4*pbL.Y(ipo, :))];
% calibrated engine history of a1_learn (results/summary_v3/learning_long.csv), as part_paths
f = fullfile(X.c.project, 'results', 'summary_v3', 'learning_long.csv');
Tl = readtable(f, 'TextType', 'char', 'Delimiter', ',');
sel = strcmp(Tl.scenario, 'a1_learn') & strcmp(Tl.variable, 'pinf') & strcmp(Tl.stage, 'history');
map = {'n2', 'n2'; 'alpha_pinf', 'alpha'; 'beta_pinf', 'beta'; 'perceived_mean_report', 'pmean'};
for k = 1:size(map, 1)
    s = sel & strcmp(Tl.field, map{k, 1});
    R = [R; prow(Tl.date(s), map{k, 2}, 'calibrated', 'value', Tl.value(s))]; %#ok<AGROW>
end
% calibrated forecasts made in t, from the a1_learn run itself (results/a1_learn/learning.csv, model
% units): the same run as summary_v3 (n2 checked), annualised with the swX1 steady-state inflation
% (checked against the perceived mean of summary_v3)
sN = sel & strcmp(Tl.field, 'n2');
dH = Tl.date(sN);
Ta = readtable(fullfile(X.c.project, 'results', 'a1_learn', 'learning.csv'), 'TextType', 'char', 'Delimiter', ',');
getA = @(fld) Ta(strcmp(Ta.variable, 'pinf') & strcmp(Ta.field, fld), :);
An2 = getA('n2');
[ok, ia] = ismember(dH, An2.date);
assert(all(ok), 'paths: results/a1_learn/learning.csv lacks quarters of the calibrated history');
dN = max(abs(An2.value(ia) - Tl.value(sN)));
assert(dN < 1e-8, 'paths: results/a1_learn/learning.csv is not the run of summary_v3 (n2 differs by %.3g)', dN);
cs = X.MR.x_swx1(iC);
sA = sel & strcmp(Tl.field, 'alpha_pinf');
sB = sel & strcmp(Tl.field, 'beta_pinf');
sP = sel & strcmp(Tl.field, 'perceived_mean_report');
assert(isequal(Tl.date(sA), Tl.date(sB), Tl.date(sP)), 'paths: calibrated history dates');
cBack = Tl.value(sP)/4 - Tl.value(sA)./(1 - Tl.value(sB));
dC = abs(median(cBack) - cs);
assert(dC < 1e-4, 'paths: the perceived mean of summary_v3 implies constepinf %.6f, swX1 has %.6f', median(cBack), cs);
for fld = {'fRE', 'fBR'}
    Af = getA(fld{1});
    [okf, jf] = ismember(dH, Af.date);
    assert(all(okf), 'paths: %s missing in results/a1_learn/learning.csv', fld{1});
    R = [R; prow(dH, fld{1}, 'calibrated', 'value', 4*(Af.value(jf) + cs))]; %#ok<AGROW>
end
write_long(fullfile(X.tdir, 'paths_long.csv'), X.G, 'date', R(:, 1), 'variable', R(:, 2), 'source', R(:, 3), ...
    'stat', R(:, 4), 'value', cell2mat(R(:, 5)));
meta = {'paths_source', 'learning mode (learn/mode.mat, out)'; 'paths_calibrated_forecasts', ...
    sprintf('results/a1_learn/learning.csv (n2 = summary_v3 to %.2g; constepinf %.6f, implied %.6f)', dN, cs, median(cBack))};
end


function R = prow(dq, var, src, stat, v)
dq = reshape(cellstr(dq), [], 1);
n = numel(dq);
R = [dq, repmat({var}, n, 1), repmat({src}, n, 1), repmat({stat}, n, 1), num2cell(double(v(:)))];
end


% =============================================================================================
% irfs_long.csv
% =============================================================================================
function meta = part_irfs(X)
pbR = X.pbR;
pbL = X.pbL;
H = 20;
shocks = {'em', 'epinf'};
vars = {'pinfobs', 'dy', 'robs'};
units = 'pp, % annualised, deviation from steady state';
[ok, ssR] = hlest.solve_orig(pbR, hlest.theta_struct(pbR, X.MR.xm));
assert(ok, 'irfs: RE model at the RE mode');
A = hlest.alm_setup(pbL, X.ML.xm);
assert(A.ok, 'irfs: learning set-up at the mode (%s)', A.status);
out = X.ML.out;
cases = {};
cases(end+1, :) = {'re', ssR.Tb, ssR.Rb, ssR.Z, ssR.Omg, 1, NaN, NaN};
cases(end+1, :) = {'learn_all_re', A.ss.Tb, A.ss.Rb, A.ss.Z, A.ss.Omg, 1, NaN, NaN};
for q = {'2019Q4', '2022Q2'}
    t = find(strcmp(X.Q, q{1}));
    n1 = out.n1m(t);
    ph = out.phi(:, t - 1);
    [Tb, Rb, ~, fl] = hlest.qz_xb(A.Rd, n1, ph(1), ph(2));
    assert(fl == 1, 'irfs: ALM in force in %s has no unique stable solution', q{1});
    cases(end+1, :) = {['learn_' q{1}], Tb, Rb, A.ss.Z, A.ss.Omg, n1, ph(1), ph(2)}; %#ok<AGROW>
end
R = {};
for k = 1:size(cases, 1)
    [nm, Tb, Rb, Z, Omg] = cases{k, 1:5};
    for s = 1:numel(shocks)
        j = find(strcmp(pbL.el, shocks{s}));
        x = Rb(:, j)*sqrt(Omg(j, j));
        Y = zeros(numel(vars), H + 1);
        for h = 0:H
            for v = 1:numel(vars)
                iy = strcmp(pbL.yl, vars{v});
                Y(v, h + 1) = 4*(Z(iy, :)*x);
            end
            x = Tb*x;
        end
        for v = 1:numel(vars)
            R = [R; [repmat({nm}, H + 1, 1), repmat(shocks(s), H + 1, 1), repmat(vars(v), H + 1, 1), ...
                num2cell((0:H)'), num2cell(Y(v, :)'), repmat({units}, H + 1, 1)]]; %#ok<AGROW>
        end
    end
    R(end+1, :) = {nm, 'setting', 'n2_model', 0, 1 - cases{k, 6}, 'learners'' share in force'}; %#ok<AGROW>
    R(end+1, :) = {nm, 'setting', 'alpha', 0, cases{k, 7}, 'belief in force (end of the previous quarter)'}; %#ok<AGROW>
    R(end+1, :) = {nm, 'setting', 'beta', 0, cases{k, 8}, 'belief in force (end of the previous quarter)'}; %#ok<AGROW>
end
iem = strcmp(pbL.tab.name, 'em');
iep = strcmp(pbL.tab.name, 'epinf');
R(end+1, :) = {'re', 'setting', 'sd_em', 0, X.MR.xm(iem), 'one sd, % per quarter'};
R(end+1, :) = {'re', 'setting', 'sd_epinf', 0, X.MR.xm(iep), 'one sd'};
R(end+1, :) = {'learn', 'setting', 'sd_em', 0, X.ML.xm(iem), 'one sd, % per quarter'};
R(end+1, :) = {'learn', 'setting', 'sd_epinf', 0, X.ML.xm(iep), 'one sd'};
write_long(fullfile(X.tdir, 'irfs_long.csv'), X.G, 'model', R(:, 1), 'shock', R(:, 2), 'variable', R(:, 3), ...
    'h', cell2mat(R(:, 4)), 'value', cell2mat(R(:, 5)), 'units', R(:, 6));
meta = {'irfs_horizon', sprintf('%d', H)};
end


% =============================================================================================
% application 1 at the estimates
% =============================================================================================
function meta = part_app1(X)
c = X.c;
pkR = make_package(c, 're', X.MR.xm, X.pbR, X.MR);
pkL = make_package(c, 'learn', X.ML.xm(1:36), X.pbR, X.ML);
sdir = fullfile(c.est_dir, 'scenarios');
write_scenarios(sdir, X.ML);
addpath(sdir);
rehash;
rdir = fullfile(c.results, 'app1');
if exist(rdir, 'dir') ~= 7
    mkdir(rdir);
end
resR = hetlearn.run(e1_re(), 'save', true, 'results_dir', rdir, 'quiet', true);
resL = hetlearn.run(e1_learn(), 'save', true, 'results_dir', rdir, 'quiet', true);
resLR = hetlearn.run(e1_learn_re(), 'save', true, 'results_dir', rdir, 'quiet', true);
resLS = hetlearn.run(e1_learn_smoothed(), 'save', true, 'results_dir', rdir, 'quiet', true);
spec = hetlearn.load_spec(pkR);
sc = spec.report.scale;
pv = {'pinfobs', 'robs', 'dy', 'dc'};
Qd = qq(2018, 1):qq(2026, 2);
dq = dstr(Qd);
org = double(resR.dates.origin);
stg = repmat({'forecast'}, numel(Qd), 1);
stg(double(Qd) <= org + 1e-6) = {'history'};
R = {};
dbv = hetlearn.load_database(spec);
for v = 1:numel(pv)
    R = [R; arow('e1_re', 'estimated', pv{v}, dq, stg, resR.paths.(pv{v})(Qd)*sc.(pv{v}))]; %#ok<AGROW>
    R = [R; arow('e1_learn', 'estimated', pv{v}, dq, stg, resL.paths.(pv{v})(Qd)*sc.(pv{v}))]; %#ok<AGROW>
    R = [R; arow('e1_learn_re', 'estimated', pv{v}, dq, stg, resLR.paths.(pv{v})(Qd)*sc.(pv{v}))]; %#ok<AGROW>
    R = [R; arow('e1_learn_smoothed', 'estimated', pv{v}, dq, stg, resLS.paths.(pv{v})(Qd)*sc.(pv{v}))]; %#ok<AGROW>
    R = [R; arow('data', 'data', pv{v}, dq, repmat({'history'}, numel(Qd), 1), dbv.(pv{v})(Qd)*sc.(pv{v}))]; %#ok<AGROW>
end
cmL = X.ML.xm(strcmp(X.pbL.tab.name, 'constepinf'));
for rr = {{'e1_learn', resL}, {'e1_learn_smoothed', resLS}}
    Lg = rr{1}{2}.learning.pinf;
    R = [R; arow(rr{1}{1}, 'estimated', 'n2', dq, stg, Lg.n2(Qd))]; %#ok<AGROW>
    R = [R; arow(rr{1}{1}, 'estimated', 'n2_model', dq, stg, 1 - Lg.n1_model(Qd))]; %#ok<AGROW>
    % forecasts of pinf made in t (annualised level: 4 (f + constepinf at the learning mode))
    R = [R; arow(rr{1}{1}, 'estimated', 'fRE', dq, stg, 4*(Lg.fRE(Qd) + cmL))]; %#ok<AGROW>
    R = [R; arow(rr{1}{1}, 'estimated', 'fBR', dq, stg, 4*(Lg.fBR(Qd) + cmL))]; %#ok<AGROW>
end
% calibrated a1 (results/summary_v3)
S = fullfile(c.project, 'results', 'summary_v3');
Tp = readtable(fullfile(S, 'paths_long.csv'), 'TextType', 'char', 'Delimiter', ',');
for id = {'a1_re', 'a1_learn'}
    for v = 1:numel(pv)
        s = strcmp(Tp.scenario, id{1}) & strcmp(Tp.variable, pv{v}) & ismember(Tp.date, dq);
        R = [R; arow(id{1}, 'calibrated', pv{v}, Tp.date(s), Tp.stage(s), Tp.value(s))]; %#ok<AGROW>
    end
end
Tl = readtable(fullfile(S, 'learning_long.csv'), 'TextType', 'char', 'Delimiter', ',');
for fld = {'n2', 'n2_model'}
    s = strcmp(Tl.scenario, 'a1_learn') & strcmp(Tl.variable, 'pinf') & strcmp(Tl.field, fld{1}) & ismember(Tl.date, dq);
    R = [R; arow('a1_learn', 'calibrated', fld{1}, Tl.date(s), Tl.stage(s), Tl.value(s))]; %#ok<AGROW>
end
% facility events of the learning run, as rows with variable events_<stage>_<type> (date column:
% the event dates; the inversion's history stage is called 'inversion' in res.events)
for rr = {resL, resLS}
    r = rr{1};
    for st = {'history', 'forecast'}
        stIn = st;
        if strcmp(st{1}, 'history')
            stIn = {'history', 'inversion'};
        end
        for ty = {'projection_plm', 'projection_alm', 'projection_alm_shares'}
            nE = 0;
            dE = '';
            if ~isempty(r.events)
                e = strcmp(r.events.type, ty{1}) & ismember(r.events.stage, stIn);
                nE = nnz(e);
                dE = strjoin(sort(cellstr(r.events.date(e))), ' ');
            end
            R(end+1, :) = {r.cfg.id, 'estimated', ['events_' st{1} '_' ty{1}], dE, st{1}, nE}; %#ok<AGROW>
        end
    end
end
write_long(fullfile(X.tdir, 'app1_long.csv'), X.G, 'scenario', R(:, 1), 'source', R(:, 2), 'variable', R(:, 3), ...
    'date', R(:, 4), 'stage', R(:, 5), 'value', cell2mat(R(:, 6)));
hz = qq(2022, 3):qq(2026, 2);
meta = {'app1_avg_pinf_e1_re', sprintf('%.4f', mean(resR.paths.pinfobs(hz))*sc.pinfobs); ...
    'app1_avg_pinf_e1_learn', sprintf('%.4f', mean(resL.paths.pinfobs(hz))*sc.pinfobs); ...
    'app1_avg_pinf_e1_learn_re', sprintf('%.4f', mean(resLR.paths.pinfobs(hz))*sc.pinfobs); ...
    'app1_avg_pinf_e1_learn_smoothed', sprintf('%.4f', mean(resLS.paths.pinfobs(hz))*sc.pinfobs); ...
    'app1_results', rdir; 'app1_packages', [pkR ' ' pkL]};
end


function R = arow(id, src, var, dq, stg, v)
dq = reshape(cellstr(dq), [], 1);
n = numel(dq);
R = [repmat({id}, n, 1), repmat({src}, n, 1), repmat({var}, n, 1), dq, reshape(cellstr(stg), [], 1), num2cell(double(v(:)))];
end


function dst = make_package(c, kind, xs, pbR, M)
% estimation/models/sw07_est_<kind>: a copy of models/sw07 whose params function returns the mode.
name = ['sw07_est_' kind];
dst = fullfile(c.est_dir, 'models', name);
src = fullfile(c.project, 'models', 'sw07');
if exist(fullfile(dst, 'data'), 'dir') ~= 7
    mkdir(fullfile(dst, 'data'));
end
copyfile(fullfile(src, 'sw07.model'), fullfile(dst, 'sw07.model'), 'f');
copyfile(fullfile(src, 'data', 'sw07_database.csv'), fullfile(dst, 'data', 'sw07_database.csv'), 'f');
copyfile(fullfile(src, 'data', 'sw07_database.mat'), fullfile(dst, 'data', 'sw07_database.mat'), 'f');
txt = fileread(fullfile(src, 'model_spec.m'));
what = ternary(strcmp(kind, 're'), 'RE re-estimate', 'learning estimate (a1_learn)');
old = {'% MODEL_SPEC  Package contract for the re-estimated Smets-Wouters (2007) model.', ...
    'spec.name = ''sw07'';', 'spec.params = ''sw07_params'';'};
new = {sprintf(['%% MODEL_SPEC  sw07 at the posterior mode of the %s of estimation/ (generated by\n' ...
    '%% est_06_post from results/estimation/%s/mode.mat; do not edit by hand). Everything else\n' ...
    '%% is models/sw07/model_spec.m.'], what, ternary(strcmp(kind, 're'), 're', 'learn')), ...
    sprintf('spec.name = ''%s'';', name), sprintf('spec.params = ''%s_params'';', name)};
for k = 1:numel(old)
    if ~contains(txt, old{k})
        error('est_06_post:package', 'models/sw07/model_spec.m has changed: line not found: %s', old{k});
    end
    txt = strrep(txt, old{k}, new{k});
end
write_text(fullfile(dst, 'model_spec.m'), txt);
P = pbR.Pbase;
tg = pbR.tab.target;
L = {sprintf('function P = %s_params()', name), ...
    sprintf('%% %s_PARAMS  Posterior mode of the %s (estimation/, 1966Q1-2026Q2).', upper(name), what), ...
    '%', ...
    sprintf('%% Generated by est_06_post from results/estimation/%s/mode.mat (created %s); do not edit.', ...
    ternary(strcmp(kind, 're'), 're', 'learn'), M.created), ...
    sprintf('%% Likelihood 1966Q1-2026Q2 (presample 1965), covid quarters 2020Q1-Q3 missing, stochastic'), ...
    sprintf('%% initialisation; log posterior at the mode %.4f, log likelihood %.4f.', M.lp, M.ll), ...
    '% Fixed as in swX1: ctou, clandaw, cg, curvp, curvw.', '', 'P = struct();', '', '% fixed parameters'};
fx = {'ctou', 'clandaw', 'cg', 'curvp', 'curvw'};
for k = 1:numel(fx)
    L{end+1} = sprintf('P.%s = %.17g;', fx{k}, P.(fx{k})); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '% estimated parameters (posterior mode)';
for k = 8:36
    L{end+1} = sprintf('P.%s = %.17g;', tg{k}, xs(k)); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = '% shock standard deviations (posterior mode)';
for k = 1:7
    L{end+1} = sprintf('P.%s = %.17g;', tg{k}, xs(k)); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = 'end';
write_text(fullfile(dst, [name '_params.m']), strjoin(L, newline));
end


function write_scenarios(sdir, ML)
if exist(sdir, 'dir') ~= 7
    mkdir(sdir);
end
g = ML.xm(37);
om = ML.xm(38);
chi = ML.xm(39);
E1 = {'function cfg = e1_re()', ...
    '%E1_RE  Application 1 at the RE estimate: forecast from the 2022Q2 peak, rational expectations.', ...
    '%', ...
    '%   cfg = e1_re()', ...
    '%', ...
    '%   As scenarios/sw07/app1_peak/a1_re.m, with the model package estimation/models/sw07_est_re', ...
    '%   (sw07 at the posterior mode of the RE re-estimation, 1966Q1-2026Q2, covid quarters', ...
    '%   missing). Generated by est_06_post; do not edit by hand. Run with the estimation''s', ...
    '%   toolbox on the path (setup_est) and estimation/scenarios added: res = hetlearn.run(e1_re());', ...
    '', ...
    'cfg = a1_re();', ...
    'cfg.id = ''e1_re'';', ...
    'cfg.title = ''App 1 at the RE estimate: forecast from the 2022Q2 peak, rational expectations'';', ...
    'cfg.description = ''As a1_re, at the posterior mode of the RE re-estimation (estimation/).'';', ...
    'cfg.model = fullfile(fileparts(fileparts(mfilename(''fullpath''))), ''models'', ''sw07_est_re'');', ...
    'end'};
E2 = {'function cfg = e1_learn()', ...
    '%E1_LEARN  Application 1 at the learning estimate: forecast from the 2022Q2 peak, learning on inflation.', ...
    '%', ...
    '%   cfg = e1_learn()', ...
    '%', ...
    '%   As scenarios/sw07/app1_peak/a1_learn.m, with the model package estimation/models/sw07_est_learn', ...
    '%   (the 36 SW07 parameters at the learning posterior mode), the estimated gain, memory and', ...
    '%   intensity of choice, and history.mode = ''inversion'', so the history (beliefs, shares,', ...
    '%   states) comes from the learning model itself and not from the RE smoother.', ...
    sprintf('%%   Values: results/estimation/learn/mode.mat (%s). Generated by est_06_post; do not edit.', ML.created), ...
    '', ...
    'cfg = a1_learn();', ...
    'cfg.id = ''e1_learn'';', ...
    'cfg.title = ''App 1 at the learning estimate: forecast from the 2022Q2 peak, learning on inflation'';', ...
    'cfg.description = ''As a1_learn, at the posterior mode of the learning estimation, history by inversion.'';', ...
    'cfg.model = fullfile(fileparts(fileparts(mfilename(''fullpath''))), ''models'', ''sw07_est_learn'');', ...
    sprintf('cfg.gain.value = %.17g;               %% posterior mode', g), ...
    sprintf('cfg.switching.memory = %.17g;         %% posterior mode', om), ...
    sprintf('cfg.switching.intensity = %.17g;      %% posterior mode', chi), ...
    'cfg.history.mode = ''inversion'';', ...
    'cfg.compare_with = {};', ...
    'end'};
E3 = {'function cfg = e1_learn_re()', ...
    '%E1_LEARN_RE  Application 1 at the learning estimate''s SW07 parameters with every agent rational.', ...
    '%', ...
    '%   cfg = e1_learn_re()', ...
    '%', ...
    '%   As scenarios/sw07/app1_peak/a1_re.m, with the model package estimation/models/sw07_est_learn.', ...
    '%   Compared with e1_learn it isolates the effect of learning at the learning estimate; compared', ...
    '%   with e1_re, the effect of the different SW07 parameters. Generated by est_06_post; do not edit.', ...
    '', ...
    'cfg = a1_re();', ...
    'cfg.id = ''e1_learn_re'';', ...
    'cfg.title = ''App 1 at the learning estimate, every agent rational'';', ...
    'cfg.description = ''As a1_re, with the SW07 parameters at the posterior mode of the learning estimation.'';', ...
    'cfg.model = fullfile(fileparts(fileparts(mfilename(''fullpath''))), ''models'', ''sw07_est_learn'');', ...
    'end'};
write_text(fullfile(sdir, 'e1_re.m'), strjoin(E1, newline));
E4 = {'function cfg = e1_learn_smoothed()', ...
    '%E1_LEARN_SMOOTHED  As e1_learn, with the history learned on the RE-smoothed states (history.mode = ''re_smoother'').', ...
    '%', ...
    '%   cfg = e1_learn_smoothed()', ...
    '%', ...
    '%   The history method of the calibrated a1_learn. Compared with e1_learn_re it isolates the effect of', ...
    '%   learning with the same history method; compared with e1_learn, the effect of the history method.', ...
    '%   Generated by est_06_post; do not edit.', ...
    '', ...
    'cfg = e1_learn();', ...
    'cfg.id = ''e1_learn_smoothed'';', ...
    'cfg.title = ''App 1 at the learning estimate, history on the RE-smoothed states'';', ...
    'cfg.description = ''As e1_learn, with history.mode = re_smoother (the method of the calibrated a1_learn).'';', ...
    'cfg.history.mode = ''re_smoother'';', ...
    'end'};
write_text(fullfile(sdir, 'e1_learn_re.m'), strjoin(E3, newline));
write_text(fullfile(sdir, 'e1_learn_smoothed.m'), strjoin(E4, newline));
write_text(fullfile(sdir, 'e1_learn.m'), strjoin(E2, newline));
end


% =============================================================================================
% application 1 consistent with the likelihood (est_06b_app1_post)
% =============================================================================================
function meta = part_app1_post(X, mode)
if X.modes
    S = est_06b_app1_post('modes');
    T = S.post.summary;
    meta = {};
    for k = 1:height(T)
        meta(end+1, :) = {['app1_post_avg_pinf_' T.model{k}], sprintf(['%.4f %.4f [%.4f %.4f] (mode, median [p05 p95]; ' ...
            '%d draws)'], T.avg_inflation_mode(k), T.avg_inflation_median(k), T.avg_inflation_p05(k), ...
            T.avg_inflation_p95(k), T.n_draws(k))}; %#ok<AGROW>
    end
    il = strcmp(T.model, 'learn');
    meta(end+1, :) = {'app1_post_n2_origin_learn', sprintf('%.4f (mode)', T.n2_origin_mode(il))};
    sn = S.sens;
    meta(end+1, :) = {'share_sensitivity_n2_2022Q2', strjoin(cellfun(@(v, x) sprintf('%s %.3f', v, x), sn.variant, ...
        num2cell(sn.n2_2022Q2), 'UniformOutput', false), '; ')};
    return
end
S = est_06b_app1_post(mode, 'draws', X.o.draws, 'max_blocks', X.o.max_blocks, 'min_age_s', X.o.min_age_s);
T = S.post.summary;
meta = {};
for k = 1:height(T)
    m = T.model{k};
    meta(end+1, :) = {['app1_post_avg_pinf_' m], sprintf('%.4f %.4f [%.4f %.4f] (mode, median [p05 p95])', ...
        T.avg_inflation_mode(k), T.avg_inflation_median(k), T.avg_inflation_p05(k), T.avg_inflation_p95(k))}; %#ok<AGROW>
end
il = strcmp(T.model, 'learn');
meta(end+1, :) = {'app1_post_n2_origin_learn', sprintf('%.4f %.4f [%.4f %.4f] (mode, median [p05 p95])', T.n2_origin_mode(il), ...
    T.n2_origin_median(il), T.n2_origin_p05(il), T.n2_origin_p95(il))};
meta(end+1, :) = {'app1_post_draws', sprintf('%d re, %d learn (%d and %d failed)', T.n_draws(~il), T.n_draws(il), ...
    T.n_failed(~il), T.n_failed(il))};
sn = S.sens;
meta(end+1, :) = {'share_sensitivity_n2_2022Q2', strjoin(cellfun(@(v, x) sprintf('%s %.3f', v, x), sn.variant, ...
    num2cell(sn.n2_2022Q2), 'UniformOutput', false), '; ')};
end


% =============================================================================================
% diagnostics.csv
% =============================================================================================
function meta = part_diag(X)
if X.modes
    meta = part_diag_modes(X);
    return
end
R = {};
for mdl = {'re', 'learn'}
    if strcmp(mdl{1}, 're')
        P = X.PR; S = X.RE; names = X.pbR.tab.name;
    else
        P = X.PL; S = X.LE; names = X.pbL.tab.name;
    end
    for k = 1:numel(S)
        R(end+1, :) = {mdl{1}, S(k).name, '', 'draws', P.n(k), ''}; %#ok<AGROW>
        R(end+1, :) = {mdl{1}, S(k).name, '', 'acceptance', P.acc(k), ''}; %#ok<AGROW>
    end
    R(end+1, :) = {mdl{1}, 'all', '', 'chains', numel(S), ''}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'draws_shortest_chain', P.n_diag, ''}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'burn_in_diag', P.burn_diag, sprintf('first %.0f%% of the shortest chain', 100*P.burn)}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'post_draws_pooled', size(P.X, 1), sprintf('every chain after its first %.0f%%', 100*P.burn)}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'burn_share', P.burn, ternary(strcmp(mdl{1}, 'learn'), X.labL, 're/chains')}; %#ok<AGROW>
    [rmx, irx] = max(P.diag.rhat);
    [emn, ien] = min(P.diag.ess_bulk);
    R(end+1, :) = {mdl{1}, 'all', '', 'rhat_max', rmx, names{irx}}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'ess_min', emn, names{ien}}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'n_rhat_lt_1.1', nnz(P.diag.rhat < 1.1), ''}; %#ok<AGROW>
    R(end+1, :) = {mdl{1}, 'all', '', 'n_ess_gt_100', nnz(P.diag.ess_bulk > 100), ''}; %#ok<AGROW>
    for i = 1:numel(names)
        R(end+1, :) = {mdl{1}, 'all', names{i}, 'rhat', P.diag.rhat(i), ''}; %#ok<AGROW>
        R(end+1, :) = {mdl{1}, 'all', names{i}, 'ess_bulk', P.diag.ess_bulk(i), ''}; %#ok<AGROW>
    end
end
% facility events: share of post burn-in learning draws whose state has each event type
ev = X.PL.EV;
tys = {'plm', 'alm', 'alm_shares'};
for j = 1:3
    R(end+1, :) = {'learn', 'all', '', ['share_draws_' tys{j}], mean(ev(:, j) > 0), 'post burn-in draws, pooled'}; %#ok<AGROW>
    R(end+1, :) = {'learn', 'all', '', ['mean_events_' tys{j}], mean(ev(:, j)), 'per draw'}; %#ok<AGROW>
end
out = X.ML.out;
evm = out.events;
txt = {};
for q = 1:size(evm, 2)
    txt{end+1} = sprintf('%s %s', X.Q{evm(1, q)}, tys{min(evm(2, q), 3)}); %#ok<AGROW>
end
R(end+1, :) = {'learn', 'mode', '', 'mode_events_plm', out.ev_plm, strjoin(txt, '; ')};
R(end+1, :) = {'learn', 'mode', '', 'mode_events_alm', out.ev_alm, ''};
R(end+1, :) = {'learn', 'mode', '', 'mode_events_alm_shares', out.ev_keep, ''};
for v = {'MC', 'MK'}
    Mv = X.(v{1});
    tv = {};
    for q = 1:size(Mv.out.events, 2)
        tv{end+1} = sprintf('%s %s', X.Q{Mv.out.events(1, q)}, tys{min(Mv.out.events(2, q), 3)}); %#ok<AGROW>
    end
    R(end+1, :) = {['learn_' Mv.variant], 'mode', '', 'mode_events_plm', Mv.out.ev_plm, strjoin(tv, '; ')}; %#ok<AGROW>
    R(end+1, :) = {['learn_' Mv.variant], 'mode', '', 'mode_starts', numel(Mv.starts), ''}; %#ok<AGROW>
end
R(end+1, :) = {'learn', 'mode', '', 'mode_starts', numel(X.ML.starts), sprintf('best start %d', X.ML.best_start)};
R(end+1, :) = {'learn', 'mode', '', 'hessian_pd', double(X.HL.info.pd), sprintf('min eigenvalue %.4g', X.HL.info.min_eig)};
R(end+1, :) = {'re', 'mode', '', 'hessian_pd', double(X.MR.hess_info.pd), sprintf('min eigenvalue %.4g', X.MR.hess_info.min_eig)};
% go/no-go (est_gonogo), if it has been run
gf = fullfile(X.c.results, 'learn', 'gonogo.txt');
if exist(gf, 'file') == 2
    gt = fileread(gf);
    dec = regexp(gt, 'DECISION: ([\w-]+)', 'tokens', 'once');
    hd = regexp(gt, 'est_gonogo\(''learn''\) ([\d\- :]+)', 'tokens', 'once');
    nd = regexp(gt, '(\d+) chains, (\d+) draws each used', 'tokens', 'once');
    R(end+1, :) = {'learn', 'gonogo', '', 'decision', NaN, ternary(isempty(dec), 'n/a', dec{1})};
    R(end+1, :) = {'learn', 'gonogo', '', 'created', NaN, ternary(isempty(hd), '', strtrim(hd{1}))};
    if ~isempty(nd)
        R(end+1, :) = {'learn', 'gonogo', '', 'draws_per_chain', str2double(nd{2}), sprintf('%s chains', nd{1})};
    end
end
% the main session's decision on the go/no-go result (learn/gonogo_override.txt), if any
gfo = fullfile(X.c.results, 'learn', 'gonogo_override.txt');
if exist(gfo, 'file') == 2
    kvo = regexp(fileread(gfo), '(\w+)\s*=\s*([^\n\r]*)', 'tokens');
    for q = 1:numel(kvo)
        R(end+1, :) = {'learn', 'gonogo_override', '', kvo{q}{1}, NaN, strtrim(kvo{q}{2})}; %#ok<AGROW>
    end
end
% est_gonogo2 (stage 1 and stage 2), if it has been run
gf2 = fullfile(X.c.results, 'learn', 'gonogo2.txt');
if exist(gf2, 'file') == 2
    gt2 = fileread(gf2);
    hd2 = regexp(gt2, 'est_gonogo2\(''\w+''\) ([\d\- :]+)', 'tokens', 'once');
    R(end+1, :) = {'learn', 'gonogo2', '', 'created', NaN, ternary(isempty(hd2), '', strtrim(hd2{1}))};
    for key = {'STAGE1 RULE', 'STAGE1 CONVERGED', 'STAGE 2', 'STAGE2 RULE', 'STAGE2 CONVERGED'}
        tk = regexp(gt2, [key{1} ': ([^\n\r]*)'], 'tokens', 'once');
        if ~isempty(tk)
            R(end+1, :) = {'learn', 'gonogo2', '', lower(strrep(key{1}, ' ', '_')), NaN, strtrim(tk{1})}; %#ok<AGROW>
        end
    end
    sh = regexp(gt2, '== STAGE(\d): [^\n\r]*[\r\n]+(\d+) chains \([^)]*\), (\d+) draws each used', 'tokens');
    for q = 1:numel(sh)
        R(end+1, :) = {'learn', 'gonogo2', '', sprintf('stage%s_draws_per_chain', sh{q}{1}), str2double(sh{q}{3}), ...
            sprintf('%s chains', sh{q}{2})}; %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'diagnostics.csv'), X.G, 'model', R(:, 1), 'chain', R(:, 2), 'parameter', R(:, 3), ...
    'metric', R(:, 4), 'value', cell2mat(R(:, 5)), 'text', R(:, 6));
meta = {'diag_learn_rhat_max', sprintf('%.4f', max(X.PL.diag.rhat)); 'diag_learn_ess_min', sprintf('%.1f', min(X.PL.diag.ess_bulk))};
end


function meta = part_diag_modes(X)
% diagnostics.csv at the modes: mode searches (starts, how many reached the mode), Hessians,
% facility events at the modes, the progress of every chain (progress.txt and the list of its
% block files; no chain file is opened) and the rows of learn/mcmc_paused.txt.
R = {};
tys = {'plm', 'alm', 'alm_shares'};
% RE: one search (est_01_mode_re)
R(end+1, :) = {'re', 'mode', '', 'mode_starts', 1, sprintf(['csminwel from the swX1 mode, then a restart from its ' ...
    'result (%d + %d iterations, return codes %d and %d)'], X.MR.iterations, X.MR.retcodes)};
R(end+1, :) = {'re', 'mode', '', 'mode_starts_reached', 1, 'one search'};
R(end+1, :) = {'re', 'mode', '', 'hessian_pd', double(X.MR.hess_info.pd), sprintf('min eigenvalue %.4g', X.MR.hess_info.min_eig)};
% learning model and its two re-estimated variants (est_03_mode_learn 'full' and 'pick')
for v = {{'learn', 'ML', 'HL'}, {'learn_current', 'MC', 'HC'}, {'learn_calib', 'MK', 'HK'}}
    nm = v{1}{1};
    M = X.(v{1}{2});
    H = X.(v{1}{3});
    sd = sqrt(diag(H.Sigma));
    st = M.starts;
    gap = arrayfun(@(s) M.lp - s.lp, st);
    dx = arrayfun(@(s) max(abs(s.x(:) - M.xm(:))./sd), st);
    hit = abs(gap) < 0.01;
    ks = strjoin(arrayfun(@(s) sprintf('%d', s.k), st, 'UniformOutput', false), ', ');
    R(end+1, :) = {nm, 'mode', '', 'mode_starts', numel(st), sprintf('starts %s; best start %d', ks, M.best_start)}; %#ok<AGROW>
    R(end+1, :) = {nm, 'mode', '', 'mode_starts_reached', nnz(hit), sprintf(['%d of %d starts within 0.01 of the ' ...
        'best log posterior; largest gap %.2g, largest parameter difference %.2g Hessian sd'], nnz(hit), numel(st), ...
        max(abs(gap)), max(dx))}; %#ok<AGROW>
    R(end+1, :) = {nm, 'mode', '', 'hessian_pd', double(H.info.pd), sprintf('min eigenvalue %.4g', H.info.min_eig)}; %#ok<AGROW>
    evm = M.out.events;
    txt = {};
    for q = 1:size(evm, 2)
        txt{end+1} = sprintf('%s %s', X.Q{evm(1, q)}, tys{min(evm(2, q), 3)}); %#ok<AGROW>
    end
    R(end+1, :) = {nm, 'mode', '', 'mode_events_plm', M.out.ev_plm, strjoin(txt, '; ')}; %#ok<AGROW>
    R(end+1, :) = {nm, 'mode', '', 'mode_events_alm', M.out.ev_alm, ''}; %#ok<AGROW>
    R(end+1, :) = {nm, 'mode', '', 'mode_events_alm_shares', M.out.ev_keep, ''}; %#ok<AGROW>
end
% variants (c) and (d) at the baseline mode (learn/robust.mat)
for v = {{'learn_fixed_beliefs', X.RB.c_events}, {'learn_freeze', X.RB.d_events}}
    [n, txt] = sig_text(v{1}{2}, X.Q, tys);
    R(end+1, :) = {v{1}{1}, 'baseline_mode', '', 'events', n, txt}; %#ok<AGROW>
end
% the chains: progress only (progress.txt and the number of block files)
sets = {'re', 're', fullfile(X.c.results, 're', 'chains'); 'learn', 'stage1', fullfile(X.c.results, 'learn', 'chains'); ...
    'learn', 'stage2', fullfile(X.c.results, 'learn', 'chains2')};
for s = 1:size(sets, 1)
    dd = dir(fullfile(sets{s, 3}, 'chain_*'));
    dd = dd([dd.isdir]);
    for k = 1:numel(dd)
        cdir = fullfile(dd(k).folder, dd(k).name);
        P = progress_kv(cdir);
        nb = numel(dir(fullfile(cdir, 'block_*.mat')));
        R(end+1, :) = {sets{s, 1}, dd(k).name, '', [sets{s, 2} '_draws_in_blocks'], nb*X.c.block, ...
            sprintf('of %s; progress.txt: %s draws, status %s, updated %s', P.ndraws, P.draws_done, P.status, P.updated)}; %#ok<AGROW>
        R(end+1, :) = {sets{s, 1}, dd(k).name, '', [sets{s, 2} '_ndraws'], str2double(P.ndraws), 'target'}; %#ok<AGROW>
    end
end
% the pause (learn/mcmc_paused.txt, key = value lines written by the main session)
f = fullfile(X.c.results, 'learn', 'mcmc_paused.txt');
if exist(f, 'file') == 2
    kv = regexp(fileread(f), '(\w+)\s*=\s*([^\n\r]*)', 'tokens');
    for q = 1:numel(kv)
        R(end+1, :) = {'learn', 'mcmc_paused', '', kv{q}{1}, NaN, strtrim(kv{q}{2})}; %#ok<AGROW>
    end
end
write_long(fullfile(X.tdir, 'diagnostics.csv'), X.G, 'model', R(:, 1), 'chain', R(:, 2), 'parameter', R(:, 3), ...
    'metric', R(:, 4), 'value', cell2mat(R(:, 5)), 'text', R(:, 6));
meta = {'diag_kind', 'modes: mode searches, Hessians, facility events at the modes, chain progress (MCMC paused)'};
end


function [n, txt] = sig_text(sig, Q, tys)
% '229.1;230.1;' (quarter index . event type) -> 2 and '2022Q1 plm; 2022Q2 plm'
tk = regexp(sig, '(\d+)\.(\d+)', 'tokens');
n = numel(tk);
c = cell(1, n);
for q = 1:n
    c{q} = sprintf('%s %s', Q{str2double(tk{q}{1})}, tys{min(str2double(tk{q}{2}), 3)});
end
txt = strjoin(c, '; ');
end


function P = progress_kv(cdir)
% The key = value lines of a chain's progress.txt (strings; '' where missing).
P = struct('ndraws', '', 'draws_done', '', 'status', '', 'updated', '');
f = fullfile(cdir, 'progress.txt');
if exist(f, 'file') ~= 2
    return
end
try
    txt = fileread(f);
catch
    return
end
for k = fieldnames(P)'
    t = regexp(txt, [k{1} ' = ([^\n\r]*)'], 'tokens', 'once');
    if ~isempty(t)
        P.(k{1}) = strtrim(t{1});
    end
end
end


function s = re_posterior_note(c)
% One line on the RE posterior (re/gonogo.txt: chains, draws, how many parameters pass the
% design's convergence rule), which the modes tables do not use.
s = 'RE chains: no re/gonogo.txt';
f = fullfile(c.results, 're', 'gonogo.txt');
if exist(f, 'file') ~= 2
    return
end
t = fileread(f);
hd = regexp(t, 'est_gonogo\(''re''\) ([\d\- :]+)', 'tokens', 'once');
nd = regexp(t, '(\d+) chains, (\d+) draws each used', 'tokens', 'once');
okc = regexp(t, '[\r\n]\w+\s+[-\d.]+\s+[-\d.]+\s+[\d.]+\s+[\d.]+\s+(\d)', 'tokens');
if isempty(hd) || isempty(nd) || isempty(okc)
    s = 'RE chains: re/gonogo.txt not readable';
    return
end
ok = cellfun(@(x) str2double(x{1}), okc);
s = sprintf(['the RE chains (re/chains, %s x %s draws) have converged: %d of %d parameters pass the design''s ' ...
    'rule in est_gonogo(''re'') (%s); that posterior is not used in the modes tables'], nd{1}, nd{2}, ...
    nnz(ok == 1), numel(ok), strtrim(hd{1}));
end


% =============================================================================================
% helpers
% =============================================================================================
function Q = qlabels(nT)
Q = cell(1, nT);
for t = 1:nT
    Q{t} = sprintf('%dQ%d', 1965 + floor((t - 1)/4), mod(t - 1, 4) + 1);
end
end


function t = qidx(y, q)
t = (y - 1965)*4 + q;
end


function s = dstr(d)
s = reshape(cellstr(string(dat2str(d))), [], 1);
end


function q = quantiles(X, p)
% Column quantiles (linear interpolation, Hazen positions), no Statistics Toolbox; NaN-free X.
if isvector(X)
    X = X(:);
end
[n, d] = size(X);
Xs = sort(X, 1);
q = zeros(d, numel(p));
for i = 1:numel(p)
    h = n*p(i) + 0.5;
    lo = min(max(floor(h), 1), n);
    hi = min(lo + 1, n);
    w = h - floor(h);
    q(:, i) = ((1 - w)*Xs(lo, :) + w*Xs(hi, :))';
end
end


function write_long(file, G, varargin)
% A long CSV with the given columns plus status and learn_draws.
names = varargin(1:2:end);
vals = varargin(2:2:end);
n = numel(vals{1});
T = table();
for k = 1:numel(names)
    v = vals{k};
    if iscell(v)
        T.(names{k}) = reshape(v, [], 1);
    else
        T.(names{k}) = reshape(double(v), [], 1);
    end
    assert(size(T, 1) == n, 'write_long: column %s has %d rows, expected %d', names{k}, numel(v), n);
end
if iscell(G.status)
    T.status = reshape(G.status, [], 1);
else
    T.status = repmat({G.status}, n, 1);
end
T.learn_draws = repmat(G.learn_draws, n, 1);
if isfield(G, 'draws')
    T.draws = repmat({G.draws}, n, 1);           % which learning draws: stage1 | stage2
end
tmp = [file '.tmp'];
writetable(T, tmp, 'FileType', 'text', 'Delimiter', ',', 'QuoteStrings', 'all');
movefile(tmp, file, 'f');
end


function s = num2str_keep(v)
if ischar(v)
    s = v;
elseif isnumeric(v)
    s = num2str(v);
else
    s = char(string(v));
end
end


function write_text(file, txt)
fid = fopen(file, 'w');
if fid < 0
    error('est_06_post:write', 'Cannot write %s.', file);
end
fwrite(fid, txt);
if ~endsWith(txt, newline)
    fwrite(fid, newline);
end
fclose(fid);
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
