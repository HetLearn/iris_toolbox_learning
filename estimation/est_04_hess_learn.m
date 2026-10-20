function est_04_hess_learn(part, nparts, variant)
%EST_04_HESS_LEARN  Hessian of the learning model at its mode, split over batch processes.
%
%   est_04_hess_learn(part, nparts, variant)   evaluate stencil points part, part+nparts, ...
%   est_04_hess_learn('merge', [], variant)    assemble H, Laplace MDD, proposal covariance
%
%   Needs <dir>/mode.mat and <dir>/hess_steps.mat from est_03_mode_learn('pick', [], variant)
%   (dir = results/estimation/learn, learn_current or learn_calib). Central differences of
%   minus the log posterior in the original space, 2 d^2 + 1 = 3,043 points (hlest.hessian_fd);
%   the steps keep the facility event pattern of the mode on the axes (hess_steps.mat), and
%   stencil points with another pattern are counted (n_diff_sig).
%   'merge' writes <dir>/hessian.mat (H, Sigma = inverse of H, or of its nearest PD matrix if
%   H is not PD, info, laplace) and <dir>/mode_params.csv, and adds .laplace to mode.mat.

if nargin < 3 || isempty(variant)
    variant = 'lagged';
end
c = setup_est();
maxNumCompThreads(c.threads_learn);
switch variant
    case 'lagged'
        pb = hlest.problem('learn');
        odir = fullfile(c.results, 'learn');
    case 'current'
        pb = hlest.problem('learn', 'info', 'current');
        odir = fullfile(c.results, 'learn_current');
    case 'calib'
        pb = hlest.problem('learn', 'priors', 'calib');
        odir = fullfile(c.results, 'learn_calib');
end
M = load(fullfile(odir, 'mode.mat'));
St = load(fullfile(odir, 'hess_steps.mat'));
pts = hlest.hessian_fd('points', pb.n);
f = @(x) negpost_sig(pb, x);
if ischar(part) && strcmp(part, 'merge')
    fv = NaN(size(pts, 1), 1);
    same = true(size(pts, 1), 1);
    dd = dir(fullfile(odir, 'hess_part_*.mat'));
    for q = 1:numel(dd)
        P = load(fullfile(odir, dd(q).name));
        fv(P.idx) = P.fv;
        same(P.idx) = P.same;
    end
    if any(isnan(fv))
        error('est_04:missing', '%d stencil points missing; run every part first.', nnz(isnan(fv)));
    end
    [H, info] = hlest.hessian_fd('assemble', M.xm, St.h, pts, fv, same);
    [lap, linfo] = hlest.mdd_laplace(M.lp, H);
    Hp = nearest_pd(H);
    lapPD = hlest.mdd_laplace(M.lp, Hp);
    Sigma = inv(Hp);
    Sigma = (Sigma + Sigma')/2;
    % MCMC proposal: the inverse Hessian with the sds of the SW07 parameters widened where the
    % RE posterior (RE chains, post burn-in) is wider than the RE inverse Hessian (persistence
    % parameters with a mode near the upper bound and a long left tail: crhopinf, cmap, crhow,
    % cmaw, crhog); D = clip(sd_post / sd_Hessian, 1, 3), correlations of Sigma kept.
    D = ones(pb.n, 1);
    REm = load(fullfile(c.results, 're', 'mode.mat'));
    dd = dir(fullfile(c.results, 're', 'chains', 'chain_*'));
    Xr = [];
    for q = 1:numel(dd)
        Cq = hlest.read_chain(fullfile(dd(q).folder, dd(q).name));
        if Cq.n > 0
            Xr = [Xr; Cq.draws(floor(Cq.n/2)+1:end, :)]; %#ok<AGROW>
        end
    end
    if ~isempty(Xr)
        D(1:36) = min(max(std(Xr, 0, 1)'./sqrt(diag(REm.Sigma)), 1), 3);
    end
    Sigma_prop = diag(D)*Sigma*diag(D);
    Sigma_prop = (Sigma_prop + Sigma_prop')/2;
    S = struct('H', H, 'Sigma', Sigma, 'Sigma_prop', Sigma_prop, 'D', D, 'info', info, 'laplace', lap, ...
        'laplace_pd', lapPD, 'laplace_info', linfo, 'h', St.h, 'nearest_pd_used', ~info.pd, ...
        'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
    save(fullfile(odir, 'hessian.mat'), '-struct', 'S');
    M.laplace = lap;
    M.laplace_pd = lapPD;
    save(fullfile(odir, 'mode.mat'), '-struct', 'M');
    sd = sqrt(diag(Sigma));
    Tt = table(pb.tab.name, M.xm, sd, 'VariableNames', {'name', 'mode', 'sd_hessian'});
    writetable(Tt, fullfile(odir, 'mode_params.csv'));
    fprintf('merge %s: H PD %d (min eig %.3g), %d stencil points with another event pattern, Laplace %.4f\n', ...
        variant, info.pd, info.min_eig, info.n_diff_sig, lap);
    return
end
idx = part:nparts:size(pts, 1);
t0 = tic;
[fv, same] = hlest.hessian_fd('eval', f, M.xm, St.h, pts, idx);
P = struct('idx', idx, 'fv', fv, 'same', same, 'time_s', toc(t0)); %#ok<NASGU>
save(fullfile(odir, sprintf('hess_part_%02d.mat', part)), '-struct', 'P');
fprintf('part %d/%d: %d points in %.0f s (%.3f s each), %d with another event pattern\n', part, nparts, numel(idx), ...
    toc(t0), toc(t0)/numel(idx), nnz(~same));
end


function [f, sig] = negpost_sig(pb, x)
[lp, ~, ~, out] = hlest.logpost(pb, x);
f = -lp;
sig = '';
if isfield(out, 'sig')
    sig = out.sig;
end
end


function A = nearest_pd(H)
H = (H + H')/2;
[V, D] = eig(H);
d = diag(D);
if all(d > 0)
    A = H;
    return
end
d = max(d, 1e-6*max(abs(d)));
A = V*diag(d)*V';
A = (A + A')/2;
end
