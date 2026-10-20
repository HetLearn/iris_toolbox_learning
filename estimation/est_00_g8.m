function R = est_00_g8()
%EST_00_G8  Gate G8: hlest.forecast_learn and hlest.forecast_re reproduce the engine's forecast stage.
%
%   R = est_00_g8()      % about 2 minutes; appends to results/estimation/gates.txt
%
%   The two functions start the application 1 forecast from the estimation filter's own state
%   at the origin (2022Q2) and simulate 2022Q3-2026Q2 with zero shocks. To test the simulation
%   and learning steps against the engine, both are started from the same inputs: the engine
%   runs a scenario (hetlearn.engine.core, as hetlearn.run does before saving), its state at the
%   end of the origin is taken (F.S0: beliefs phi, RLS moments R, fitness zetaRE/zetaBR, discrete-
%   choice share n1, the forecasts made at the origin, the beliefs before the origin's update,
%   the model shares in force and any kept share; F.d0: the predetermined states xb at the
%   origin), the same state is fed to hlest.forecast_learn(..., 'origin_state', S) or
%   hlest.forecast_re(..., 'origin_state', xb), and the 16-quarter paths are compared with the
%   engine's forecast (res.paths, res.learning): the seven observables, pinf, the learners'
%   discrete-choice share n2 and model share n1_model, the beliefs alpha and beta, the forecasts
%   fRE and fBR, and the facility events of the forecast (tolerance 1e-9).
%     (a) a1_learn at the calibration (swX1, gain 0.0585, memory 0.6, intensity 0.51; the
%         engine's RE-smoothed history); (b) e1_learn at the learning posterior mode (inversion
%         history, intensity 6.7, so the shares move); (c) a1_re at swX1 and (d) e1_re at the RE
%         mode against hlest.forecast_re; (e) internal: hlest.forecast_learn from the filter at
%         the learning mode = hlest.forecast_learn restarted from its own origin state (exact),
%         and its history = hlest.loglik_learn on the full sample (the function's 'check').
%   The engine solves every ALM with IRIS (solve, sspace); hlest uses its QZ port (gate G5,
%   about 1e-12), so the paths agree to rounding, not bit for bit.
%   Writes "# est_00_g8 <date> (toolbox root ...)" and one G8 line to gates.txt, details in
%   results/estimation/gates/gates_G8.mat.

c = setup_est();
maxNumCompThreads(c.threads_learn);
addpath(fullfile(c.est_dir, 'scenarios'));
rehash;
t00 = tic;
pbR = hlest.problem('re');
pbL = hlest.problem('learn');
ML = load(fullfile(c.results, 'learn', 'mode.mat'));
MR = load(fullfile(c.results, 're', 'mode.mat'));
xc = pbL.tab.x0;
tol = 1e-9;
cases = {'a1_learn', 'learn', xc, 'calibration'; 'e1_learn', 'learn', ML.xm, 'learning mode'; ...
    'a1_re', 're', xc(1:36), 'swX1'; 'e1_re', 're', MR.xm, 'RE mode'};
R = struct();
txt = {};
pass = true;
for k = 1:size(cases, 1)
    id = cases{k, 1};
    cfg = feval(id);
    cfg.compare_with = {};
    if strcmp(id, 'e1_learn')
        assert(abs(cfg.gain.value - ML.xm(37)) < 1e-15 && abs(cfg.switching.memory - ML.xm(38)) < 1e-15 && ...
            abs(cfg.switching.intensity - ML.xm(39)) < 1e-15, 'G8: e1_learn.m does not hold the learning mode');
    end
    [res, Fe] = engine_core(cfg);
    org = Fe.ctx.origin;
    hz = Fe.ctx.horizon;
    pb = pbL;
    if strcmp(cases{k, 2}, 're')
        pb = pbR;
    end
    xb = xb_at(Fe.d0, pb.xb, org);
    if strcmp(cases{k, 2}, 'learn')
        S0 = Fe.S0;
        keep = [];
        if isfield(S0, 'n1m_keep') && isstruct(S0.n1m_keep)
            keep = S0.n1m_keep.pinf;
        end
        st = struct('a', xb, 'phi', S0.phi.pinf(:), 'R', S0.R.pinf, 'zRE', S0.zetaRE, 'zBR', S0.zetaBR, ...
            'n1', S0.n1, 'fRE', S0.fRE.pinf, 'fBR', S0.fBR.pinf, 'n1m_keep', keep, 'prev_phi', S0.prev.phi.pinf(:), ...
            'prev_R', S0.prev.R.pinf, 'n1m_last', S0.n1m_last.pinf);
        Fh = hlest.forecast_learn(pb, cases{k, 3}, 'origin_state', st, 'check', false);
    else
        Fh = hlest.forecast_re(pb, cases{k, 3}, 'origin_state', xb);
    end
    assert(Fh.ok, 'G8 %s: %s', id, Fh.status);
    assert(abs(pb.dates(Fh.t_origin) - double(org)) < 1e-6 && numel(hz) == Fh.horizon, 'G8 %s: origin or horizon', id);
    kk = Fh.t_origin + 1:Fh.t_end;
    d = struct();
    d.obs = 0;
    for i = 1:numel(pb.yl)
        e = reshape(res.paths.(pb.yl{i})(hz), 1, []);
        d.obs = max(d.obs, max(abs(e - Fh.y(i, kk))));
    end
    if strcmp(cases{k, 2}, 'learn')
        Lg = res.learning.pinf;
        g = @(s) reshape(s(hz), 1, []);
        d.pinf = max(abs(g(res.paths.pinf) - Fh.pinf(kk)));
        d.n2 = max(abs(g(Lg.n2) - Fh.n2(kk)));
        d.n1_model = max(abs(g(Lg.n1_model) - (1 - Fh.n2_model(kk))));
        d.alpha = max(abs(g(Lg.alpha_pinf) - Fh.alpha(kk)));
        d.beta = max(abs(g(Lg.beta_pinf) - Fh.beta(kk)));
        d.fRE = max(abs(g(Lg.fRE) - Fh.fRE(kk)));
        d.fBR = max(abs(g(Lg.fBR) - Fh.fBR(kk)));
        evE = {};
        if ~isempty(res.events)
            s = strcmp(res.events.stage, 'forecast') & ismember(res.events.type, ...
                {'projection_plm', 'projection_alm', 'projection_alm_shares'});
            evE = sort(cellstr(res.events.date(s)))';
        end
        evH = {};
        for q = find(Fh.events(1, :) > Fh.t_origin & Fh.events(2, :) <= 3)
            evH{end+1} = Fh.q{Fh.events(1, q)}; %#ok<AGROW>
        end
        evH = sort(evH);
        d.events_equal = isequal(reshape(evE, 1, []), reshape(evH, 1, []));
        dm = max([d.obs, d.pinf, d.n2, d.n1_model, d.alpha, d.beta, d.fRE, d.fBR]);
        ok = dm < tol && d.events_equal;
        txt{end+1} = sprintf(['%s (%s, %s history): observables %.1e, pinf %.1e, n2 %.1e, n1_model %.1e, alpha %.1e, ' ...
            'beta %.1e, fRE %.1e, fBR %.1e; share at the origin %.3f, at 2026Q2 %.3f; forecast events engine {%s} hlest {%s}'], ...
            id, cases{k, 4}, cfg_history(Fe.ctx.opts), d.obs, d.pinf, d.n2, d.n1_model, d.alpha, d.beta, d.fRE, d.fBR, ...
            1 - S0.n1, Fh.n2(end), strjoin(evE, ','), strjoin(evH, ',')); %#ok<AGROW>
    else
        dm = d.obs;
        ok = dm < tol;
        txt{end+1} = sprintf('%s (%s): observables %.1e; average inflation %.4f%%', id, cases{k, 4}, d.obs, Fh.avg_pinf); %#ok<AGROW>
    end
    d.max = dm;
    d.pass = ok;
    pass = pass && ok;
    R.(id) = d;
    fprintf('G8 %s: %s\n', id, txt{end});
end
% (e) internal: restart from the function's own origin state; history = the likelihood's
F1 = hlest.forecast_learn(pbL, ML.xm);
F2 = hlest.forecast_learn(pbL, ML.xm, 'origin_state', F1.origin_state, 'check', false);
kk = F1.t_origin + 1:F1.t_end;
dR = max([max(max(abs(F1.y(:, kk) - F2.y(:, kk)))), max(abs(F1.n2(kk) - F2.n2(kk))), max(abs(F1.n2_model(kk) - F2.n2_model(kk))), ...
    max(abs(F1.alpha(kk) - F2.alpha(kk))), max(abs(F1.beta(kk) - F2.beta(kk))), max(abs(F1.fRE(kk) - F2.fRE(kk))), ...
    max(abs(F1.fBR(kk) - F2.fBR(kk)))]);
F3 = hlest.forecast_re(pbR, MR.xm);
F4 = hlest.forecast_re(pbR, MR.xm, 'origin_state', F3.origin_state);
dR3 = max(max(abs(F3.y(:, F3.t_origin + 1:end) - F4.y(:, F3.t_origin + 1:end))));
okE = dR == 0 && dR3 < 1e-12 && F1.check < 1e-12 && F3.check < 1e-12;
pass = pass && okE;
txt{end+1} = sprintf(['internal: forecast from the filter at the learning mode = restart from its origin state %.1e (RE %.1e); ' ...
    'history = hlest.loglik_learn on the full sample %.1e (RE filter %.1e); likelihood-consistent average inflation ' ...
    '2022Q3-2026Q2 %.4f%% (learning mode, share at the origin %.3f) and %.4f%% (RE mode)'], dR, dR3, F1.check, F3.check, ...
    F1.avg_pinf, F1.n2(F1.t_origin), F3.avg_pinf);
R.internal = struct('d_restart', dR, 'd_restart_re', dR3, 'check_learn', F1.check, 'check_re', F3.check, 'pass', okE);
fprintf('G8 internal: %s\n', txt{end});
R.pass = pass;
R.time_s = toc(t00);
st = 'FAIL';
if pass
    st = 'PASS';
end
line = sprintf(['G8 %s  likelihood-consistent app. 1 forecast (hlest.forecast_learn / forecast_re) vs the engine''s forecast ' ...
    'stage from the same origin state (engine F.S0 and xb of F.d0 fed to hlest), 2022Q3-2026Q2, tol %.0e: %s  [%.0f s]'], ...
    st, tol, strjoin(txt, '; '), R.time_s);
R.line = line;
save(fullfile(c.results, 'gates', 'gates_G8.mat'), 'R');
fid = fopen(fullfile(c.results, 'gates.txt'), 'a');
fprintf(fid, '\n# est_00_g8 %s (toolbox root %s)\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'), c.toolbox_root); %#ok<TNOW1,DATST>
fprintf(fid, '%s\n', line);
fclose(fid);
fprintf('%s\n', line);
end


function [res, F] = engine_core(cfg)
% hetlearn.run up to the engine core (no density, no saving), returning the forecast bundle F.
opts = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(opts.model);
[m, info] = hetlearn.load_model(spec, opts);
if logical(opts.history.realtime) && strcmp(opts.history.mode, 're_smoother')
    H = hetlearn.re_filter(spec, opts, 'end', opts.forecast.origin(1));
else
    H = hetlearn.re_filter(spec, opts);
end
H = hetlearn.policy.prepare(H, info, opts);
ctx = struct('opts', opts, 'spec', spec, 'info', info, 'results_dir', tempdir, 'quiet', true);
[res, F] = hetlearn.engine.core(ctx, m, H);
end


function x = xb_at(d, xbn, t)
% Predetermined states at t from a databank (element 'v{-k}' = v at t-k).
x = zeros(numel(xbn), 1);
for j = 1:numel(xbn)
    tok = regexp(xbn{j}, '^(\w+)\{-(\d+)\}$', 'tokens', 'once');
    if isempty(tok)
        x(j) = d.(xbn{j})(t);
    else
        x(j) = d.(tok{1})(t - str2double(tok{2}));
    end
end
end


function s = cfg_history(o)
s = o.history.mode;
if strcmp(s, 're_smoother')
    s = 'RE-smoothed';
end
end
