function R = test_ramsey(parts)
%TEST_RAMSEY  Ramsey policy (DESIGN 13): IRIS patch, generator, targeting rules, loss, SW07 runs.
%
%   R = test_ramsey()          toy NK checks and the SW07 runs
%   R = test_ramsey('toy')     toy NK checks only
%   R = test_ramsey('sw07')    SW07 runs only (from the 2022Q2 peak, zero
%                              shocks, default weights; Ramsey RE and Ramsey
%                              switching pinf against the Taylor-rule runs)
%
%   Toy (tests/toy_nk, rule labelled "Taylor rule"): with h = iota = c2 = 0
%   the toy is the textbook NK model, so under RE the commitment targeting
%   rule pie_t + (lam/kap)(y_t - y_{t-1}) = 0 holds from the second forecast
%   period (first period: pie + (lam/kap) y = 0, the multipliers are zero at
%   the origin) and discretion gives pie_t + (lam/kap) y_t = 0.
%   SW07 output goes to tests/output/results/ (never results/), plus
%   tests/output/results/sw07_ramsey_paths.csv and sw07_ramsey_losses.csv.

if nargin < 1 || isempty(parts)
    parts = {'toy', 'sw07'};
end
parts = cellstr(parts);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % test scenarios tsw07_* (not scenarios/)
outDir = fullfile(here, 'output', 'results');
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end
R = struct('name', {}, 'pass', {}, 'msg', {});
if any(strcmp(parts, 'toy'))
    R = [R, toy_part(here, outDir)];
end
if any(strcmp(parts, 'sw07'))
    R = [R, sw07_part(outDir)];
end
end


% =========================================================================
function R = toy_part(here, outDir)
R = struct('name', {}, 'pass', {}, 'msg', {});
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
spec = hetlearn.load_spec(toyDir);
run = @(cfg, varargin) hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false, varargin{:});
origin = qq(2020, 4);
hz = origin + 1 : origin + 12;
lam = 0.5;
kap = 0.05;

% ---- R0: IRIS patch -------------------------------------------------------------
w = which('model.Insertable');
R = add(R, 'ramsey R0: which(''model.Insertable'') is the hetlearn patch (toolbox/iris_patches)', ...
    contains(w, fullfile('toolbox', 'iris_patches')), w);

% ---- R1: generator --------------------------------------------------------------
nm = 'ramsey R1: generator wraps the labelled rule (!if ramsey), rule-only shock e_r, collapse test with ramsey = false';
try
    meta = hetlearn.extend_model(spec, 'ar1');
    txt = fileread(meta.ext_file);
    mp = meta.policy;
    ok = mp.ok && strcmp(meta.policy_toggle, 'ramsey') && contains(txt, '!if ramsey') ...
        && contains(txt, 'min((1 - ramsey_disc_on)*(bet) + ramsey_disc_on*ramsey_disc) w_pinf*(pie)^2') ...
        && contains(txt, '"Taylor rule" r = rho_r*r{-1} +') && isequal(mp.rule_shocks, {'e_r'}) ...
        && isempty(mp.rule_vars) && all(meta.collapse_maxdiff < 1e-10) && meta.generator_version >= 3;
    R = add(R, nm, ok, sprintf('collapse %s; rule shocks {%s}', mat2str(meta.collapse_maxdiff, 2), ...
        strjoin(mp.rule_shocks, ',')));
catch err
    R = add(R, nm, false, err.message);
end

% ---- R2: package copies: no policy section; missing label ------------------------
tmp = fullfile(tempdir, 'hetlearn_test_models', 'ramsey_pkg');
if exist(tmp, 'dir') == 7
    rmdir(tmp, 's');
end
mkdir(tmp);
copyfile(fullfile(toyDir, 'nk3.model'), tmp);
copyfile(fullfile(toyDir, 'nk3_params.m'), tmp);
nm = 'ramsey R2: without spec.policy the generated file has no policy text (meta.policy empty)';
try
    s0 = spec;
    s0.folder = tmp;
    s0 = rmfield(s0, 'policy');
    m0 = hetlearn.extend_model(s0, 'ar1', 'force', true);
    t0 = fileread(m0.ext_file);
    R = add(R, nm, isempty(m0.policy) && isempty(m0.policy_toggle) && ~contains(t0, 'ramsey') ...
        && ~contains(t0, 'w_pinf'), m0.ext_file);
catch err
    R = add(R, nm, false, err.message);
end
cR = struct('id', 'toy_ramsey_rule_check', 'model', toyDir);
cR.forecast = struct('origin', origin, 'horizon', 12);
cR.expectations = struct('mode', 'rational', 'variables', {{}});
try
    s1 = spec;
    s1.folder = tmp;
    s1.policy.rule_label = 'No such rule';
    c1 = cR;
    c1.policy.mode = 'ramsey';
    R = expect_error(R, 'ramsey R2: missing rule label is an error with policy.mode = ''ramsey''', ...
        @() hetlearn.load_model(s1, c1), 'No such rule');
    [~, i1] = hetlearn.load_model(s1, cR);
    R = add(R, 'ramsey R2: missing rule label is fine with policy.mode = ''rule''', ...
        ~i1.policy.wrapped && ~isempty(i1.meta.policy.error), i1.meta.policy.error);
catch err
    R = add(R, 'ramsey R2: missing rule label is fine with policy.mode = ''rule''', false, err.message);
end
c2 = cR;
c2.policy.loss = struct('pinf', 1, 'output', 1);
R = expect_error(R, 'ramsey R2: unknown target name in policy.loss is an error', ...
    @() hetlearn.load_model(spec, c2), 'unknown target');

% ---- R3/R4: targeting rules (textbook parameters) ---------------------------------
for type = {'commitment', 'discretion'}
    nm = sprintf('ramsey R3: %s targeting rule holds under RE from the origin (< 1e-10)', type{1});
    try
        c = cR;
        c.id = ['toy_ramsey_tr_' type{1}];
        c.policy = struct('mode', 'ramsey', 'type', type{1}, 'loss', struct('pinf', 1, 'ygap', lam));
        [m, info] = hetlearn.load_model(spec, c);
        m = assign(m, struct('h', 0, 'iota', 0, 'c2', 0));
        [m, ok] = hetlearn.engine.solve_model(m, spec);
        res = run(c, 'model', struct('spec', spec, 'm', m, 'info', info));
        p = res.paths.pie(hz);
        y = res.paths.y(hz);
        if strcmp(type{1}, 'commitment')
            tr = [p(1) + lam / kap * y(1); p(2:end) + lam / kap * (y(2:end) - y(1:end-1))];
        else
            tr = p + lam / kap * y;
        end
        mu = info.policy.multipliers;
        mu0 = max(cellfun(@(n) abs(res.paths.(n)(origin)), mu));
        R = add(R, nm, ok && max(abs(tr)) < 1e-10 && mu0 == 0 && max(abs(y)) > 1e-3, ...
            sprintf('max residual %.2e; %d multipliers, max |Mu| at origin %g; max |y| %.3g', ...
            max(abs(tr)), numel(mu), mu0, max(abs(y))));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- R5: Ramsey loss <= Taylor-rule loss over 200 quarters; continuation ------------------
nm = 'ramsey R5: RE, zero shocks, same state: Ramsey loss <= Taylor-rule loss over 200 quarters';
try
    c = cR;
    c.id = 'toy_ramsey_loss_rule';
    c.policy.loss_horizon = 200;
    rr = run(c);
    c.id = 'toy_ramsey_loss_ramsey';
    c.policy.mode = 'ramsey';
    ra = run(c);
    hist = ra.dates.full(1):origin;
    dh = max(abs(ra.paths.y(hist) - rr.paths.y(hist)));
    R = add(R, nm, ra.loss.total <= rr.loss.total && ra.loss.continuation && dh == 0, ...
        sprintf('Ramsey %.6g, rule %.6g (ratio %.3f); history diff %g', ra.loss.total, rr.loss.total, ...
        ra.loss.total / rr.loss.total, dh));
    c.id = 'toy_ramsey_loss_direct';
    c.forecast.horizon = 200;
    c.policy.loss_horizon = [];
    rd = run(c);
    R = add(R, 'ramsey R5: loss over a 200-quarter continuation = loss of a 200-quarter forecast', ...
        abs(rd.loss.total - ra.loss.total) < 1e-10 * max(1, rd.loss.total), ...
        sprintf('%.12g vs %.12g', ra.loss.total, rd.loss.total));
    v = rr.paths;
    t = origin + 1 : origin + 12;
    df = 0.99 .^ (1:12)';
    c.policy.loss_horizon = [];
    c.forecast.horizon = 12;
    c.policy.mode = 'rule';
    c.id = 'toy_ramsey_loss_rule12';
    r12 = run(c);
    hand = sum(df .* (v.pie(t).^2 + 0.5 * v.y(t).^2 + 0.1 * v.r(t).^2));
    R = add(R, 'ramsey R5: rule-run loss = hand computation sum bet^h (pie^2 + 0.5 y^2 + 0.1 r^2)', ...
        abs(r12.loss.total - hand) < 1e-12 * max(1, hand), sprintf('%.12g vs %.12g', r12.loss.total, hand));
catch err
    R = add(R, nm, false, err.message);
end

% ---- R6: Ramsey with learning: switching, anchored RE, VAR PLM; history = rule ---------------
base = cR;
base.expectations = struct('mode', 'switching', 'variables', {{'pie'}});
cases = {'switching pie (AR1), model-consistent RE', struct('re_variant', 'model_consistent'), ...
    'anchored RE, switching y and pie', struct('re_variant', 'anchored', 'variables', {{'y', 'pie'}}), ...
    'switching y and pie, VAR(1) PLM, model-consistent RE', struct('re_variant', 'model_consistent', 'variables', {{'y', 'pie'}}, 'plm', 'var1')};
% (discretion with learning variables: IRIS's discretion is indeterminate,
% MULTIPLE_STABLE, at the RE point n1 = 1 with zero beliefs, where
% hetlearn.load_model solves; DESIGN 13 open issue)
for i = 1:2:numel(cases)
    nm = sprintf('ramsey R6: Ramsey with %s runs (timing assert holds), history equals the rule run', cases{i});
    try
        o = cases{i + 1};
        c = base;
        c.id = sprintf('toy_ramsey_learn%d', i);
        if isfield(o, 're_variant'), c.expectations.re_variant = o.re_variant; end
        if isfield(o, 'variables'), c.expectations.variables = o.variables; end
        if isfield(o, 'plm'), c.beliefs.plm.default = o.plm; end
        rr = run(c);
        c.policy.mode = 'ramsey';
        if isfield(o, 'type'), c.policy.type = o.type; end
        ra = run(c);
        rd = ra.dates.record;
        hist = rd(double(rd) <= double(origin) + 1e-6);
        x = c.expectations.variables{end};
        dh = max(abs(ra.learning.(x).fBR(hist) - rr.learning.(x).fBR(hist)));
        dr = max(abs(ra.paths.r(hz) - rr.paths.r(hz)));
        R = add(R, nm, isfinite(ra.loss.total) && dh == 0 && dr > 1e-6, ...
            sprintf('loss Ramsey %.4g, rule %.4g; history fBR diff %g; r differs by %.3g; %d events', ...
            ra.loss.total, rr.loss.total, dh, dr, height(ra.events)));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- R7: rule-only shock has no effect and warns once; discount override ---------------------
nm = 'ramsey R7: a shock on the rule (e_r) runs under Ramsey, warns, and has no effect';
try
    c = cR;
    c.id = 'toy_ramsey_er';
    c.policy.mode = 'ramsey';
    r0 = run(c);
    c.shocks.add = {{'e_r', hz(1:4), 1}};
    r1 = run(c);
    [~, info7] = hetlearn.load_model(spec, c);
    rg = qq(2000, 1):origin;
    lastwarn('');
    hetlearn.policy.prepare(struct('smooth', struct('r', Series(rg, zeros(numel(rg), 1)))), info7, ...
        hetlearn.load_options(c));
    [~, wid] = lastwarn();
    d = 0;
    for v = {'y', 'pie', 'r', 'g', 'u'}
        d = max(d, max(abs(r1.paths.(v{1})(hz) - r0.paths.(v{1})(hz))));
    end
    R = add(R, nm, d == 0 && strcmp(wid, 'hetlearn:policy:ruleInputs'), sprintf('max diff %g, warning %s', d, wid));
    c = cR;
    c.id = 'toy_ramsey_disc';
    c.policy.mode = 'ramsey';
    c.policy.discount = 0.99;
    r2 = run(c);
    d = max(abs(r2.paths.r(hz) - r0.paths.r(hz)));
    c.policy.discount = 0.9;
    r3 = run(c);
    d3 = max(abs(r3.paths.r(hz) - r0.paths.r(hz)));
    R = add(R, 'ramsey R7: policy.discount = bet reproduces the spec discount; 0.9 changes the plan', ...
        d < 1e-12 && d3 > 1e-6 && strcmp(r2.loss.discount_source, 'option') && r3.loss.discount == 0.9, ...
        sprintf('diff at 0.99 %.2e, at 0.9 %.3g', d, d3));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function R = sw07_part(outDir)
R = struct('name', {}, 'pass', {}, 'msg', {});
runs = {'sw07_test_rule_re', @tsw07_peak_re, 'rule'; ...
    'sw07_test_ramsey_re', @tsw07_peak_re, 'ramsey'; ...
    'sw07_test_rule_switch_pinf', @tsw07_switch_pinf, 'rule'; ...
    'sw07_test_ramsey_switch_pinf', @tsw07_switch_pinf, 'ramsey'};
res = cell(1, size(runs, 1));
for i = 1:size(runs, 1)
    nm = sprintf('ramsey S%d: %s runs from the 2022Q2 peak (zero shocks, default weights)', i, runs{i, 1});
    try
        c = runs{i, 2}();
        c.id = runs{i, 1};
        c.compare_with = {};
        c.policy.mode = runs{i, 3};
        t = tic;
        res{i} = hetlearn.run(c, 'results_dir', outDir, 'quiet', true, 'save', true);
        L = res{i}.loss;
        R = add(R, nm, isfinite(L.total) && exist(fullfile(outDir, c.id, 'loss.csv'), 'file') == 2, ...
            sprintf('loss %.6g (discount %.6f), %.1f s', L.total, L.discount, toc(t)));
    catch err
        R = add(R, nm, false, err.message);
    end
end
if any(cellfun(@isempty, res))
    return
end
hz = res{1}.dates.horizon;
origin = res{1}.dates.origin;
nm = 'ramsey S5: RE: Ramsey loss <= Taylor-rule loss; same history; multipliers 0 at the origin';
mu = res{2}.meta.xList(startsWith(res{2}.meta.xList, 'Mu_'));
mu0 = max(cellfun(@(n) abs(res{2}.paths.(n)(origin)), mu));
hist = res{1}.dates.full(1):origin;
dh = max(abs(res{2}.paths.pinf(hist) - res{1}.paths.pinf(hist)));
R = add(R, nm, res{2}.loss.total <= res{1}.loss.total && mu0 == 0 && dh == 0, ...
    sprintf('Ramsey %.6g vs rule %.6g; switching pinf: Ramsey %.6g vs rule %.6g; %d multipliers', ...
    res{2}.loss.total, res{1}.loss.total, res{4}.loss.total, res{3}.loss.total, numel(mu)));

% summary tables: annualised inflation, policy rate, output growth; losses
names = {'pinfobs', 'robs', 'dy'};
hdr = {'date'};
X = zeros(numel(hz), 0);
for i = 1:size(runs, 1)
    for j = 1:numel(names)
        hdr{end+1} = sprintf('%s_x4__%s', names{j}, runs{i, 1}); %#ok<AGROW>
        X(:, end+1) = 4 * res{i}.paths.(names{j})(hz); %#ok<AGROW>
    end
end
hetlearn.util.write_csv(fullfile(outDir, 'sw07_ramsey_paths.csv'), hdr, ...
    hetlearn.util.date_str(double(hz)), X);
tn = res{1}.loss.target_names;
Y = zeros(size(runs, 1), numel(tn) + 1);
for i = 1:size(runs, 1)
    for j = 1:numel(tn)
        Y(i, j) = res{i}.loss.by_target.(tn{j});
    end
    Y(i, end) = res{i}.loss.total;
end
hetlearn.util.write_csv(fullfile(outDir, 'sw07_ramsey_losses.csv'), [{'run'}, tn, {'total'}], runs(:, 1)', Y);
end


% =========================================================================
function R = expect_error(R, name, f, needle)
try
    f();
    R = add(R, name, false, 'no error raised');
catch err
    R = add(R, name, contains(err.message, needle), err.message);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
