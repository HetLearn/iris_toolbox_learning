function make_br_freeze()
%MAKE_BR_FREEZE  Freeze the references of tests/test_br_regression.m (docs/DESIGN_br_extensions.md 1.7, phase P0).
%
%   make_br_freeze()
%
%   Writes tests/reference/br_freeze.mat, variable ref:
%     .made, .matlab, .iris, .threads (maxNumCompThreads when frozen)
%     .toolbox   struct array (file, md5) of every file under toolbox/: the code that was frozen
%     .gen       R1: br_generate() output (package, re_info, file, md5, bytes, generator_version)
%     .runs      R2: struct array, one per run: id, group, step, cfg (the partial option tree
%                passed to hetlearn.run; test_br_regression re-runs it), opts (res.cfg, the merged
%                tree), the result fields paths, learning, events, state, dates, loss,
%                history_mode, and meta (model_hash, refilter_hash, refilter_fit_error, learnVars,
%                xList, yList, eList)
%     .girf_sd   one-sd shock sizes of the 2019Q4 IRF runs (std_<shock> of sw07_params_original)
%
%   Runs (default engine.step 'fast' unless named): tsw07_peak_re; tsw07_switch_pinf ('fast' and
%   'iris'); the baseline tsw07_a1_re and tsw07_a1_learn ('fast' and 'iris'); the 2019Q4 IRF runs
%   of DESIGN_br_extensions sec. 4: for the baseline and the RE(t-1) benchmark, no shock and +1 sd
%   of each of the seven SW07 shocks in 2020Q1, and for the baseline also -1 sd (the
%   nonlinearity diagnostic). 30 runs, about 1.5 minutes (4.5 MB).
%
%   Checks before saving (an error stops the freeze): the test copies tsw07_a1_re/_learn merge
%   to the same option tree as scenarios/sw07/app1_peak/a1_re/_learn under the live
%   config/master_options.m (apart from id, title, description, compare_with); the tsw07_switch_pinf
%   runs equal tests/reference/tsw07_switch_pinf_iris.mat and _fast.mat (max diff 0); every
%   shocked 2019Q4 run differs from its unshocked run over the horizon. Also printed: the max
%   difference from results/a1_re and results/a1_learn when those exist (information only).
%
%   Run it only on the code to be frozen (first made 2026-10-20 with the code before phase P1),
%   at the default thread count, from a session where tests/scenarios is on the path (run_tests
%   adds it).

here = fileparts(mfilename('fullpath'));    % tests/scenarios
tests = fileparts(here);
root = fileparts(tests);
addpath(here);
mo = which('master_options');
assert(startsWith(mo, here), 'make_br_freeze: master_options resolves to %s, not tests/scenarios.', mo);
tAll = tic;

% ---- R1: generated files ------------------------------------------------------------------
G = br_generate();
for i = 1:numel(G)
    fprintf('R1 %-6s %-8s %-28s %s (%d bytes, generator version %d)\n', G(i).package, G(i).re_info, ...
        G(i).file, G(i).md5, numel(G(i).bytes), G(i).generator_version);
end

% ---- the baseline test copies merge to the live baseline -----------------------------------
check_baseline_copies(root);

% ---- R2: runs ---------------------------------------------------------------------------------
P = feval_in(fullfile(root, 'models', 'sw07'), 'sw07_params_original');
shocks = {'ea', 'eb', 'eg', 'eqs', 'em', 'epinf', 'ew'};
sd = struct();
for k = 1:numel(shocks)
    sd.(shocks{k}) = P.(['std_' shocks{k}]);
end
defs = {};      % {id, group, step, cfg}
defs(end+1, :) = {'tsw07_peak_re', 'tsw07', 'fast', tsw07_peak_re()};
defs(end+1, :) = {'tsw07_switch_pinf', 'tsw07', 'fast', tsw07_switch_pinf()};
defs(end+1, :) = {'tsw07_switch_pinf', 'tsw07', 'iris', tsw07_switch_pinf()};
defs(end+1, :) = {'tsw07_a1_re', 'baseline', 'fast', tsw07_a1_re()};
defs(end+1, :) = {'tsw07_a1_learn', 'baseline', 'fast', tsw07_a1_learn()};
defs(end+1, :) = {'tsw07_a1_re', 'baseline', 'iris', tsw07_a1_re()};
defs(end+1, :) = {'tsw07_a1_learn', 'baseline', 'iris', tsw07_a1_learn()};
for b = {'re', 'learn'}
    c = tsw07_girf2019(b{1});
    defs(end+1, :) = {c.id, ['girf_' b{1}], 'fast', c}; %#ok<AGROW>
    for k = 1:numel(shocks)
        c = tsw07_girf2019(b{1}, shocks{k}, sd.(shocks{k}));
        defs(end+1, :) = {c.id, ['girf_' b{1}], 'fast', c}; %#ok<AGROW>
    end
end
for k = 1:numel(shocks)
    c = tsw07_girf2019('learn', shocks{k}, -sd.(shocks{k}));
    c.id = [c.id '_minus'];
    defs(end+1, :) = {c.id, 'girf_learn_minus', 'fast', c}; %#ok<AGROW>
end

runs = struct('id', {}, 'group', {}, 'step', {}, 'cfg', {}, 'opts', {}, 'paths', {}, 'learning', {}, ...
    'events', {}, 'state', {}, 'dates', {}, 'loss', {}, 'history_mode', {}, 'meta', {});
for i = 1:size(defs, 1)
    cfg = defs{i, 4};
    cfg.compare_with = {};
    if strcmp(defs{i, 3}, 'iris')
        cfg.engine.step = 'iris';
    end
    t = tic;
    res = hetlearn.run(cfg, 'save', false, 'quiet', true);
    runs(end+1) = pack(defs{i, 1}, defs{i, 2}, defs{i, 3}, cfg, res); %#ok<AGROW>
    fprintf('R2 %-36s %-5s %5.1f s, %d events, pinfobs at origin+1 %.6f\n', defs{i, 1}, defs{i, 3}, ...
        toc(t), height(res.events), res.paths.pinfobs(res.dates.horizon(1)));
end

% ---- checks against the existing references and between runs ----------------------------------
for st = {'iris', 'fast'}
    L = load(fullfile(tests, 'reference', ['tsw07_switch_pinf_' st{1} '.mat']), 'ref');
    k = find(strcmp({runs.id}, 'tsw07_switch_pinf') & strcmp({runs.step}, st{1}));
    [d, worst] = ref_maxdiff(runs(k), L.ref);
    fprintf('tsw07_switch_pinf_%s.mat: max diff %.3g %s\n', st{1}, d, worst);
    assert(d == 0, 'make_br_freeze: tsw07_switch_pinf (%s) differs from tests/reference by %.3g (%s).', st{1}, d, worst);
end
obs = {'pinfobs', 'dy', 'robs', 'dc'};
for i = find(startsWith({runs.group}, 'girf_'))
    g = runs(i).group;
    if endsWith(runs(i).id, '_none')
        continue
    end
    b = 'learn';
    if contains(g, '_re')
        b = 're';
    end
    k0 = find(strcmp({runs.id}, sprintf('tsw07_girf2019_%s_none', b)));
    hz = runs(i).dates.horizon;
    v = cellfun(@(o) runs(i).paths.(o)(hz(1)) - runs(k0).paths.(o)(hz(1)), obs);
    dmax = max(cellfun(@(o) max(abs(runs(i).paths.(o)(hz) - runs(k0).paths.(o)(hz))), obs));
    fprintf('GIRF %-38s impact pinfobs %8.4f dy %8.4f robs %8.4f dc %8.4f (max %.3g)\n', runs(i).id, v, dmax);
    assert(dmax > 1e-6, 'make_br_freeze: %s does not differ from the run without the shock.', runs(i).id);
end
for nm = {'a1_re', 'a1_learn'}
    f = fullfile(root, 'results', nm{1}, 'results.mat');
    k = find(strcmp({runs.id}, ['tsw07_' nm{1}]) & strcmp({runs.step}, 'fast'));
    if exist(f, 'file') == 2
        L = load(f, 'res');
        [d, worst] = ref_maxdiff(runs(k), L.res);
        fprintf('results/%s (information only; made %s): max diff %.3g %s\n', nm{1}, L.res.meta.finished, d, worst);
    end
end

% ---- save --------------------------------------------------------------------------------------------
ref = struct();
ref.made = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
ref.matlab = version();
ref.iris = char(string(iris.release()));
ref.threads = maxNumCompThreads();
ref.toolbox = code_state(fullfile(root, 'toolbox'));
ref.gen = G;
ref.runs = runs;
ref.girf_sd = sd;
out = fullfile(tests, 'reference', 'br_freeze.mat');
save(out, 'ref');
w = dir(out);
fprintf('saved %s: %d generated files, %d runs, %.1f MB, %.0f s\n', out, numel(G), numel(runs), ...
    w.bytes / 2^20, toc(tAll));
end


% =========================================================================================
function r = pack(id, group, step, cfg, res)
meta = struct();
for f = {'model_hash', 'refilter_hash', 'refilter_fit_error', 'learnVars', 'xList', 'yList', 'eList'}
    meta.(f{1}) = res.meta.(f{1});
end
r = struct('id', id, 'group', group, 'step', step, 'cfg', cfg, 'opts', res.cfg, 'paths', res.paths, ...
    'learning', res.learning, 'events', res.events, 'state', res.state, 'dates', res.dates, ...
    'loss', res.loss, 'history_mode', res.history_mode, 'meta', meta);
end


function check_baseline_copies(root)
% tsw07_a1_re/_learn under tests/scenarios/master_options.m = a1_re/_learn under config/master_options.m
scn = {fullfile(root, 'scenarios', 'sw07', 'base'), fullfile(root, 'scenarios', 'sw07', 'app1_peak')};
addpath(scn{:});
c = onCleanup(@() rmpath(scn{:}));
live = live_master(root);
skip = {'id', 'title', 'description', 'compare_with'};
pairs = {'a1_re', @a1_re, @tsw07_a1_re; 'a1_learn', @a1_learn, @tsw07_a1_learn};
for i = 1:size(pairs, 1)
    a = rmfield(hetlearn.load_options(pairs{i, 2}(), live), skip);
    b = rmfield(hetlearn.load_options(pairs{i, 3}()), skip);       % the test master (run_tests puts it first)
    assert(isequaln(a, b), 'make_br_freeze: tsw07_%s does not merge to the option tree of %s under config/master_options.m.', ...
        pairs{i, 1}, pairs{i, 1});
    fprintf('tsw07_%s = %s under config/master_options.m (merged option trees equal)\n', pairs{i, 1}, pairs{i, 1});
end
end


function M = live_master(root)
% config/master_options.m, although tests/scenarios/master_options.m shadows it on the path
old = cd(fullfile(root, 'config'));
c = onCleanup(@() cd(old));
clear('master_options');
M = master_options();
clear('master_options');
end


function T = code_state(folder)
f = dir(fullfile(folder, '**', '*.*'));
f = f(~[f.isdir]);
T = struct('file', {}, 'md5', {});
for i = 1:numel(f)
    p = fullfile(f(i).folder, f(i).name);
    T(end+1) = struct('file', strrep(p, [folder filesep], ''), ...
        'md5', hetlearn.util.md5(hetlearn.util.file_bytes(p))); %#ok<AGROW>
end
end


function P = feval_in(folder, fname)
addpath(folder);
c = onCleanup(@() rmpath(folder));
P = feval(fname);
end
