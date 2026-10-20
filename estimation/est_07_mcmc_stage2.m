function R = est_07_mcmc_stage2(cmd, n, varargin)
%EST_07_MCMC_STAGE2  Second RWMH stage of the learning model: proposal = covariance of the stage-1 draws.
%
%   est_07_mcmc_stage2('prepare')        % 'proposal', then 'pilot' (300 draws at 3 scales), then 'pick',
%                                        % all in this process (about 8 minutes)
%   est_07_mcmc_stage2('proposal')       % <base>/stage2_proposal.mat from the stage-1 block files
%   est_07_mcmc_stage2('pilot', 300, 'scales', [0.17 0.21 0.26])   % short pilot runs in this process
%   est_07_mcmc_stage2('pick')           % <base>/stage2_pilot.mat: the scale for 27.5% acceptance
%   est_07_mcmc_stage2(k, ndraws)        % stage-2 chain k (1..6): resumable; a larger ndraws extends it
%   est_07_mcmc_stage2('compare')        % ESS per 1,000 draws and jump distance, stage 1 against stage 2
%
%   Options (name, value pairs, every call)
%     'base'       folder for everything stage 2 writes (default results/estimation/learn; the test of
%                  2026-10-20 used results/estimation/learn/stage2_test)
%     'stage1'     folder of the stage-1 chains (default results/estimation/learn/chains)
%     'burn1'      share of each stage-1 chain dropped before the covariance (0.25)
%     'shrink'     Sigma = (1 - shrink) Sigma_emp + shrink diag(diag(Sigma_emp)) (0.1)
%     'min_age_s'  block files younger than this are not read (120; 0 for a chain whose
%                  progress.txt says done), so the running stage-1 chains are never disturbed
%     'scale'      chain: override the picked scale; 'scales' pilot scales; 'target' acceptance (0.275)
%
%   Proposal (cmd 'proposal'). The sampler (hlest.rwmh_core) works in the original parameter space:
%   x' = x + c L z, L L' = Sigma, and a proposal outside the bounds or the prior support has log
%   posterior -Inf and is rejected. So the covariance is taken of the raw draws: every stage-1
%   chain's completed blocks (hlest.read_blocks; state.mat is never opened), the first 25% of each
%   chain dropped, the rest pooled. The pooled covariance contains the between-chain spread along
%   the slow SW07 ridges (crhow/cmaw, crhopinf/cmap), which the inverse Hessian at the mode misses.
%   It is shrunk by 10% towards its diagonal: that keeps it positive definite and well conditioned
%   when a direction is poorly estimated (few effective draws along the ridges) while keeping 90%
%   of every correlation; the scale is tuned on this matrix, so the shrinkage costs little.
%   Saved: Sigma, Sigma_emp, mu, names, chains, n_read (draws read per chain), n_used (after the
%   burn-in), burn1, shrink, xlast/lplast/lllast (last state of each chain = last row of its last
%   complete block), eig_min/eig_max, created.
%
%   Pilot and pick. Each pilot run starts at the same stage-1 last state (the chain with the
%   median last log posterior) and runs n draws in memory (hlest.rwmh_core) at one scale; the
%   result goes to <base>/stage2_pilot/pilot_<scale>.mat (so pilots can also run in parallel
%   processes, one scale each). 'pick' fits log(acceptance) on the scale (linear) over every pilot
%   file and solves for the target, inside [0.5, 1.5] x the range of the pilot scales.
%   Test of 2026-10-20 03:17-03:38 (interim covariance from 6 x 21,000 stage-1 draws; folder
%   deleted afterwards): the Gaussian rule 2.38/sqrt(39) = 0.381 gives 9% acceptance; pilots of
%   300 draws at 0.15/0.19/0.24/0.30/0.381/0.47 gave 47/32/19/11/9/2%, the pick 0.209, and three
%   1,000-draw chains at 0.209 had 27-31%. Hence the default pilot scales 0.17/0.21/0.26. Against
%   stage 1 (same window length, 900 draws): mean squared jump per draw 7.3x (crhow), 4.9x (cmaw),
%   1.6x (gain), 0.9x (crhopinf), 0.65x (chi); single-chain ESS per 1,000 draws 2.0x (crhow), 2.4x
%   (cmaw), about 1x for gain, crhopinf and cmap, 0.8x for chi.
%
%   Chains. Chain k starts at the last state of stage-1 chain k, proposal N(x, c^2 Sigma) with
%   Sigma and c from the two files above (stored in its state.mat at the first call and reused on
%   every resume), random stream mt19937ar seed 9000 + k, one thread. Folder
%   <base>/chains2/chain_0k/ in the format of hlest.rwmh (block_*.mat of 1,000 draws with the
%   thinned paths every 50th draw, state.mat, progress.txt), so hlest.read_blocks/read_chain,
%   est_status2, est_gonogo2 and est_06_post(..., 'draws', 'stage2') read it. Post-processing
%   treats stage 1 as adaptation and drops the first 10% of every stage-2 chain.
%   Launch: powershell -File launch.ps1 -Cmd "est_07_mcmc_stage2(1, 30000)" -Log "mcmc2_1.txt".

if nargin < 2
    n = [];
end
c = setup_est();
maxNumCompThreads(c.threads_learn);
ip = inputParser;
ip.addParameter('base', fullfile(c.results, 'learn'));
ip.addParameter('stage1', fullfile(c.results, 'learn', 'chains'));
ip.addParameter('burn1', 0.25);
ip.addParameter('shrink', 0.1);
ip.addParameter('min_age_s', 120);
ip.addParameter('scale', []);
ip.addParameter('scales', [0.17 0.21 0.26]);
ip.addParameter('target', 0.275);
ip.parse(varargin{:});
o = ip.Results;
if exist(o.base, 'dir') ~= 7
    mkdir(o.base);
end
pfile = fullfile(o.base, 'stage2_proposal.mat');
sfile = fullfile(o.base, 'stage2_pilot.mat');
R = struct();
if isnumeric(cmd)
    R = run_chain(c, o, cmd, n, pfile, sfile);
    return
end
switch cmd
    case 'proposal'
        R = build_proposal(c, o, pfile);
    case 'pilot'
        if isempty(n), n = 300; end
        R = pilot(c, o, n, pfile);
    case 'pick'
        R = pick(o, sfile);
    case 'prepare'
        if isempty(n), n = 300; end
        build_proposal(c, o, pfile);
        old = dir(fullfile(o.base, 'stage2_pilot', 'pilot_*.mat'));    % pilots of an earlier proposal
        for k = 1:numel(old)
            delete(fullfile(old(k).folder, old(k).name));
        end
        pilot(c, o, n, pfile);
        R = pick(o, sfile);
    case 'compare'
        R = compare(c, o);
    otherwise
        error('est_07_mcmc_stage2:cmd', 'Unknown command %s.', cmd);
end
end


% =============================================================================================
function P = build_proposal(c, o, pfile)
pb = hlest.problem('learn');
dd = dir(fullfile(o.stage1, 'chain_*'));
dd = dd([dd.isdir]);
Xc = {};
P = struct('chains', {{}}, 'n_read', [], 'n_used', [], 'xlast', zeros(pb.n, 0), 'lplast', [], 'lllast', [], ...
    'status1', {{}}, 'notes', {{}});
for k = 1:numel(dd)
    cdir = fullfile(dd(k).folder, dd(k).name);
    st = progress_status(cdir);
    age = o.min_age_s;
    if strcmp(st, 'done')
        age = 0;                 % stopped chain: no block can be in the middle of being written
    end
    C = hlest.read_blocks(cdir, false, age);
    if C.n < 2*c.block
        fprintf('[stage2] %s: %d draws, skipped\n', dd(k).name, C.n);
        continue
    end
    b = floor(o.burn1*C.n);
    Xc{end+1} = C.draws(b+1:end, :); %#ok<AGROW>
    P.chains{end+1} = dd(k).name;
    P.n_read(end+1) = C.n;
    P.n_used(end+1) = C.n - b;
    P.xlast(:, end+1) = C.draws(end, :)';
    P.lplast(end+1) = C.lp(end);
    P.lllast(end+1) = C.ll(end);
    P.status1{end+1} = st;
    P.notes{end+1} = C.note;
    fprintf('[stage2] %s: %d draws read (%s), %d used, last lp %.3f\n', dd(k).name, C.n, st, C.n - b, C.lp(end));
end
if numel(Xc) < 2
    error('est_07_mcmc_stage2:proposal', 'Fewer than 2 stage-1 chains with 2 or more completed blocks in %s.', o.stage1);
end
X = vertcat(Xc{:});
P.mu = mean(X, 1)';
Se = cov(X);
Se = (Se + Se')/2;
S = (1 - o.shrink)*Se + o.shrink*diag(diag(Se));
S = (S + S')/2;
[~, p] = chol(S);
if p ~= 0
    error('est_07_mcmc_stage2:proposal', 'The regularised covariance is not positive definite.');
end
ev = eig(S);
P.Sigma = S;
P.Sigma_emp = Se;
P.names = pb.tab.name;
P.burn1 = o.burn1;
P.shrink = o.shrink;
P.n_pooled = size(X, 1);
P.eig_min = min(ev);
P.eig_max = max(ev);
P.stage1 = o.stage1;
P.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
% comparison with the stage-1 proposal (inverse Hessian at the mode): sd ratios
Hs = load(fullfile(c.results, 'learn', 'hessian.mat'));
P.sd_ratio_vs_hessian = sqrt(diag(S))./sqrt(diag(Hs.Sigma));
save(pfile, '-struct', 'P');
cr = corrcov_(Se);
fprintf('[stage2] proposal from %d chains, %s draws read, %d pooled after %.0f%% burn-in; eig %.3g..%.3g\n', ...
    numel(P.chains), mat2str(P.n_read), P.n_pooled, 100*o.burn1, P.eig_min, P.eig_max);
pairs = {'crhow', 'cmaw'; 'crhopinf', 'cmap'; 'gain', 'chi'};
for q = 1:size(pairs, 1)
    i = find(strcmp(P.names, pairs{q, 1}));
    j = find(strcmp(P.names, pairs{q, 2}));
    fprintf('[stage2] corr(%s, %s) = %.3f; sd %s %.4g (%.2f x Hessian), %s %.4g (%.2f x Hessian)\n', pairs{q, 1}, ...
        pairs{q, 2}, cr(i, j), pairs{q, 1}, sqrt(S(i, i)), P.sd_ratio_vs_hessian(i), pairs{q, 2}, sqrt(S(j, j)), ...
        P.sd_ratio_vs_hessian(j));
end
fprintf('[stage2] wrote %s\n', pfile);
end


function R = corrcov_(S)
s = sqrt(diag(S));
R = S./(s*s');
end


% =============================================================================================
function R = pilot(c, o, n, pfile)
pb = hlest.problem('learn');
P = load(pfile);
L = chol(P.Sigma, 'lower');
[~, o2] = sort(P.lplast);
j0 = o2(ceil(numel(o2)/2));        % the chain with the median last log posterior
x0 = P.xlast(:, j0);
pdir = fullfile(o.base, 'stage2_pilot');
if exist(pdir, 'dir') ~= 7
    mkdir(pdir);
end
target = @(x) tgt(pb, x);
[lp0, ll0, ex0] = target(x0);
R = struct('scale', o.scales(:)', 'acc', NaN(1, numel(o.scales)), 's_per_draw', NaN(1, numel(o.scales)));
for i = 1:numel(o.scales)
    sc = o.scales(i);
    rs = RandStream('mt19937ar', 'Seed', 8100 + round(1000*sc));
    st = struct('x', x0, 'lp', lp0, 'll', ll0, 'ev', ex0.ev, 'paths', ex0.paths, 'n_done', 0);
    t0 = tic;
    [B, st] = hlest.rwmh_core(target, st, L, sc, n, rs, c.thin_paths, false); %#ok<ASGLU>
    Q = struct('scale', sc, 'n', n, 'acc', mean(B.acc), 's_per_draw', toc(t0)/n, 'start_chain', P.chains{j0}, ...
        'proposal_created', P.created, 'draws', B.draws, 'lp', B.lp, 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
    save(fullfile(pdir, sprintf('pilot_%.4f.mat', sc)), '-struct', 'Q');
    R.acc(i) = Q.acc;
    R.s_per_draw(i) = Q.s_per_draw;
    fprintf('[stage2] pilot scale %.4f: %d draws from %s, acceptance %.3f, %.3f s per draw\n', sc, n, P.chains{j0}, ...
        Q.acc, Q.s_per_draw);
end
end


function R = pick(o, sfile)
dd = dir(fullfile(o.base, 'stage2_pilot', 'pilot_*.mat'));
if isempty(dd)
    error('est_07_mcmc_stage2:pick', 'No pilot files in %s.', fullfile(o.base, 'stage2_pilot'));
end
sc = zeros(1, numel(dd));
acc = sc;
spd = sc;
nn = sc;
for k = 1:numel(dd)
    Q = load(fullfile(dd(k).folder, dd(k).name), 'scale', 'acc', 's_per_draw', 'n');
    sc(k) = Q.scale;
    acc(k) = Q.acc;
    spd(k) = Q.s_per_draw;
    nn(k) = Q.n;
end
[sc, ix] = sort(sc);
acc = acc(ix);
spd = spd(ix);
nn = nn(ix);
if numel(sc) >= 2
    pf = polyfit(sc, log(max(acc, 1e-3)), 1);
    s = (log(o.target) - pf(2))/pf(1);
else
    s = sc*exp((acc - o.target)/0.5);
end
lo = 0.5*min(sc);
hi = 1.5*max(sc);
if ~isfinite(s) || s <= 0
    [~, i] = min(abs(acc - o.target));
    s = sc(i);
end
s = min(max(s, lo), hi);
sfit = s;
if ~isempty(o.scale)
    s = o.scale;
end
R = struct('scale', s, 'scale_fit', sfit, 'scales', sc, 'acc', acc, 's_per_draw', spd, 'n', nn, 'target', o.target, ...
    'default_scale', 2.38/sqrt(39), 'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
save(sfile, '-struct', 'R');
fprintf('[stage2] pilots: %s\n', strjoin(arrayfun(@(k) sprintf('scale %.4f acc %.3f (%d draws, %.3f s/draw)', sc(k), ...
    acc(k), nn(k), spd(k)), 1:numel(sc), 'UniformOutput', false), '; '));
fprintf('[stage2] chosen scale %.4f for target acceptance %.3f (fit %.4f); wrote %s\n', s, o.target, sfit, sfile);
end


% =============================================================================================
function R = run_chain(c, o, k, ndraws, pfile, sfile)
if isempty(ndraws)
    error('est_07_mcmc_stage2:ndraws', 'est_07_mcmc_stage2(k, ndraws): give the number of draws.');
end
pb = hlest.problem('learn');
M = load(fullfile(c.results, 'learn', 'mode.mat'));
cdir = fullfile(o.base, 'chains2', sprintf('chain_%02d', k));
P = load(pfile);
scale = o.scale;
if isempty(scale)
    if exist(sfile, 'file') == 2
        Pl = load(sfile);
        scale = Pl.scale;
    else
        scale = 2.38/sqrt(pb.n);
        fprintf('[stage2] no %s: default scale 2.38/sqrt(%d) = %.4f\n', sfile, pb.n, scale);
    end
end
j = mod(k - 1, numel(P.chains)) + 1;
x0 = P.xlast(:, j);
if exist(fullfile(cdir, 'state.mat'), 'file') == 2
    fprintf('[stage2] chain %d: resuming (the stored proposal and scale are kept)\n', k);
else
    fprintf('[stage2] chain %d: start at the last state of stage-1 %s (draw %d, lp %.4f), scale %.4f\n', k, ...
        P.chains{j}, P.n_read(j), P.lplast(j), scale);
end
opts = struct('seed', 9000 + k, 'block', c.block, 'thin', c.thin_paths, 'keep_paths', true, ...
    'names', {pb.tab.name}, 'label', sprintf('learn stage-2 chain %d', k), 'progress_every', 100, ...
    'meta', struct('kind', 'learn', 'variant', 'stage2', 'stage', 2, 'free', (1:pb.n)', 'mode_lp', M.lp, ...
    'xm', M.xm, 'scale', scale, 'proposal_file', pfile, 'proposal_created', P.created, ...
    'start_chain', P.chains{j}, 'start_draw', P.n_read(j), 'burn1', P.burn1, 'shrink', P.shrink));
R = hlest.rwmh(cdir, @(x) tgt(pb, x), x0, P.Sigma, scale, ndraws, opts);
end


% =============================================================================================
function R = compare(c, o)
% ESS per 1,000 draws (single-chain split ESS, hlest.diagnostics on each chain, averaged over the
% chains) and the mean squared jump per draw in units of the stage-1 posterior variance, for the
% learning parameters and the ridge parameters; stage 1 on its second halves, stage 2 on everything
% after its first 10%.
pb = hlest.problem('learn');
names = {'gain', 'omega', 'chi', 'crhow', 'cmaw', 'crhopinf', 'cmap', 'epinf'};
idx = cellfun(@(nm) find(strcmp(pb.tab.name, nm)), names);
S1 = read_dir(o.stage1, o.min_age_s, 0.5);
S2 = read_dir(fullfile(o.base, 'chains2'), o.min_age_s, 0.1);
if isempty(S1)
    error('est_07_mcmc_stage2:compare', 'No stage-1 chains.');
end
v1 = var(vertcat(S1.X), 0, 1);
R = struct('names', {names}, 'stage1', stats(S1, idx, v1), 'stage2', [], 'stage1_windowed', []);
if ~isempty(S2)
    R.stage2 = stats(S2, idx, v1);
    % stage 1 cut into windows as long as the stage-2 chains: the same short-chain bias of the ESS estimate
    w = min(arrayfun(@(s) size(s.X, 1), S2));
    Sw = struct('name', {}, 'X', {}, 'acc', {});
    for k = 1:numel(S1)
        nw = floor(size(S1(k).X, 1)/w);
        for j = 1:nw
            Sw(end+1) = struct('name', sprintf('%s_w%d', S1(k).name, j), 'X', S1(k).X((j-1)*w+1:j*w, :), 'acc', S1(k).acc); %#ok<AGROW>
        end
    end
    R.stage1_windowed = stats(Sw, idx, v1);
    R.window = w;
end
fprintf('%-10s %26s %26s %26s %18s\n', 'parameter', 'stage 1: ESS/1000 (ESJD)', 'stage 1 windows: ESS/1000', ...
    'stage 2: ESS/1000 (ESJD)', 'ratio ESS w / ESJD');
for q = 1:numel(names)
    a = R.stage1;
    t2 = 'n/a';
    tw = 'n/a';
    rt = '';
    if ~isempty(R.stage2)
        b = R.stage2;
        aw = R.stage1_windowed;
        t2 = sprintf('%8.2f (%.4f)', b.ess_per_1000(q), b.esjd(q));
        tw = sprintf('%8.2f', aw.ess_per_1000(q));
        rt = sprintf('%6.2f / %6.2f', b.ess_per_1000(q)/aw.ess_per_1000(q), b.esjd(q)/a.esjd(q));
    end
    fprintf('%-10s %26s %26s %26s %18s\n', names{q}, sprintf('%8.2f (%.4f)', a.ess_per_1000(q), a.esjd(q)), tw, t2, rt);
end
if ~isempty(R.stage2)
    fprintf(['ESS/1000: single-chain split ESS (hlest.diagnostics, raw draws) per 1,000 draws, averaged over chains; ' ...
        'stage 1 windows: its post burn-in draws cut into %d-draw pieces (as long as the stage-2 chains). ESJD: mean ' ...
        'squared jump per draw / stage-1 posterior variance.\n'], R.window);
end
fprintf('stage 1: %d chains, %s draws used per chain (acceptance %s); stage 2: %d chains, %s draws used per chain (acceptance %s)\n', ...
    numel(S1), mat2str(arrayfun(@(s) size(s.X, 1), S1)), mat2str(round(arrayfun(@(s) s.acc, S1), 3)), numel(S2), ...
    mat2str(arrayfun(@(s) size(s.X, 1), S2)), mat2str(round(arrayfun(@(s) s.acc, S2), 3)));
end


function S = read_dir(base, minAge, burn)
dd = dir(fullfile(base, 'chain_*'));
dd = dd([dd.isdir]);
S = struct('name', {}, 'X', {}, 'acc', {});
for k = 1:numel(dd)
    cdir = fullfile(dd(k).folder, dd(k).name);
    age = minAge;
    if strcmp(progress_status(cdir), 'done')
        age = 0;
    end
    C = hlest.read_blocks(cdir, false, age);
    if C.n < 20
        continue
    end
    b = floor(burn*C.n);
    S(end+1) = struct('name', dd(k).name, 'X', C.draws(b+1:end, :), 'acc', mean(C.acc(b+1:end))); %#ok<AGROW>
end
end


function T = stats(S, idx, v1)
m = numel(S);
e = zeros(m, numel(idx));
j = zeros(m, numel(idx));
for k = 1:m
    X = S(k).X(:, idx);
    nk = size(X, 1);
    D = hlest.diagnostics(reshape(X, nk, 1, numel(idx)));
    e(k, :) = D.ess_raw/nk*1000;
    j(k, :) = mean(diff(X, 1, 1).^2, 1)./v1(idx);
end
T = struct('ess_per_1000', mean(e, 1), 'ess_per_1000_by_chain', e, 'esjd', mean(j, 1), 'draws', ...
    arrayfun(@(s) size(s.X, 1), S), 'acc', arrayfun(@(s) s.acc, S));
end


% =============================================================================================
function st = progress_status(cdir)
st = '';
f = fullfile(cdir, 'progress.txt');
if exist(f, 'file') ~= 2
    return
end
try
    txt = fileread(f);
    t = regexp(txt, 'status = (\w+)', 'tokens', 'once');
    if ~isempty(t)
        st = t{1};
    end
catch
end
end


function [lp, ll, ex] = tgt(pb, x)
% As est_05_mcmc_learn: log posterior, log likelihood, facility events and the light paths.
[lp, ll, ~, out] = hlest.logpost(pb, x, 'paths', 'light');
ex = struct('ev', [0 0 0], 'paths', []);
if isfinite(lp)
    ex.ev = [out.ev_plm, out.ev_alm, out.ev_keep];
    ex.paths = struct('n2', single(1 - out.n1), 'n1m', single(out.n1m), 'alpha', single(out.phi(1, :)), ...
        'beta', single(out.phi(2, :)), 'llt', single(out.llt));
end
end
