function S = est_06b_app1_post(mode, varargin)
%EST_06B_APP1_POST  Application 1 consistent with the likelihood, with posterior bands; share sensitivity.
%
%   est_06b_app1_post('interim')     % learning chains still running: completed blocks only (labelled interim)
%   est_06b_app1_post('final')       % every learning chain of the chosen stage finished
%   est_06b_app1_post('modes')       % at the two modes; no learning chain is read (the MCMC is paused)
%   est_06b_app1_post(mode, 'draws', 'stage2', 'n_post', 200, 'parts', {'post', 'sens'}, 'min_age_s', 120)
%
%   'modes' (2026-10-20): part 'post' writes the same two files at the modes (statistic 'mode') and
%   reads no learning chain: the learning model's median and band columns are NaN (n_draws 0).
%   Option 're_post' (default true): the RE model also gets its posterior (median, p05, p95 over
%   n_post thinned draws of the finished, converged RE chains, exactly as in 'interim'/'final'), so
%   the page can say where the RE mode sits in the RE posterior. Part 'sens' is unchanged (it is at
%   the learning mode in every mode). Status 'modes', learn_draws 0, draws 'none'.
%
%   Forecast from the 2022Q2 origin, 2022Q3-2026Q2, zero shocks, starting from what the estimated
%   model itself says about the origin: hlest.forecast_learn (learning filter of the likelihood up
%   to the origin, then the engine's forecast stage; gate G8) and hlest.forecast_re (RE filter,
%   RE law of motion). Both check at every theta that their history up to the origin is the
%   likelihood's own filtered path (data after the origin cannot matter).
%
%   Part 'post': at the RE mode and the learning mode, and at n_post (200) thinned posterior draws
%   of each model: RE from the finished RE chains (re/chains, second half of every chain);
%   learning from 'draws' = 'stage1' (learn/chains, second half; with 'interim' only the
%   completed blocks, read with hlest.read_blocks, never state.mat) or 'stage2' (learn/chains2,
%   first 10% of every chain dropped, stage 1 treated as adaptation). Thinning: evenly spaced
%   over the pooled post burn-in draws. Writes tables/app1_post_long.csv (variable, date,
%   model = data | re | learn, statistic = value (data) | mode | median | p05 | p95, value;
%   2018Q1-2026Q2; the seven observables in report units (inflation, rate and growth rates in %
%   annualised, hours 100 x log), and for the learning model n2 (learners' share at the end of
%   the quarter), n2_model (share in force), alpha, beta, pmean, fRE, fBR (annualised levels),
%   fRE for RE; plus rows avg_<obs> (date 2022Q3-2026Q2: the average over the horizon, computed
%   per draw) and n2_origin (date 2022Q2)) and tables/app1_post_summary.csv (one row per model:
%   average annualised inflation 2022Q3-2026Q2 at the mode, posterior median and 90% band; the
%   learners' share at the origin; draws used and failed; which draws).
%
%   Part 'sens': the learners' share at 2021Q2, 2021Q4 and 2022Q2 at the learning mode under five
%   histories: the likelihood filter (baseline), the engine's inversion (e1_learn) and RE-smoothed
%   (e1_learn_smoothed) histories (results/estimation/app1/<id>/results.mat, written by
%   est_06_post part app1, checked against the learning mode), the 'freeze' variant (no updating in
%   the quarters without data; its log likelihood is checked against learn/robust.mat), and the
%   filter with the 2020Q1-Q3 observations put back (values from models/sw07/data/
%   sw_ext_1966_latest.csv, the raw panel; the project database is not changed; a likelihood-free
%   what-if at the mode). Writes tables/share_sensitivity.csv with the share in 2019Q4 and 2020Q4,
%   the RE agents' and learners' forecasts made in 2020Q4, the forecast's average inflation, and
%   one line on each variant.
%
%   Every table also has status (interim | final) and learn_draws (learning draws read, all
%   chains, before burn-in). One thread (maxNumCompThreads(1)); about 5 minutes for 200 + 200
%   draws while six chains run.

if nargin < 1 || isempty(mode)
    mode = 'interim';
end
if ~any(strcmp(mode, {'interim', 'final', 'modes'}))
    error('est_06b_app1_post:mode', 'mode must be ''interim'', ''final'' or ''modes''.');
end
modes = strcmp(mode, 'modes');
ip = inputParser;
ip.addParameter('draws', 'stage1');
ip.addParameter('n_post', 200);
ip.addParameter('parts', {'post', 'sens'});
ip.addParameter('min_age_s', 120);
ip.addParameter('max_blocks', Inf);     % interim: read at most this many blocks per learning chain
ip.addParameter('re_post', true);       % 'modes' only: also the RE posterior from the finished RE chains
ip.parse(varargin{:});
o = ip.Results;
parts = cellstr(o.parts);
tAll = tic;
c = setup_est();
maxNumCompThreads(c.threads_learn);
addpath(fullfile(c.est_dir, 'scenarios'));
tdir = fullfile(c.results, 'tables');
final = strcmp(mode, 'final');
fprintf('est_06b_app1_post(''%s'', draws %s) started %s\n', mode, ternary(modes, 'none', o.draws), ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS')); %#ok<TNOW1,DATST>
pbR = hlest.problem('re');
pbL = hlest.problem('learn');
MR = load(fullfile(c.results, 're', 'mode.mat'));
ML = load(fullfile(c.results, 'learn', 'mode.mat'));
Q = qlabels(pbL.nT);
X = struct('c', c, 'o', o, 'mode', mode, 'tdir', tdir, 'pbR', pbR, 'pbL', pbL, 'MR', MR, 'ML', ML, 'Q', {Q});

% learning draws (also labels the tables)
if modes
    XL = [];
    X.G = struct('status', 'modes', 'learn_draws', 0, 'draws', 'none');
    X.lab = 'posterior modes only (no draws; the MCMC is paused)';
else
    switch o.draws
        case 'stage1'
            ldir = fullfile(c.results, 'learn', 'chains');
            burnL = 0.5;
            lab = 'stage 1 (learn/chains), first 50% of every chain dropped';
        case 'stage2'
            ldir = fullfile(c.results, 'learn', 'chains2');
            burnL = 0.1;
            lab = 'stage 2 (learn/chains2), first 10% of every chain dropped (stage 1 = adaptation)';
        otherwise
            error('est_06b_app1_post:draws', 'draws must be ''stage1'' or ''stage2''.');
    end
    [XL, infoL] = post_draws(ldir, burnL, ternary(final, 0, o.min_age_s), final, o.max_blocks);
    X.G = struct('status', mode, 'learn_draws', sum(infoL.n), 'draws', o.draws);
    X.lab = sprintf('%s; %d chains, %s draws read, %d post burn-in%s', lab, numel(infoL.n), ...
        strjoin(arrayfun(@(x) sprintf('%d', x), infoL.n, 'UniformOutput', false), '/'), size(XL, 1), ...
        ternary(final, '', ' (interim: chains still running)'));
end
fprintf('learning draws: %s\n', X.lab);
S = struct('label', X.lab);
for k = 1:numel(parts)
    t0 = tic;
    switch parts{k}
        case 'post'
            if modes
                S.post = part_post_modes(X);
            else
                S.post = part_post(X, XL);
            end
        case 'sens'
            S.sens = part_sens(X);
        otherwise
            error('est_06b_app1_post:part', 'Unknown part %s.', parts{k});
    end
    fprintf('  %-5s done (%.0f s)\n', parts{k}, toc(t0));
end
fprintf('est_06b_app1_post finished in %.0f s\n', toc(tAll));
end


% =============================================================================================
function P = part_post(X, XL)
c = X.c;
pbR = X.pbR;
pbL = X.pbL;
[XR, infoR] = post_draws(fullfile(c.results, 're', 'chains'), 0.5, 0, true);
fprintf('RE draws: %d chains, %s draws, %d post burn-in\n', numel(infoR.n), mat2str(infoR.n), size(XR, 1));
nP = X.o.n_post;
iR = unique(round(linspace(1, size(XR, 1), nP)));
iL = unique(round(linspace(1, size(XL, 1), nP)));
win = find(strcmp(X.Q, '2018Q1')):pbL.nT;
dq = X.Q(win);
ny = numel(pbL.yl);
nw = numel(win);
% modes
FRm = hlest.forecast_re(pbR, X.MR.xm);
FLm = hlest.forecast_learn(pbL, X.ML.xm);
assert(FRm.ok && FLm.ok, 'app1_post: forecast at a mode failed');
tO = FLm.t_origin;
hz = tO + 1:FLm.t_end;
assert(strcmp(X.Q{tO}, '2022Q2') && FLm.t_end == pbL.nT, 'app1_post: origin 2022Q2 and horizon to 2026Q2 expected');
% RE draws
YR = NaN(numel(iR), ny, nw);
FR = NaN(numel(iR), nw);
avR = NaN(numel(iR), ny);
badR = 0;
chkR = 0;
for k = 1:numel(iR)
    Fk = hlest.forecast_re(pbR, XR(iR(k), :)');
    if ~Fk.ok
        badR = badR + 1;
        continue
    end
    chkR = max(chkR, Fk.check);
    YR(k, :, :) = reshape(Fk.yrep(:, win), 1, ny, nw);
    FR(k, :) = Fk.fRE_rep(win);
    avR(k, :) = mean(Fk.yrep(:, hz), 2)';
end
fprintf('RE: %d draws, %d failed, max history check %.3g\n', numel(iR), badR, chkR);
% learning draws
YL = NaN(numel(iL), ny, nw);
fl = {'n2', 'n2_model', 'alpha', 'beta', 'pmean', 'fRE_rep', 'fBR_rep'};
A = struct();
for q = 1:numel(fl)
    A.(fl{q}) = NaN(numel(iL), nw);
end
avL = NaN(numel(iL), ny);
n2o = NaN(numel(iL), 1);
evF = zeros(numel(iL), 1);
badL = 0;
chkL = 0;
tL = tic;
for k = 1:numel(iL)
    Fk = hlest.forecast_learn(pbL, XL(iL(k), :)');
    if ~Fk.ok
        badL = badL + 1;
        continue
    end
    chkL = max(chkL, Fk.check);
    YL(k, :, :) = reshape(Fk.yrep(:, win), 1, ny, nw);
    for q = 1:numel(fl)
        A.(fl{q})(k, :) = Fk.(fl{q})(win);
    end
    avL(k, :) = mean(Fk.yrep(:, hz), 2)';
    n2o(k) = Fk.n2(tO);
    evF(k) = Fk.n_events_forecast;
    if mod(k, 50) == 0
        fprintf('  learning draw %d of %d (%.0f s)\n', k, numel(iL), toc(tL));
    end
end
fprintf('learning: %d draws, %d failed, max history check %.3g, draws with forecast facility events %d\n', ...
    numel(iL), badL, chkL, nnz(evF > 0));
okR = all(isfinite(avR), 2);
okL = all(isfinite(avL), 2);
% rows
R = {};
spec = pbL.spec;
for i = 1:ny
    v = pbL.yl{i};
    R = [R; rows(v, dq, 'data', 'value', pbL.Y(i, win)*spec.report.scale.(v))]; %#ok<AGROW>
    R = [R; stat_rows(v, dq, 're', FRm.yrep(i, win), squeeze(YR(okR, i, :)))]; %#ok<AGROW>
    R = [R; stat_rows(v, dq, 'learn', FLm.yrep(i, win), squeeze(YL(okL, i, :)))]; %#ok<AGROW>
end
for q = 1:numel(fl)
    nm = strrep(fl{q}, '_rep', '');
    R = [R; stat_rows(nm, dq, 'learn', FLm.(fl{q})(win), A.(fl{q})(okL, :))]; %#ok<AGROW>
end
R = [R; stat_rows('fRE', dq, 're', FRm.fRE_rep(win), FR(okR, :))];
hzl = sprintf('%s-%s', X.Q{hz(1)}, X.Q{hz(end)});
for i = 1:ny
    v = pbL.yl{i};
    R = [R; stat_rows(['avg_' v], {hzl}, 're', mean(FRm.yrep(i, hz)), avR(okR, i))]; %#ok<AGROW>
    R = [R; stat_rows(['avg_' v], {hzl}, 'learn', mean(FLm.yrep(i, hz)), avL(okL, i))]; %#ok<AGROW>
end
R = [R; stat_rows('n2_origin', X.Q(tO), 'learn', FLm.n2(tO), n2o(okL))];
write_long(fullfile(X.tdir, 'app1_post_long.csv'), X.G, 'variable', R(:, 1), 'date', R(:, 2), 'model', R(:, 3), ...
    'statistic', R(:, 4), 'value', cell2mat(R(:, 5)));
% summary
ipo = strcmp(pbL.yl, 'pinfobs');
qR = quantiles(avR(okR, ipo), [0.5 0.05 0.95]);
qL = quantiles(avL(okL, ipo), [0.5 0.05 0.95]);
qN = quantiles(n2o(okL), [0.5 0.05 0.95]);
T = table();
T.model = {'re'; 'learn'};
T.avg_inflation_mode = [FRm.avg_pinf; FLm.avg_pinf];
T.avg_inflation_median = [qR(1); qL(1)];
T.avg_inflation_p05 = [qR(2); qL(2)];
T.avg_inflation_p95 = [qR(3); qL(3)];
T.n2_origin_mode = [NaN; FLm.n2(tO)];
T.n2_origin_median = [NaN; qN(1)];
T.n2_origin_p05 = [NaN; qN(2)];
T.n2_origin_p95 = [NaN; qN(3)];
T.n_draws = [nnz(okR); nnz(okL)];
T.n_failed = [numel(iR) - nnz(okR); numel(iL) - nnz(okL)];
T.max_history_check = [chkR; chkL];
T.draws_label = {sprintf('RE chains (re/chains), %d chains x %d draws, first 50%% dropped, %d thinned', numel(infoR.n), ...
    infoR.n(1), numel(iR)); sprintf('%s; %d thinned', X.lab, numel(iL))};
T.horizon = {hzl; hzl};
T.status = {X.G.status; X.G.status};
T.learn_draws = [X.G.learn_draws; X.G.learn_draws];
T.draws = {X.G.draws; X.G.draws};            % which learning draws: stage1 | stage2 (as every table)
writetable(T, fullfile(X.tdir, 'app1_post_summary.csv.tmp'), 'FileType', 'text', 'Delimiter', ',', 'QuoteStrings', 'all');
movefile(fullfile(X.tdir, 'app1_post_summary.csv.tmp'), fullfile(X.tdir, 'app1_post_summary.csv'), 'f');
fprintf(['app1 (likelihood-consistent): average inflation %s: RE mode %.3f, median %.3f [%.3f, %.3f]; learning mode %.3f, ' ...
    'median %.3f [%.3f, %.3f]; learners'' share at the origin: mode %.3f, median %.3f [%.3f, %.3f]\n'], hzl, ...
    FRm.avg_pinf, qR, FLm.avg_pinf, qL, FLm.n2(tO), qN);
P = struct('summary', T, 'checks', [chkR, chkL]);
end


% =============================================================================================
function P = part_post_modes(X)
% Part 'post' at the two modes (statistic 'mode'), reading no learning chain. With X.o.re_post the RE
% model also gets the median, p05 and p95 over n_post thinned draws of the finished RE chains, computed
% exactly as in part_post (re/chains, second half of every chain, evenly spaced thinning).
pbR = X.pbR;
pbL = X.pbL;
win = find(strcmp(X.Q, '2018Q1')):pbL.nT;
dq = X.Q(win);
ny = numel(pbL.yl);
FRm = hlest.forecast_re(pbR, X.MR.xm);
FLm = hlest.forecast_learn(pbL, X.ML.xm);
assert(FRm.ok && FLm.ok, 'app1_post: forecast at a mode failed');
tO = FLm.t_origin;
hz = tO + 1:FLm.t_end;
assert(strcmp(X.Q{tO}, '2022Q2') && FLm.t_end == pbL.nT, 'app1_post: origin 2022Q2 and horizon to 2026Q2 expected');
assert(abs(FLm.ll_full - X.ML.ll) < 1e-8, 'app1_post: learning filter log likelihood %.10f vs the mode %.10f', ...
    FLm.ll_full, X.ML.ll);
% RE posterior (finished RE chains only)
nw = numel(win);
reP = X.o.re_post;
chkR = 0;
if reP
    [XR, infoR] = post_draws(fullfile(X.c.results, 're', 'chains'), 0.5, 0, true);
    iR = unique(round(linspace(1, size(XR, 1), X.o.n_post)));
    YR = NaN(numel(iR), ny, nw);
    FR = NaN(numel(iR), nw);
    avR = NaN(numel(iR), ny);
    for k = 1:numel(iR)
        Fk = hlest.forecast_re(pbR, XR(iR(k), :)');
        if ~Fk.ok
            continue
        end
        chkR = max(chkR, Fk.check);
        YR(k, :, :) = reshape(Fk.yrep(:, win), 1, ny, nw);
        FR(k, :) = Fk.fRE_rep(win);
        avR(k, :) = mean(Fk.yrep(:, hz), 2)';
    end
    okR = all(isfinite(avR), 2);
    fprintf('RE posterior: %d chains, %s draws, %d post burn-in, %d thinned, %d failed, max history check %.3g\n', ...
        numel(infoR.n), mat2str(infoR.n), size(XR, 1), numel(iR), numel(iR) - nnz(okR), chkR);
end
fl = {'n2', 'n2_model', 'alpha', 'beta', 'pmean', 'fRE_rep', 'fBR_rep'};
R = {};
spec = pbL.spec;
for i = 1:ny
    v = pbL.yl{i};
    R = [R; rows(v, dq, 'data', 'value', pbL.Y(i, win)*spec.report.scale.(v))]; %#ok<AGROW>
    if reP
        R = [R; stat_rows(v, dq, 're', FRm.yrep(i, win), squeeze(YR(okR, i, :)))]; %#ok<AGROW>
    else
        R = [R; rows(v, dq, 're', 'mode', FRm.yrep(i, win))]; %#ok<AGROW>
    end
    R = [R; rows(v, dq, 'learn', 'mode', FLm.yrep(i, win))]; %#ok<AGROW>
end
for q = 1:numel(fl)
    R = [R; rows(strrep(fl{q}, '_rep', ''), dq, 'learn', 'mode', FLm.(fl{q})(win))]; %#ok<AGROW>
end
if reP
    R = [R; stat_rows('fRE', dq, 're', FRm.fRE_rep(win), FR(okR, :))];
else
    R = [R; rows('fRE', dq, 're', 'mode', FRm.fRE_rep(win))];
end
hzl = sprintf('%s-%s', X.Q{hz(1)}, X.Q{hz(end)});
for i = 1:ny
    v = pbL.yl{i};
    if reP
        R = [R; stat_rows(['avg_' v], {hzl}, 're', mean(FRm.yrep(i, hz)), avR(okR, i))]; %#ok<AGROW>
    else
        R = [R; rows(['avg_' v], {hzl}, 're', 'mode', mean(FRm.yrep(i, hz)))]; %#ok<AGROW>
    end
    R = [R; rows(['avg_' v], {hzl}, 'learn', 'mode', mean(FLm.yrep(i, hz)))]; %#ok<AGROW>
end
R = [R; rows('n2_origin', X.Q(tO), 'learn', 'mode', FLm.n2(tO))];
write_long(fullfile(X.tdir, 'app1_post_long.csv'), X.G, 'variable', R(:, 1), 'date', R(:, 2), 'model', R(:, 3), ...
    'statistic', R(:, 4), 'value', cell2mat(R(:, 5)));
% summary: the columns of part_post; posterior statistics for RE only (with re_post)
qR = [NaN NaN NaN];
nR = 0;
fR = 0;
labR = 'RE mode (re/mode.mat); no RE draws (re_post false)';
if reP
    ipo = strcmp(pbL.yl, 'pinfobs');
    qR = quantiles(avR(okR, ipo), [0.5 0.05 0.95])';
    nR = nnz(okR);
    fR = numel(iR) - nR;
    labR = sprintf(['RE chains (re/chains, finished and converged), %d chains x %d draws, first 50%% dropped, ' ...
        '%d thinned'], numel(infoR.n), infoR.n(1), numel(iR));
end
T = table();
T.model = {'re'; 'learn'};
T.avg_inflation_mode = [FRm.avg_pinf; FLm.avg_pinf];
T.avg_inflation_median = [qR(1); NaN];
T.avg_inflation_p05 = [qR(2); NaN];
T.avg_inflation_p95 = [qR(3); NaN];
T.n2_origin_mode = [NaN; FLm.n2(tO)];
T.n2_origin_median = [NaN; NaN];
T.n2_origin_p05 = [NaN; NaN];
T.n2_origin_p95 = [NaN; NaN];
T.n_draws = [nR; 0];
T.n_failed = [fR; 0];
T.max_history_check = [max(FRm.check, chkR); FLm.check];
T.draws_label = {labR; 'learning mode (learn/mode.mat); no learning draws, the MCMC is paused'};
T.horizon = {hzl; hzl};
T.status = {X.G.status; X.G.status};
T.learn_draws = [X.G.learn_draws; X.G.learn_draws];
T.draws = {X.G.draws; X.G.draws};
writetable(T, fullfile(X.tdir, 'app1_post_summary.csv.tmp'), 'FileType', 'text', 'Delimiter', ',', 'QuoteStrings', 'all');
movefile(fullfile(X.tdir, 'app1_post_summary.csv.tmp'), fullfile(X.tdir, 'app1_post_summary.csv'), 'f');
fprintf(['app1 (likelihood-consistent, modes): average inflation %s: RE mode %.3f (RE posterior median %.3f ' ...
    '[%.3f, %.3f], %d draws), learning mode %.3f; learners'' share at the origin %.3f; history checks %.3g (RE), ' ...
    '%.3g (learning)\n'], hzl, FRm.avg_pinf, qR, nR, FLm.avg_pinf, FLm.n2(tO), max(FRm.check, chkR), FLm.check);
P = struct('summary', T, 'checks', [max(FRm.check, chkR), FLm.check]);
end


% =============================================================================================
function T = part_sens(X)
c = X.c;
pbL = X.pbL;
ML = X.ML;
th = ML.xm;
qs = {'2019Q4', '2020Q4', '2021Q2', '2021Q4', '2022Q2'};
ix = cellfun(@(q) find(strcmp(X.Q, q)), qs);
i20 = find(strcmp(X.Q, '2020Q4'));
cm = th(strcmp(pbL.tab.name, 'constepinf'));
V = struct('variant', {}, 'label', {}, 'n2', {}, 'fRE20', {}, 'fBR20', {}, 'avg', {}, 'll', {}, 'beta', {}, 'pmean', {}, ...
    'why', {});
tO = find(strcmp(X.Q, '2022Q2'));
ipo = strcmp(pbL.yl, 'pinfobs');
pi21 = 4*pbL.Y(ipo, strcmp(X.Q, '2021Q1'));      % inflation in 2021Q1, % annualised (data)
% (1) likelihood filter
F1 = hlest.forecast_learn(pbL, th);
assert(abs(F1.ll_full - ML.ll) < 1e-8, 'sens: filter log likelihood at the mode');
V(end+1) = mk('filter', 'Likelihood filter (baseline)', F1.n2(ix), F1.fRE_rep(i20), F1.fBR_rep(i20), F1.avg_pinf, F1.ll_full, ...
    F1.beta(tO), F1.pmean(tO));
% (2), (3) engine histories (est_06_post part app1)
for e = {{'inversion', 'e1_learn', 'Engine inversion history (e1_learn)'}, ...
        {'re_smoother', 'e1_learn_smoothed', 'Engine RE-smoothed history (e1_learn_smoothed)'}}
    f = fullfile(c.results, 'app1', e{1}{2}, 'results.mat');
    for tr = 1:3                 % est_06_post part app1 may be rewriting the file in a parallel run
        try
            Sx = load(f);
            break
        catch err
            if tr == 3
                rethrow(err);
            end
            pause(30);
        end
    end
    if isfield(Sx, 'res')
        res = Sx.res;
    else
        fn = fieldnames(Sx);
        res = Sx.(fn{1});
    end
    o = res.cfg;
    assert(abs(o.gain.value - th(37)) < 1e-15 && abs(o.switching.memory - th(38)) < 1e-15 && ...
        abs(o.switching.intensity - th(39)) < 1e-15 && strcmp(o.history.mode, e{1}{1}), ...
        'sens: %s was not run at the learning mode with history %s; rerun est_06_post(mode, ''parts'', {''app1''})', ...
        e{1}{2}, e{1}{1});
    Lg = res.learning.pinf;
    dts = qq(1965, 1) + ix - 1;
    n2 = reshape(Lg.n2(dts), 1, []);
    d20 = qq(1965, 1) + i20 - 1;
    dO = qq(2022, 2);
    hz = qq(2022, 3):qq(2026, 2);
    avg = mean(res.paths.pinfobs(hz))*pbL.spec.report.scale.pinfobs;
    al = Lg.alpha_pinf(dO);
    be = Lg.beta_pinf(dO);
    V(end+1) = mk(e{1}{1}, e{1}{3}, n2, 4*(Lg.fRE(d20) + cm), 4*(Lg.fBR(d20) + cm), avg, NaN, be, ...
        4*(al/(1 - be) + cm)); %#ok<AGROW>
end
% (4) freeze
RB = load(fullfile(c.results, 'learn', 'robust.mat'));
pbZ = hlest.problem('learn', 'gap', 'freeze');
F4 = hlest.forecast_learn(pbZ, th);
assert(abs(F4.ll_full - RB.d_ll) < 1e-8, 'sens: freeze log likelihood %.8f differs from learn/robust.mat %.8f', F4.ll_full, RB.d_ll);
V(end+1) = mk('freeze', '''freeze'': no updating without data (learn/robust.mat)', F4.n2(ix), F4.fRE_rep(i20), ...
    F4.fBR_rep(i20), F4.avg_pinf, F4.ll_full, F4.beta(tO), F4.pmean(tO));
% (5) the 2020Q1-Q3 observations put back (raw panel, not the project database)
raw = readtable(fullfile(c.project, 'models', 'sw07', 'data', 'sw_ext_1966_latest.csv'), 'TextType', 'string');
assert(height(raw) == pbL.nT && raw.date(1) == "1965Q1", 'sens: raw panel layout');
Yr = NaN(size(pbL.Y));
for i = 1:numel(pbL.yl)
    Yr(i, :) = raw.(pbL.yl{i})';
end
ok = isfinite(pbL.Y);
dRaw = max(abs(Yr(ok) - pbL.Y(ok)));
assert(dRaw < 1e-12, 'sens: the raw panel differs from the database outside the covid quarters (%.3g)', dRaw);
cq = find(any(~ok, 1));
assert(isequal(X.Q(cq), {'2020Q1', '2020Q2', '2020Q3'}), 'sens: missing quarters other than 2020Q1-Q3');
pbC = pbL;
pbC.Y(:, cq) = Yr(:, cq);
pbC.obs = isfinite(pbC.Y);
F5 = hlest.forecast_learn(pbC, th);
V(end+1) = mk('covid_data', 'Filter with the 2020Q1-Q3 data put back (what-if)', F5.n2(ix), F5.fRE_rep(i20), ...
    F5.fBR_rep(i20), F5.avg_pinf, NaN, F5.beta(tO), F5.pmean(tO));
% one line each on why they differ
b = V(1);
V(1).why = sprintf(['Learners update on the filtered values through the gap. In 2020Q4 the Kalman gain spreads the catch-up ' ...
    'over the uncertain state, so the RE agents'' forecast made in 2020Q4 is %.2f%% (2021Q1 inflation: %.2f%%); with chi = %.1f ' ...
    'their smaller errors in 2021 cut the learners'' share from %.2f at the end of 2020Q4 to %.2f in 2021Q4 (%.2f at the origin).'], ...
    b.fRE20, pi21, th(39), b.n2(2), b.n2(4), b.n2(5));
V(2).why = sprintf(['The 2020Q4 observations are matched exactly by that quarter''s shocks, so the state jumps: the RE agents'' ' ...
    'forecast made in 2020Q4 is %.2f%% (filter %.2f%%), they miss the 2021Q1 rise by %.1f pp instead of %.1f pp, and the ' ...
    'learners'' share stays at %.2f-%.2f in 2021Q2-%s.'], V(2).fRE20, b.fRE20, abs(pi21 - V(2).fRE20), abs(pi21 - b.fRE20), ...
    min(V(2).n2(3:5)), max(V(2).n2(3:5)), qs{5});
V(3).why = sprintf(['Learning on the two-sided RE smoother, which also spreads the 2020Q4 surprise (and uses data to 2026Q2): ' ...
    'the RE agents'' 2020Q4 forecast is %.2f%% and the share %.2f at the origin, close to the filter.'], V(3).fRE20, V(3).n2(5));
V(4).why = sprintf(['No updating in 2020Q1-Q3: beliefs, fitness and shares stay at their 2019Q4 values (share %.2f) instead of ' ...
    'learning from the filter''s predictions; with the same 2020Q4-2022Q2 data the share ends at %.2f at the origin (baseline ' ...
    '%.2f).'], V(4).n2(1), V(4).n2(5), b.n2(5));
V(5).why = sprintf(['With the 2020 collapse and rebound observed the RE agents miss those swings by more than the learners, and the ' ...
    'learners'' share is %.2f at the end of 2020Q4 (filter %.2f); the 2021-22 errors bring it down to %.2f at the origin. The ' ...
    'filtered state at the origin differs too (the 2020 observations enter every later estimate), and the forecast averages ' ...
    '%.2f%% (filter %.2f%%); the perceived persistence is %.3f against %.3f.'], ...
    V(5).n2(2), b.n2(2), V(5).n2(5), V(5).avg, b.avg, V(5).beta, b.beta);
T = table();
T.variant = {V.variant}';
T.label = {V.label}';
for j = 1:numel(qs)
    T.(['n2_' qs{j}]) = arrayfun(@(v) v.n2(j), V)';
end
T.fRE_made_2020Q4 = [V.fRE20]';
T.fBR_made_2020Q4 = [V.fBR20]';
T.beta_2022Q2 = [V.beta]';
T.pmean_2022Q2 = [V.pmean]';
T.avg_inflation_2022Q3_2026Q2 = [V.avg]';
T.log_likelihood = [V.ll]';
T.why = {V.why}';
T.status = repmat({X.G.status}, height(T), 1);
T.learn_draws = repmat(X.G.learn_draws, height(T), 1);
T.draws = repmat({X.G.draws}, height(T), 1);
writetable(T, fullfile(X.tdir, 'share_sensitivity.csv.tmp'), 'FileType', 'text', 'Delimiter', ',', 'QuoteStrings', 'all');
movefile(fullfile(X.tdir, 'share_sensitivity.csv.tmp'), fullfile(X.tdir, 'share_sensitivity.csv'), 'f');
for k = 1:height(T)
    fprintf('  %-12s n2 2021Q2 %.3f 2021Q4 %.3f 2022Q2 %.3f | fRE(2020Q4) %.2f | beta %.3f pmean %.2f | avg inflation %.3f\n', ...
        T.variant{k}, T.n2_2021Q2(k), T.n2_2021Q4(k), T.n2_2022Q2(k), T.fRE_made_2020Q4(k), T.beta_2022Q2(k), ...
        T.pmean_2022Q2(k), T.avg_inflation_2022Q3_2026Q2(k));
    fprintf('     %s\n', T.why{k});
end
end


function v = mk(variant, label, n2, fRE20, fBR20, avg, ll, beta, pmean)
v = struct('variant', variant, 'label', label, 'n2', reshape(n2, 1, []), 'fRE20', fRE20, 'fBR20', fBR20, 'avg', avg, ...
    'll', ll, 'beta', beta, 'pmean', pmean, 'why', '');
end


% =============================================================================================
function [X, info] = post_draws(base, burn, minAge, needDone, maxBlocks)
% Pooled post burn-in draws of every chain folder under base (completed blocks only).
dd = dir(fullfile(base, 'chain_*'));
dd = dd([dd.isdir]);
Xc = {};
info = struct('n', [], 'names', {{}});
for k = 1:numel(dd)
    cdir = fullfile(dd(k).folder, dd(k).name);
    [tgt, st] = progress_of(cdir);
    age = minAge;
    if strcmp(st, 'done')
        age = 0;
    end
    C = hlest.read_blocks(cdir, false, age);
    if nargin >= 5 && C.nblocks > maxBlocks
        n = maxBlocks*size(C.draws, 1)/C.nblocks;
        C.draws = C.draws(1:n, :);
        C.n = n;
        C.nblocks = maxBlocks;
    end
    if needDone && (~strcmp(st, 'done') || C.n < tgt)
        error('est_06b_app1_post:final', 'chain %s is not complete (%d of %d draws, status %s); use ''interim''.', ...
            cdir, C.n, tgt, st);
    end
    if C.nblocks < 2
        continue
    end
    h = floor(burn*C.n);
    Xc{end+1} = C.draws(h+1:end, :); %#ok<AGROW>
    info.n(end+1) = C.n;
    info.names{end+1} = dd(k).name;
end
if numel(Xc) < 2
    error('est_06b_app1_post:chains', 'Fewer than 2 chains with 2 or more completed blocks in %s.', base);
end
X = vertcat(Xc{:});
end


function [tgt, st] = progress_of(cdir)
tgt = NaN;
st = '';
f = fullfile(cdir, 'progress.txt');
if exist(f, 'file') ~= 2
    return
end
try
    txt = fileread(f);
catch
    return
end
t = regexp(txt, 'ndraws = (\d+)', 'tokens', 'once');
if ~isempty(t)
    tgt = str2double(t{1});
end
t = regexp(txt, 'status = (\w+)', 'tokens', 'once');
if ~isempty(t)
    st = t{1};
end
end


function R = rows(var, dq, model, stat, v)
n = numel(dq);
R = [repmat({var}, n, 1), reshape(dq, [], 1), repmat({model}, n, 1), repmat({stat}, n, 1), num2cell(double(v(:)))];
end


function R = stat_rows(var, dq, model, vmode, M)
% mode, median, p05, p95 by column of M (draws x dates)
if isvector(M) && numel(dq) == 1
    M = M(:);
end
qv = quantiles(M, [0.5 0.05 0.95]);
R = [rows(var, dq, model, 'mode', vmode); rows(var, dq, model, 'median', qv(:, 1)); ...
    rows(var, dq, model, 'p05', qv(:, 2)); rows(var, dq, model, 'p95', qv(:, 3))];
end


function q = quantiles(X, p)
% Column quantiles (linear interpolation, Hazen positions), as est_06_post; NaN-free X.
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
% A long CSV with the given columns plus status, learn_draws and draws (stage1 | stage2).
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
T.status = repmat({G.status}, n, 1);
T.learn_draws = repmat(G.learn_draws, n, 1);
T.draws = repmat({G.draws}, n, 1);
tmp = [file '.tmp'];
writetable(T, tmp, 'FileType', 'text', 'Delimiter', ',', 'QuoteStrings', 'all');
movefile(tmp, file, 'f');
end


function Q = qlabels(nT)
Q = cell(1, nT);
for t = 1:nT
    Q{t} = sprintf('%dQ%d', 1965 + floor((t - 1)/4), mod(t - 1, 4) + 1);
end
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
