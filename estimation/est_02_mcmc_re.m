function est_02_mcmc_re(chain, ndraws)
%EST_02_MCMC_RE  One RWMH chain of the RE model (one batch process per chain; resumable).
%
%   est_02_mcmc_re(chain)            % chain = 1, 2, ...; ndraws = est_config().re_draws
%   est_02_mcmc_re(chain, ndraws)    % extend an existing chain to ndraws in total
%   est_02_mcmc_re('post')           % pool the chains (50% burn-in): posterior summary, R-hat,
%                                    % ESS, MHM log MDD -> re/posterior.mat, posterior_summary.csv
%
%   Proposal N(x, c^2 Sigma): Sigma = inverse Hessian at the RE mode (re/mode.mat), c from
%   re/pilot.mat. Start: a draw from N(mode, 4 Sigma) with a finite log posterior (seed
%   5000 + chain); chain random stream mt19937ar, seed 1000 + chain. Output in
%   results/estimation/re/chains/chain_<k>/ (hlest.rwmh: state.mat, block_*.mat, progress.txt).

if ischar(chain) && strcmp(chain, 'post')
    post_re();
    return
end
c = setup_est();
maxNumCompThreads(c.threads);
if nargin < 2 || isempty(ndraws)
    ndraws = c.re_draws;
end
pb = hlest.problem('re');
M = load(fullfile(c.results, 're', 'mode.mat'));
Pl = load(fullfile(c.results, 're', 'pilot.mat'));
cdir = fullfile(c.results, 're', 'chains', sprintf('chain_%02d', chain));
x0 = [];
if exist(fullfile(cdir, 'state.mat'), 'file') ~= 2
    rs = RandStream('mt19937ar', 'Seed', 5000 + chain);
    L = chol(M.Sigma, 'lower');
    for k = 1:1000
        x = M.xm + 2*L*randn(rs, numel(M.xm), 1);
        if isfinite(hlest.logpost(pb, x))
            x0 = x;
            break
        end
    end
    if isempty(x0)
        x0 = M.xm;
    end
end
opts = struct('seed', 1000 + chain, 'block', c.block, 'names', {pb.tab.name}, ...
    'label', sprintf('re chain %d', chain), 'meta', struct('kind', 're', 'mode_lp', M.lp, 'scale', Pl.scale));
hlest.rwmh(cdir, @(x) tgt(pb, x), x0, M.Sigma, Pl.scale, ndraws, opts);
end


function [lp, ll, ex] = tgt(pb, x)
[lp, ll] = hlest.logpost(pb, x);
ex = struct('ev', [], 'paths', []);
end


function post_re()
% est_02_mcmc_re('post'): pool the second half of every RE chain; posterior mean, sd, 5/50/95%
% quantiles, split R-hat and bulk ESS (chains truncated to the shortest for these two), MHM
% log MDD for p = 0.1..0.9. Writes re/posterior.mat and re/posterior_summary.csv. No IRIS.
c = est_config();
addpath(c.est_dir);
M = load(fullfile(c.results, 're', 'mode.mat'));
dd = dir(fullfile(c.results, 're', 'chains', 'chain_*'));
X = [];
LP = [];
C = {};
for k = 1:numel(dd)
    Ck = hlest.read_chain(fullfile(dd(k).folder, dd(k).name));
    h = floor(Ck.n/2);
    X = [X; Ck.draws(h+1:end, :)]; %#ok<AGROW>
    LP = [LP; Ck.lp(h+1:end)]; %#ok<AGROW>
    C{end+1} = Ck; %#ok<AGROW>
end
n = min(cellfun(@(x) x.n, C));
m = numel(C);
d = size(X, 2);
Xd = zeros(n - floor(n/2), m, d);
for j = 1:m
    Xd(:, j, :) = reshape(C{j}.draws(floor(n/2)+1:n, :), [], 1, d);
end
Dg = hlest.diagnostics(Xd);
[mhm, p] = hlest.mdd_mhm(X, LP);
q = quantiles(X, [0.05 0.5 0.95]);
T = table(M.names(:), M.xm, mean(X, 1)', std(X, 0, 1)', q(:, 1), q(:, 2), q(:, 3), Dg.rhat', Dg.ess_bulk', ...
    'VariableNames', {'name', 'mode', 'mean', 'sd', 'q05', 'q50', 'q95', 'rhat', 'ess_bulk'});
writetable(T, fullfile(c.results, 're', 'posterior_summary.csv'));
S = struct('mhm', mhm, 'p', p, 'laplace', M.laplace, 'n_draws_pooled', size(X, 1), ...
    'chain_draws', cellfun(@(x) x.n, C), 'acc', cellfun(@(x) mean(x.acc), C), 'diag', Dg, 'summary', T, ...
    'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
save(fullfile(c.results, 're', 'posterior.mat'), '-struct', 'S');
fprintf('RE posterior: %d chains (%s draws), %d pooled post-burn-in draws; MHM log MDD %s (p = 0.1..0.9); Laplace %.4f\n', ...
    m, mat2str(S.chain_draws), size(X, 1), mat2str(mhm, 7), M.laplace);
fprintf('R-hat max %.4f; ESS min %.1f (%s); parameters with ESS < 100: %s\n', max(Dg.rhat), min(Dg.ess_bulk), ...
    M.names{Dg.ess_bulk == min(Dg.ess_bulk)}, strjoin(M.names(Dg.ess_bulk < 100), ', '));
end


function q = quantiles(X, p)
% Column quantiles without the Statistics Toolbox (linear interpolation, Hazen positions).
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
