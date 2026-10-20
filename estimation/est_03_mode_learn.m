function est_03_mode_learn(stage, k, variant)
%EST_03_MODE_LEARN  Posterior mode of the learning model (one stage per batch process).
%
%   est_03_mode_learn('learn3', [], variant)  gain, memory, chi with the 36 SW07 parameters at
%                                             the RE mode: csminwel from the calibration and
%                                             from the prior mean, then fminsearch polish
%   est_03_mode_learn('full', k, variant)     all 39 parameters from start k:
%                                             1 [RE mode; best of 'learn3'],
%                                             2 [RE mode; learning prior mean],
%                                             3 [RE mode + 0.5 posterior sd (seeded); calibration]
%                                             ('current' and 'calib' use start 1 only, with the
%                                             baseline's 'learn3' values if their own are missing)
%   est_03_mode_learn('pick', [], variant)    best full search -> mode.mat; Hessian steps with the
%                                             facility event-pattern check (hess_steps.mat)
%   est_03_mode_learn('robust')               at the baseline mode: (c) IJCB-style fixed initial
%                                             beliefs (RE moments at the RE mode), (d) 'freeze'
%                                             learning in the 2020 gap; likelihood only
%
%   variant 'lagged' (baseline, results/estimation/learn), 'current' (beliefs.info = 'current',
%   learn_current), 'calib' (priors centred on the calibration, learn_calib).
%   Mode searches run in the logistic-transformed space (hlest.transform), csminwel with the
%   inverse of the RE Hessian (transformed) as the initial inverse Hessian of the SW07 block.

if nargin < 2
    k = [];
end
if nargin < 3 || isempty(variant)
    variant = 'lagged';
end
c = setup_est();
maxNumCompThreads(c.threads_learn);
[pb, odir] = make_problem(c, variant);
tag = stage;
if ~isempty(k)
    tag = sprintf('%s_%d', stage, k);
end
diary(fullfile(odir, sprintf('diary_%s.txt', tag)));
cl = onCleanup(@() diary('off'));
fprintf('est_03_mode_learn %s %s, started %s\n', tag, variant, datestr(now)); %#ok<TNOW1,DATST>
RE = load(fullfile(c.results, 're', 'mode.mat'));
lb = pb.lb;
ub = pb.ub;
iL = find(pb.tab.learn);
switch stage
    case 'learn3'
        starts = [0.0585 0.6 0.51; pb.tab.p1(iL)'];
        if strcmp(variant, 'calib')
            starts = starts(1, :);
        end
        res = struct('l0', {}, 'l', {}, 'lp', {}, 'H', {});
        for s = 1:size(starts, 1)
            l0 = starts(s, :)';
            fu = @(u) negpost(pb, [RE.xm; hlest.transform('x', u, lb(iL), ub(iL))]);
            u0 = hlest.transform('u', l0, lb(iL), ub(iL));
            % capped: the facility makes the surface piecewise smooth (csminwel "cliffs"), so
            % csminwel takes the large steps and Nelder-Mead polishes
            [~, uh, ~, Hh] = hlest.csminwel(fu, u0, 1e-2*eye(3), 1e-4, 15, struct('max_time', 240));
            ops = optimset('Display', 'iter', 'MaxFunEvals', 150, 'MaxIter', 150, 'TolX', 1e-6, 'TolFun', 1e-6);
            [uh2, fh2] = fminsearch(fu, uh, ops);
            l = hlest.transform('x', uh2, lb(iL), ub(iL));
            res(s) = struct('l0', l0, 'l', l, 'lp', -fh2, 'H', Hh);
            fprintf('learn3 start %s -> gain %.5f omega %.4f chi %.4f, log posterior %.4f\n', mat2str(l0', 4), l, -fh2);
        end
        [~, b] = max([res.lp]);
        x = [RE.xm; res(b).l];
        [lp, ll, lpr, out] = hlest.logpost(pb, x);
        M3 = struct('x', x, 'l', res(b).l, 'lp', lp, 'll', ll, 'lpr', lpr, 'Hu3', res(b).H, 'starts', res, ...
            'events', out.events, 'sig', out.sig);
        save(fullfile(odir, 'mode3.mat'), '-struct', 'M3');
        fprintf('learn3 best: lp %.4f ll %.4f events %s\n', lp, ll, out.sig);
    case 'full'
        f3 = fullfile(odir, 'mode3.mat');
        if exist(f3, 'file') ~= 2
            f3 = fullfile(c.results, 'learn', 'mode3.mat');
        end
        switch k
            case 1
                M3 = load(f3);
                x0 = [RE.xm; M3.l];
                Hl = M3.Hu3;
            case 2
                x0 = [RE.xm; pb.tab.p1(iL)];
                Hl = 1e-2*eye(3);
            case 3
                rs = RandStream('mt19937ar', 'Seed', 303);
                xs = RE.xm + 0.5*sqrt(diag(RE.Sigma)).*sign(randn(rs, numel(RE.xm), 1));
                xs = min(max(xs, lb(1:36) + 1e-4*(ub(1:36) - lb(1:36))), ub(1:36) - 1e-4*(ub(1:36) - lb(1:36)));
                x0 = [xs; 0.0585; 0.6; 0.51];
                Hl = 1e-2*eye(3);
        end
        if ~isfinite(hlest.logpost(pb, x0))
            error('est_03:start', 'Start %d has a non-finite log posterior.', k);
        end
        u0 = hlest.transform('u', x0, lb, ub);
        J = hlest.transform('dxdu', u0(1:36), lb(1:36), ub(1:36));
        Hu = diag(J)*RE.H*diag(J);
        H0 = blkdiag(inv((Hu + Hu')/2), (Hl + Hl')/2);
        fu = @(u) negpost(pb, hlest.transform('x', u, lb, ub));
        pfile = fullfile(odir, sprintf('mode_full_%d_progress.mat', k));
        if exist(pfile, 'file') == 2
            Pp = load(pfile);
            if isfinite(Pp.f) && Pp.f < fu(u0)
                fprintf('resuming start %d from its checkpoint (iteration %d, f %.6f)\n', k, Pp.it, Pp.f);
                u0 = Pp.u;
            end
        end
        copt = struct('max_time', 45*60, 'checkpoint', @(u, f, it) save(pfile, 'u', 'f', 'it'));
        t0 = tic;
        [fh, uh, ~, Hh, it, fc, rc] = hlest.csminwel(fu, u0, H0, 1e-6, 150, copt);
        % a start on a facility "cliff" (event pattern changes within the gradient step) can
        % stop csminwel at once (line search fails both ways): retry from small perturbations
        rsr = RandStream('mt19937ar', 'Seed', 400 + k);
        f0 = fu(u0);
        for tr = 1:3
            if f0 - fh > 1e-3 || toc(t0) > 40*60
                break
            end
            up = u0 + [0.02*randn(rsr, 36, 1); 0.1*randn(rsr, 3, 1)];
            fprintf('start %d made no progress (retcode %d); retry %d from a perturbed point (f %.4f)\n', k, rc, tr, fu(up));
            copt.max_time = max(60, 45*60 - toc(t0));
            [fh2, uh2, ~, Hh2, it2, fc2, rc] = hlest.csminwel(fu, up, H0, 1e-6, 150, copt);
            it = it + it2;
            fc = fc + fc2;
            if fh2 < fh
                fh = fh2;
                uh = uh2;
                Hh = Hh2;
            end
        end
        x = hlest.transform('x', uh, lb, ub);
        [lp, ll, lpr, out] = hlest.logpost(pb, x);
        F = struct('k', k, 'x0', x0, 'x', x, 'lp', lp, 'll', ll, 'lpr', lpr, 'f', fh, 'Hu', Hh, 'iterations', it, ...
            'fcount', fc, 'retcode', rc, 'time_s', toc(t0), 'events', out.events, 'sig', out.sig, ...
            'ev', [out.ev_plm out.ev_alm out.ev_keep], 'variant', variant);
        save(fullfile(odir, sprintf('mode_full_%d.mat', k)), '-struct', 'F');
        fprintf('full start %d: lp %.4f ll %.4f, gain %.5f omega %.4f chi %.4f, %d iterations, %d evaluations, %.0f s, events %s\n', ...
            k, lp, ll, x(pb.ig), x(pb.iom), x(pb.ichi), it, fc, toc(t0), out.sig);
    case 'pick'
        dd = dir(fullfile(odir, 'mode_full_*.mat'));
        dd = dd(~contains({dd.name}, 'progress'));
        best = [];
        all = struct('k', {}, 'lp', {}, 'll', {}, 'x', {}, 'sig', {});
        for q = 1:numel(dd)
            F = load(fullfile(odir, dd(q).name));
            all(end+1) = struct('k', F.k, 'lp', F.lp, 'll', F.ll, 'x', F.x, 'sig', F.sig); %#ok<AGROW>
            if isempty(best) || F.lp > best.lp
                best = F;
            end
        end
        xm = best.x;
        [lp, ll, lpr, out] = hlest.logpost(pb, xm, 'paths', true);
        f = @(x) negpost_sig(pb, x);
        h0 = 1e-3*max(abs(xm), 0.05);
        [h, sinfo] = hlest.hessian_fd('steps', f, xm, h0, lb, ub);
        M = struct('xm', xm, 'names', {pb.tab.name}, 'lp', lp, 'll', ll, 'lpr', lpr, 'out', out, 'starts', all, ...
            'best_start', best.k, 'variant', variant, 'kind', 'learn', 'lb', lb, 'ub', ub, ...
            'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
        save(fullfile(odir, 'mode.mat'), '-struct', 'M');
        S = struct('h', h, 'h0', h0, 'info', sinfo);
        save(fullfile(odir, 'hess_steps.mat'), '-struct', 'S');
        fprintf('pick: best start %d, lp %.4f (starts: %s); events %s; steps shrunk for %d parameters\n', best.k, lp, ...
            sprintf('%d:%.3f ', [[all.k]; [all.lp]]), out.sig, nnz(sinfo.n_shrink));
    case 'robust'
        M = load(fullfile(c.results, 'learn', 'mode.mat'));
        Hs = load(fullfile(c.results, 'learn', 'hessian.mat'));
        % (c) IJCB-style fixed initial beliefs: RE moments of the RE model at the RE mode
        pbF = hlest.problem('learn');
        [~, o0] = hlest.loglik_learn(pbF, [RE.xm; M.xm(37:39)]);
        pbc = hlest.problem('learn', 'init_beliefs', 'fixed', 'phi0', o0.phi0, 'R0', o0.R0);
        [lpc, llc, lprc, oc] = hlest.logpost(pbc, M.xm);
        % (d) freeze learning in quarters without data (2020Q1-Q3)
        pbd = hlest.problem('learn', 'gap', 'freeze');
        [lpd, lld, lprd, od] = hlest.logpost(pbd, M.xm);
        Hb = Hs.H;
        if ~Hs.info.pd
            Hb = inv(Hs.Sigma);          % nearest PD matrix of H (est_04_hess_learn)
            Hb = (Hb + Hb')/2;
        end
        lapB = hlest.mdd_laplace(M.lp, Hb);
        R = struct('ll_base', M.ll, 'lp_base', M.lp, 'laplace_base', lapB, ...
            'c_ll', llc, 'c_lp', lpc, 'c_laplace_approx', hlest.mdd_laplace(lpc, Hb), 'c_phi0', o0.phi0, 'c_R0', o0.R0, ...
            'c_events', oc.sig, 'd_ll', lld, 'd_lp', lpd, 'd_laplace_approx', hlest.mdd_laplace(lpd, Hb), ...
            'd_events', od.sig, 'lpr', [lprc lprd]);
        save(fullfile(c.results, 'learn', 'robust.mat'), '-struct', 'R');
        fprintf(['robust at the learning mode: baseline ll %.4f; (c) fixed initial beliefs %s: ll %.4f (diff %.4f); ' ...
            '(d) freeze: ll %.4f (diff %.4f); approximate Laplace (baseline Hessian) %.4f / %.4f / %.4f\n'], M.ll, ...
            mat2str(o0.phi0', 5), llc, llc - M.ll, lld, lld - M.ll, lapB, R.c_laplace_approx, R.d_laplace_approx);
    otherwise
        error('est_03:stage', 'Unknown stage %s.', stage);
end
fprintf('done %s\n', datestr(now)); %#ok<TNOW1,DATST>
end


function [pb, odir] = make_problem(c, variant)
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
    otherwise
        error('est_03:variant', 'Unknown variant %s.', variant);
end
if exist(odir, 'dir') ~= 7
    mkdir(odir);
end
end


function f = negpost(pb, x)
f = -hlest.logpost(pb, x);
if ~isfinite(f)
    f = 1e10;
end
end


function [f, sig] = negpost_sig(pb, x)
[lp, ~, ~, out] = hlest.logpost(pb, x);
f = -lp;
sig = '';
if isfield(out, 'sig')
    sig = out.sig;
end
end
