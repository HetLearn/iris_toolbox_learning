function est_01_mode_re()
%EST_01_MODE_RE  RE benchmark: posterior mode, Hessian, Laplace MDD, proposal-scale pilot, gate G7.
%
%   est_01_mode_re()
%
%   Mode: csminwel (hlest.csminwel) in the logistic-transformed space from the swX1 mode, with
%   the initial inverse Hessian from Dynare's swX1 Hessian (transformed), then a restart from
%   the result. Hessian of minus the log posterior by central differences in the original
%   space (hlest.hessian_fd, steps 1e-3 max(|x|, 0.05)). Laplace MDD (hlest.mdd_laplace).
%   Pilot: 1,000 draws at three scales, then 2,000 at the interpolated scale for 25-30%.
%   Writes results/estimation/re/mode.mat (xm, lp, ll, lpr, H, Sigma, laplace, swX1 values
%   under the new conventions), re/pilot.mat (scale, acceptance), re/mode_params.csv, and the
%   G7 line of results/estimation/gates.txt.

c = setup_est();
maxNumCompThreads(c.threads);
odir = fullfile(c.results, 're');
diary(fullfile(c.results, 'logs', 'mode_re_diary.txt'));
cl = onCleanup(@() diary('off'));
tAll = tic;
pb = hlest.problem('re');
lb = pb.lb;
ub = pb.ub;
x0 = pb.tab.x0;
[lp0, ll0, lpr0] = hlest.logpost(pb, x0);
fprintf('swX1 under the new conventions: log posterior %.6f, log likelihood %.6f, log prior %.6f\n', lp0, ll0, lpr0);
G = load(fullfile(c.results, 'gates', 'g0_dynare.mat'), 'hh');
u0 = hlest.transform('u', x0, lb, ub);
J = hlest.transform('dxdu', u0, lb, ub);
Hu = diag(J)*G.hh*diag(J);
Hu = (Hu + Hu')/2;
[~, p] = chol(Hu);
if p == 0
    H0 = inv(Hu);
else
    H0 = 1e-4*eye(pb.n);
end
fu = @(u) negpost(pb, hlest.transform('x', u, lb, ub));
copt = struct('log', @(s) fprintf('%s\n', s), 'checkpoint', @(u, f, it) ...
    save(fullfile(odir, 'mode_progress.mat'), 'u', 'f', 'it'));
t1 = tic;
[fh, uh, ~, Hinv, it1, fc1, rc1] = hlest.csminwel(fu, u0, H0, 1e-7, 300, copt);
[fh2, uh2, ~, ~, it2, fc2, rc2] = hlest.csminwel(fu, uh, Hinv, 1e-7, 100, copt);
if fh2 > fh
    uh2 = uh;
    fh2 = fh;
end
tMode = toc(t1);
xm = hlest.transform('x', uh2, lb, ub);
[lp, ll, lpr] = hlest.logpost(pb, xm);
fprintf('RE mode: log posterior %.6f (swX1 %.6f), %d + %d iterations, %d + %d evaluations, %.0f s, retcodes %d %d\n', ...
    lp, lp0, it1, it2, fc1, fc2, tMode, rc1, rc2);
% Hessian
t2 = tic;
h0 = 1e-3*max(abs(xm), 0.05);
f = @(x) deal(-hlest.logpost(pb, x), '');
[H, hinfo] = hlest.hessian_fd('full', f, xm, h0, lb, ub);
tHess = toc(t2);
[lap, linfo] = hlest.mdd_laplace(lp, H);
Hp = nearest_pd(H);
Sigma = inv(Hp);
Sigma = (Sigma + Sigma')/2;
fprintf('Hessian %.0f s: PD %d, min eig %.3g; Laplace log MDD %.4f\n', tHess, hinfo.pd, hinfo.min_eig, lap);
M = struct('xm', xm, 'names', {pb.tab.name}, 'lp', lp, 'll', ll, 'lpr', lpr, 'H', H, 'Sigma', Sigma, ...
    'laplace', lap, 'laplace_info', linfo, 'hess_info', hinfo, 'h', h0, 'x_swx1', x0, 'lp_swx1', lp0, ...
    'll_swx1', ll0, 'lpr_swx1', lpr0, 'lb', lb, 'ub', ub, 'time_mode_s', tMode, 'time_hess_s', tHess, ...
    'iterations', [it1 it2], 'fcount', [fc1 fc2], 'retcodes', [rc1 rc2], 'kind', 're', ...
    'created', datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
save(fullfile(odir, 'mode.mat'), '-struct', 'M');
% parameter table
sd = sqrt(diag(Sigma));
Tt = table(pb.tab.name, x0, xm, sd, xm - x0, (xm - x0)./sd, 'VariableNames', ...
    {'name', 'swx1_mode', 're_mode', 're_sd_hessian', 'change', 'change_in_sd'});
writetable(Tt, fullfile(odir, 'mode_params.csv'));
% pilot for the proposal scale
target = @(x) tgt(pb, x);
L = chol(Sigma, 'lower');
sc = [0.25 0.35 0.45];
acc = zeros(size(sc));
for k = 1:numel(sc)
    rs = RandStream('mt19937ar', 'Seed', 900 + k);
    st = struct('x', xm, 'lp', lp, 'll', ll, 'ev', [], 'paths', [], 'n_done', 0);
    B = hlest.rwmh_core(target, st, L, sc(k), 1000, rs, 50, false);
    acc(k) = mean(B.acc);
    fprintf('pilot scale %.3f: acceptance %.3f\n', sc(k), acc(k));
end
scale = pick_scale(sc, acc, 0.275);
rs = RandStream('mt19937ar', 'Seed', 909);
st = struct('x', xm, 'lp', lp, 'll', ll, 'ev', [], 'paths', [], 'n_done', 0);
B = hlest.rwmh_core(target, st, L, scale, 2000, rs, 50, false);
accF = mean(B.acc);
fprintf('pilot 2000 draws at scale %.4f: acceptance %.3f\n', scale, accF);
scale2000 = scale;
if accF < 0.25 || accF > 0.30
    % refit log acceptance on the scale with every pilot point (the 2,000-draw one counted twice)
    scale = pick_scale([sc, scale, scale], [acc, accF, accF], 0.275);
    fprintf('scale refitted to %.4f\n', scale);
end
Pl = struct('scale', scale, 'scales_tried', [sc, scale2000], 'acc_tried', [acc, accF], 'acc_2000', accF);
save(fullfile(odir, 'pilot.mat'), '-struct', 'Pl');
% G7
[~, ord] = sort(abs((xm - x0)./sd), 'descend');
top = pb.tab.name(ord(1:8));
txt = sprintf(['RE re-estimation sanity: mode log posterior %.4f vs swX1 %.4f under the new likelihood (gain %.4f); ' ...
    'largest moves in posterior sd: %s; eb/ea/ew ranks %s'], lp, lp0, lp - lp0, ...
    strjoin(cellfun(@(n, v) sprintf('%s %.2f', n, v), top', num2cell((xm(ord(1:8)) - x0(ord(1:8)))'./sd(ord(1:8))'), ...
    'UniformOutput', false), ', '), mat2str(arrayfun(@(n) find(strcmp(pb.tab.name(ord), n)), {'eb', 'ea', 'ew'})));
pass = lp > lp0;
fid = fopen(fullfile(c.results, 'gates.txt'), 'a');
fprintf(fid, '\n# est_01_mode_re %s\nG7 %s  %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), ternary(pass, 'PASS', 'FAIL'), txt); %#ok<TNOW1,DATST>
fclose(fid);
fprintf('G7 %s  %s\n', ternary(pass, 'PASS', 'FAIL'), txt);
fprintf('est_01_mode_re done in %.0f s\n', toc(tAll));
end


function f = negpost(pb, x)
f = -hlest.logpost(pb, x);
if ~isfinite(f)
    f = 1e10;
end
end


function [lp, ll, ex] = tgt(pb, x)
[lp, ll] = hlest.logpost(pb, x);
ex = struct('ev', [], 'paths', []);
end


function s = pick_scale(sc, acc, target)
% log acceptance is close to linear in the scale over this range; interpolate
pfit = polyfit(sc, log(max(acc, 1e-3)), 1);
s = (log(target) - pfit(2))/pfit(1);
if ~isfinite(s) || s <= 0
    [~, k] = min(abs(acc - target));
    s = sc(k);
end
s = min(max(s, 0.05), 1.5);
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


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
