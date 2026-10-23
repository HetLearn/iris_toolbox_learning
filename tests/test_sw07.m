function R = test_sw07()
%TEST_SW07  SW07 package through the toolbox (DESIGN 8): S1-S4.
%
%   R = test_sw07()   returns a struct array of checks (name, pass, msg).
%
%   S1 load_model + re_filter; collapse test passed; fit error < 1e-8
%   S2 RE replay: origin 2022Q2, smoothed shocks 2022Q3-2026Q2, rational ->
%      observables = data (< 1e-8); run into tests/output/results/
%   S4 runs the test scenarios tsw07_peak_re and tsw07_switch_pinf (tests/scenarios/)
%      through hetlearn.run_files (saved to tests/output/results/) and prints beliefs,
%      shares and the annualised inflation paths
%   S3 tsw07_peak_re = one IRIS simulate of the ORIGINAL models/sw07/sw07.model
%      from the smoothed state at 2022Q2 with zero shocks (< 1e-10)
%   S5 option model_params = 'sw07_params_original': the model gets the published
%      SW07 values, the RE filter cache key differs, a missing function is an error

R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % test scenarios tsw07_* (not scenarios/)
outDir = fullfile(here, 'output', 'results');
origin = qq(2022, 2);
hz = qq(2022, 3):qq(2026, 2);

% ---- S1 --------------------------------------------------------------------------------
try
    spec = hetlearn.load_spec('sw07');
    opts = hetlearn.load_options(struct('model', 'sw07', ...
        'expectations', struct('variables', {{'pinf'}})));
    [m, info] = hetlearn.load_model(spec, opts);
    H = hetlearn.re_filter(spec, opts);
    cm = info.meta.collapse_maxdiff;
    ok = info.meta.validated && max(cm) < 1e-10 && H.fit_error < 1e-8 && isequal(info.learnVars, {'pinf'});
    R = add(R, 'sw07 S1: load_model (collapse test) and re_filter (fit < 1e-8)', ok, ...
        sprintf('%d forward-looking vars, collapse %.2g/%.2g, fit %.2g', ...
        numel(info.meta.forward_vars), cm(1), cm(2), H.fit_error));
catch err
    R = add(R, 'sw07 S1: load_model (collapse test) and re_filter (fit < 1e-8)', false, err.message);
    return
end

% ---- S2: RE replay -------------------------------------------------------------------------
try
    cfg = struct('id', 'sw07_test_replay', 'model', 'sw07');
    cfg.forecast = struct('origin', origin, 'horizon', 16);
    cfg.expectations = struct('mode', 'rational', 'variables', {{'pinf'}});
    cfg.shocks.source = 'smoothed';
    res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    dmax = 0;
    for i = 1:numel(spec.observables)
        o = spec.observables{i};
        dmax = max(dmax, max(abs(res.paths.(o)(hz) - H.data.(o)(hz))));
    end
    R = add(R, 'sw07 S2: RE replay with smoothed shocks 2022Q3-2026Q2 reproduces the data', ...
        dmax < 1e-8, sprintf('max abs %.2g', dmax));
    fprintf('S2 RE replay: max abs(observables - data) over 2022Q3-2026Q2 = %.3g\n', dmax);
catch err
    R = add(R, 'sw07 S2: RE replay with smoothed shocks 2022Q3-2026Q2 reproduces the data', false, err.message);
end

% ---- S4: template scenarios ------------------------------------------------------------------------
try
    T = hetlearn.run_files({'tsw07_peak_re', 'tsw07_switch_pinf'}, 'results_dir', outDir);
    re = load(fullfile(outDir, 'tsw07_peak_re', 'results.mat'));
    sw = load(fullfile(outDir, 'tsw07_switch_pinf', 'results.mat'));
    re = re.res;
    sw = sw.res;
    L = sw.learning.pinf;
    fprintf('\nS4 tsw07_switch_pinf at 2022Q2: alpha_pinf = %.4f, beta_pinf = %.4f, n2_pinf = %.4f\n', ...
        L.alpha_pinf(origin), L.beta_pinf(origin), L.n2(origin));
    fprintf('%-8s %10s %10s %10s %8s\n', 'quarter', '4*pinf RE', '4*pinf sw', 'diff', 'n2 used');
    a = 4 * re.paths.pinfobs(hz);
    b = 4 * sw.paths.pinfobs(hz);
    n2u = 1 - L.n1_model(hz);
    ds = hetlearn.util.date_str(hz);
    for k = 1:numel(hz)
        fprintf('%-8s %10.3f %10.3f %10.3f %8.3f\n', ds{k}, a(k), b(k), b(k) - a(k), n2u(k));
    end
    fprintf('runtimes: %s %.1f s, %s %.1f s; events %d / %d\n', T.id{1}, T.runtime_s(1), ...
        T.id{2}, T.runtime_s(2), T.events(1), T.events(2));
    hasCmp = exist(fullfile(outDir, 'tsw07_switch_pinf', 'compare_tsw07_peak_re.csv'), 'file') == 2;
    ok = all(strcmp(T.status, 'ok')) && hasCmp && all(isfinite(b)) && max(abs(b - a)) > 0;
    R = add(R, 'sw07 S4: template scenarios run (run_files), compare CSV written', ok, ...
        sprintf('%s; %.1f s and %.1f s', strjoin(T.status', ', '), T.runtime_s(1), T.runtime_s(2)));
catch err
    R = add(R, 'sw07 S4: template scenarios run (run_files), compare CSV written', false, err.message);
    return
end

% ---- S3: RE scenario = original model ------------------------------------------------------------
try
    mo = Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true);
    mo = assign(mo, feval_in(spec.folder, spec.params));
    [mo, flag] = solve(mo);
    assert(hasSucceeded(flag), 'solve failed for the original model');
    mo = sstate(mo);
    xo = cellstr(get(mo, 'xList'));
    yo = cellstr(get(mo, 'yList'));
    eo = cellstr(get(mo, 'eList'));
    d0 = struct();
    for n = [xo(:); yo(:); eo(:)]'
        x = H.smooth.(n{1});
        d0.(n{1}) = clip(x, x.Start, origin);
    end
    for n = eo(:)'
        d0.(n{1})(hz) = 0;
    end
    s = simulate(mo, d0, hz, 'anticipate', false, 'prependInput', true);
    dmax = 0;
    for n = [xo(:); yo(:)]'
        v = abs(re.paths.(n{1})(hz) - s.(n{1})(hz));
        v(isnan(v)) = Inf;
        dmax = max(dmax, max(v));
    end
    R = add(R, 'sw07 S3: tsw07_peak_re = one IRIS simulate of the original sw07.model (all variables)', ...
        dmax < 1e-10, sprintf('%d transition + %d measurement variables, max abs %.2g', ...
        numel(xo), numel(yo), dmax));
    fprintf('S3 tsw07_peak_re vs original model: max abs diff = %.3g\n', dmax);
catch err
    R = add(R, 'sw07 S3: tsw07_peak_re = one IRIS simulate of the original sw07.model (all variables)', false, err.message);
end

% ---- S5: option model_params ----------------------------------------------------------------------
nm = ['sw07 S5: model_params = ''sw07_params_original'' assigns the published SW07 mode (every value), ' ...
    'has its own RE filter cache (fit < 1e-8); a name not in the package is an error'];
try
    oP = opts;
    oP.model_params = 'sw07_params_original';
    [mP, infoP] = hetlearn.load_model(spec, oP);
    PP = feval_in(spec.folder, 'sw07_params_original');
    dP = 0;
    for f = fieldnames(PP)'
        dP = max(dP, abs(mP.(f{1}) - PP.(f{1})));        % parameters and std_<shock> by name
    end
    pv = struct('crpi', mP.crpi);
    HP = hetlearn.re_filter(spec, oP);
    bad = false;
    try
        oB = opts;
        oB.model_params = 'no_such_params';
        hetlearn.load_model(spec, oB);
    catch eB
        bad = strcmp(eB.identifier, 'hetlearn:load_model:params');
    end
    ok = dP == 0 && isequal(infoP.params, PP) && ~strcmp(HP.hash, H.hash) && HP.fit_error < 1e-8 ...
        && abs(PP.crpi - 2.02946740344113) < 1e-14 && bad;
    R = add(R, nm, ok, sprintf('max |model - file| %.2g, crpi %.4f (swX1 %.4f), cache %s vs %s, fit %.2g, missing name error %d', ...
        dP, pv.crpi, info.params.crpi, HP.hash(1:8), H.hash(1:8), HP.fit_error, bad));
catch err
    R = add(R, nm, false, err.message);
end
end


function P = feval_in(folder, fname)
addpath(folder);
c = onCleanup(@() rmpath(folder));
P = feval(fname);
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
