function est_05_mcmc_learn(chain, ndraws, scale, variant)
%EST_05_MCMC_LEARN  One RWMH chain of the learning model (one batch process per chain; resumable).
%
%   est_05_mcmc_learn(chain, ndraws)             % production chain; scale from learn/pilot.mat
%   est_05_mcmc_learn(chain, ndraws, scale)      % chain >= 100: pilot chain at the given scale
%   est_05_mcmc_learn(chain, ndraws, scale, 'wide') % proposal Sigma_prop (widened, see below)
%   est_05_mcmc_learn(chain, ndraws, [], 'cond') % fallback: conditional RWMH on gain, memory,
%                                                % chi and the 7 shock sds, the rest at the mode
%
%   Proposal N(x, c^2 Sigma), Sigma = inverse Hessian at the learning mode (learn/hessian.mat);
%   'wide': Sigma_prop, the same with the sds of the SW07 parameters widened by D = clip(RE
%   posterior sd / RE inverse-Hessian sd, 1, 3) (est_04_hess_learn 'merge'; tried in the pilots,
%   not used: lower acceptance, see learn/pilot.mat); 'cond': the 10 x 10 conditional
%   covariance of the plain inverse Hessian. Production chains start from
%   N(mode, 4 Sigma) draws with a finite posterior (seed 7000 + chain); pilots start at the
%   mode. Random stream mt19937ar, seed 2000 + chain. Every draw stores the parameters, log
%   posterior, log likelihood and the facility event counts of the current state; every 50th
%   draw also its filtered paths ('light': n2, model share n1m, alpha, beta, l_t; single).
%   Folders: results/estimation/learn/chains/chain_<k>/ (pilots: learn/pilot/chain_<k>/,
%   'cond': learn/chains_cond/chain_<k>/); format of hlest.rwmh. Extend a chain by calling it
%   again with a larger ndraws.

if nargin < 3
    scale = [];
end
if nargin < 4 || isempty(variant)
    variant = 'full';
end
c = setup_est();
maxNumCompThreads(c.threads_learn);
pb = hlest.problem('learn');
M = load(fullfile(c.results, 'learn', 'mode.mat'));
Hs = load(fullfile(c.results, 'learn', 'hessian.mat'));
if chain >= 100
    cdir = fullfile(c.results, 'learn', 'pilot', sprintf('chain_%03d', chain));
elseif strcmp(variant, 'cond')
    cdir = fullfile(c.results, 'learn', 'chains_cond', sprintf('chain_%02d', chain));
else
    cdir = fullfile(c.results, 'learn', 'chains', sprintf('chain_%02d', chain));
end
if isempty(scale)
    fcond = fullfile(c.results, 'learn', 'pilot_cond.mat');
    if strcmp(variant, 'cond') && exist(fcond, 'file') ~= 2
        scale = 0.8*2.38/sqrt(10);         % default for the 10-parameter fallback
    elseif strcmp(variant, 'cond')
        Pl = load(fcond);
        scale = Pl.scale;
    else
        Pl = load(fullfile(c.results, 'learn', 'pilot.mat'));
        scale = Pl.scale;
    end
end
if strcmp(variant, 'cond')
    free = [find(pb.tab.learn); (1:7)'];
    fixed = setdiff((1:pb.n)', free);
    S = Hs.Sigma;
    Sc = S(free, free) - S(free, fixed)/S(fixed, fixed)*S(fixed, free);
    Sigma = (Sc + Sc')/2;
    target = @(z) tgt(pb, put(M.xm, free, z));
    xstart = M.xm(free);
    names = pb.tab.name(free);
else
    free = (1:pb.n)';
    Sigma = Hs.Sigma;
    if isfield(Hs, 'Sigma_prop') && strcmp(variant, 'wide')
        Sigma = Hs.Sigma_prop;        % inverse Hessian with widened persistence directions (est_04)
    end
    target = @(x) tgt(pb, x);
    xstart = M.xm;
    names = pb.tab.name;
end
x0 = xstart;
if chain < 100 && exist(fullfile(cdir, 'state.mat'), 'file') ~= 2
    rs = RandStream('mt19937ar', 'Seed', 7000 + chain);
    L = chol(Sigma, 'lower');
    x0 = [];
    for k = 1:500
        x = xstart + 2*L*randn(rs, numel(xstart), 1);
        if isfinite(target(x))
            x0 = x;
            break
        end
    end
    if isempty(x0)
        x0 = xstart;
    end
end
opts = struct('seed', 2000 + chain, 'block', c.block, 'thin', c.thin_paths, 'keep_paths', true, ...
    'names', {names}, 'label', sprintf('learn %s chain %d', variant, chain), 'progress_every', 100, ...
    'meta', struct('kind', 'learn', 'variant', variant, 'free', free, 'mode_lp', M.lp, 'scale', scale, ...
    'xm', M.xm));
hlest.rwmh(cdir, target, x0, Sigma, scale, ndraws, opts);
end


function x = put(xm, free, z)
x = xm;
x(free) = z;
end


function [lp, ll, ex] = tgt(pb, x)
[lp, ll, ~, out] = hlest.logpost(pb, x, 'paths', 'light');
ex = struct('ev', [0 0 0], 'paths', []);
if isfinite(lp)
    ex.ev = [out.ev_plm, out.ev_alm, out.ev_keep];
    ex.paths = struct('n2', single(1 - out.n1), 'n1m', single(out.n1m), 'alpha', single(out.phi(1, :)), ...
        'beta', single(out.phi(2, :)), 'llt', single(out.llt));
end
end
