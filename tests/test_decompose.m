function R = test_decompose(part)
%TEST_DECOMPOSE  Shock decompositions (DESIGN 16): toy checks C1-C4, C6, SW07 report C5.
%
%   R = test_decompose()          all checks
%   R = test_decompose('toy')     C1-C4, C6;  test_decompose('sw07')  C5
%
%   C1 RE: the time-varying decomposition ('tv') = IRIS contributions
%      ('iris'), every component, on an RE inversion and an RE re_smoother
%      result (1e-10)
%   C2 learning (switching inversion): components + beliefs_constants = total
%      (1e-12); the period models with constants rebuild the paths (1e-9)
%   C3 groups: each group = sum of its members' components, total unchanged
%   C4 long CSV written with the documented columns
%   C6 'tv' uses the beliefs in force after the projection facility (ALM
%      reverts included; model-consistent toy, high gain): paths rebuilt
%      after every revert, a wrong recorded belief is detected
%   C7 N agent types: a switching re_smoother run with RE and BR
%      spelled out decomposes as the two-type run (every component, 1e-9);
%      {RE, BR, TB}: additive, the period models rebuild its paths; a result
%      of history.mode = 'kalman' stops with hetlearn:options:unsupported
%   C5 SW07 (needs test_inversion('sw07_re') and ('sw07_learn') outputs in
%      tests/output/results/): pinfobs and dy, 2019Q1-2026Q2, RE and
%      learning; largest contributors to 2022Q2 inflation; RE 'tv' = 'iris'

if nargin < 1 || isempty(part)
    part = 'all';
end
R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, 'output', 'results');
if any(strcmp(part, {'all', 'toy'}))
    R = toy_checks(R, here, outDir);
end
if any(strcmp(part, {'all', 'sw07'}))
    R = sw07_checks(R, outDir);
end
end


% =========================================================================
function R = toy_checks(R, here, outDir)
toyDir = fullfile(here, 'toy_nk');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
run = @(cfg) hetlearn.run(cfg, 'save', false, 'quiet', true);
spec = hetlearn.load_spec(toyDir);
base = struct();
base.model = toyDir;
base.forecast = struct('origin', qq(2020, 4), 'horizon', 8);
base.expectations = struct('mode', 'rational', 'variables', {{'y', 'pie'}});
vars = {'obs_pie', 'obs_y', 'pie', 'r'};
q = struct('save', false, 'quiet', true);

% ---- C1 ----
nm = 'decompose C1: RE time-varying decomposition = IRIS contributions (inversion and re_smoother histories)';
try
    worst = 0;
    add1 = 0;
    for hm = {'inversion', 're_smoother'}
        c = base;
        c.id = ['toy_dec_re_' hm{1}];
        c.history.mode = hm{1};
        r = run(c);
        opts = hetlearn.load_options(c);
        [m, info] = hetlearn.load_model(spec, opts);
        q.model = struct('spec', spec, 'm', m, 'info', info);
        q.method = 'iris';
        Di = hetlearn.decompose(r, vars, [], q);
        q.method = 'tv';
        Dt = hetlearn.decompose(r, vars, [], q);
        for v = vars
            worst = max(worst, max(max(abs(Di.values.(v{1}) - Dt.values.(v{1})))));
        end
        add1 = max([add1, Di.check.additivity_maxerr, Dt.check.additivity_maxerr]);
    end
    R = add(R, nm, worst < 1e-10 && add1 < 1e-10 && isequal(Di.components, Dt.components), ...
        sprintf('max diff %.2g, additivity %.2g, components %s', worst, add1, strjoin(Dt.components, ',')));
catch err
    R = add(R, nm, false, err.message);
end

% ---- C2 ----
nm = 'decompose C2: learning decomposition is additive and rebuilds the realised paths';
D2 = [];
try
    c = base;
    c.id = 'toy_dec_sw';
    c.history.mode = 'inversion';
    c.expectations.mode = 'switching';
    c.switching.intensity = 0.25;
    r2 = run(c);
    opts = hetlearn.load_options(c);
    [m, info] = hetlearn.load_model(spec, opts);
    q.model = struct('spec', spec, 'm', m, 'info', info);
    q.method = 'auto';
    D2 = hetlearn.decompose(r2, vars, [], q);
    bc = max(abs(D2.values.obs_pie(:, end)));
    R = add(R, nm, strcmp(D2.method, 'tv') && D2.check.additivity_maxerr < 1e-12 && D2.check.recon_maxerr < 1e-9, ...
        sprintf('additivity %.2g, path rebuild %.2g, %d solves, max |beliefs_constants| obs_pie %.3g, %.2f s', ...
        D2.check.additivity_maxerr, D2.check.recon_maxerr, D2.check.n_solve, bc, D2.runtime_s));
catch err
    R = add(R, nm, false, err.message);
end

% ---- C3 ----
nm = 'decompose C3: groups sum their members; total unchanged';
try
    q3 = q;
    q3.groups = struct('demand', {{'e_g'}}, 'cost_policy', {{'e_u', 'e_r'}});
    D3 = hetlearn.decompose(r2, vars, [], q3);
    worst = 0;
    for v = vars
        A = D2.values.(v{1});
        B = D3.values.(v{1});
        c2 = D2.components;
        worst = max([worst, max(abs(B(:, 1) - A(:, strcmp(c2, 'e_g')))), ...
            max(abs(B(:, 2) - A(:, strcmp(c2, 'e_u')) - A(:, strcmp(c2, 'e_r')))), ...
            max(abs(B(:, 3:4) - A(:, end-1:end)), [], 'all'), max(abs(D3.total.(v{1}) - D2.total.(v{1})))]);
    end
    R = add(R, nm, worst < 1e-14 && isequal(D3.components, {'demand', 'cost_policy', 'init', 'beliefs_constants'}), ...
        sprintf('max diff %.2g; components %s', worst, strjoin(D3.components, ',')));
catch err
    R = add(R, nm, false, err.message);
end

% ---- C4 ----
nm = 'decompose C4: long CSV (scenario, date, variable, component, value_model, value_report, label)';
try
    q4 = q;
    q4.save = true;
    q4.results_dir = outDir;
    D4 = hetlearn.decompose(r2, {'obs_pie'}, [qq(2019, 1), qq(2020, 4)], q4);
    T = readtable(D4.file, 'TextType', 'char', 'Delimiter', ',');
    cols = {'scenario', 'date', 'variable', 'component', 'value_model', 'value_report', 'label'};
    nExp = 8 * (numel(D4.components) + 1);
    labBC = unique(T.label(strcmp(T.component, 'beliefs_constants')));
    ok = isequal(T.Properties.VariableNames, cols) && height(T) == nExp ...
        && max(abs(T.value_model - D4.table.value_model)) < 1e-12 ...
        && isequal(labBC, {'intercept channel (perceived means)'}) && all(~cellfun(@isempty, T.label));
    R = add(R, nm, ok, sprintf('%s: %d rows (expected %d); labels %s', D4.file, height(T), nExp, ...
        strjoin(unique(T.label, 'stable')', ' | ')));
catch err
    R = add(R, nm, false, err.message);
end

% ---- C6: beliefs in force after the projection facility ----
% Model-consistent toy with half learners on y and pie and a high gain:
% under 'alm' the ALM check reverts every belief in some periods (history
% and horizon). 'tv' must use the beliefs actually in force (res.learning
% records the reverted values): the period models then rebuild the paths at
% the periods after each revert; a deliberately wrong belief at an event
% date breaks the reconstruction (the check has power).
nm = ['decompose C6: tv uses the beliefs in force after the projection facility (ALM reverts included): ' ...
    'paths rebuilt after every revert; a wrong recorded belief is detected'];
try
    c = base;
    c.id = 'tdec_facility';
    c.forecast.horizon = 12;
    c.expectations = struct('mode', 'fixed_shares', 'variables', {{'y', 'pie'}}, 're_variant', 'model_consistent');
    c.shares.fixed_n2 = 0.5;
    c.gain.value = 0.3;
    c.projection.facility = 'alm';
    rng(6);
    hz6 = qq(2021, 1):qq(2023, 4);
    c.shocks.add = {{'e_g', hz6, randn(12, 1)}, {'e_u', hz6, 0.5 * randn(12, 1)}};
    r6 = run(c);
    E = r6.events;
    isA = strcmp(E.type, 'projection_alm');
    dA = cellfun(@(s) double(str2dat(s)), E.date(isA));
    org = double(r6.dates.origin);
    last = double(hz6(end));
    dA = dA(dA >= org - 1e-6 & dA <= last - 1 + 1e-6);     % reverts that set the model of a horizon period
    qc = struct('save', false, 'quiet', true);
    D6 = hetlearn.decompose(r6, {'obs_pie', 'pie'}, [], qc);
    full = r6.dates.full;
    rec = 0;
    for k = 1:numel(dA)
        rec = max(rec, D6.check.recon_by_date(abs(double(full) - (dA(k) + 1)) < 1e-6));
    end
    bad = r6;
    tb = dater_of(full, dA(1));
    bad.learning.pie.beta_pie(tb) = bad.learning.pie.beta_pie(tb) + 0.05;
    Db = hetlearn.decompose(bad, {'obs_pie', 'pie'}, [], qc);
    recBad = Db.check.recon_by_date(abs(double(full) - (dA(1) + 1)) < 1e-6);
    ok = numel(dA) > 0 && rec < 1e-9 && D6.check.recon_maxerr < 1e-9 && recBad > 1e-6 ...
        && D6.check.additivity_maxerr < 1e-12;
    R = add(R, nm, ok, sprintf(['%d ALM reverts setting horizon models (%d in all); recon after them %.2g, ' ...
        'overall %.2g; with a wrong belief %.2g'], numel(dA), sum(isA), rec, D6.check.recon_maxerr, recBad));
catch err
    R = add(R, nm, false, sprintf('%s (%s, line %d)', err.message, err.stack(1).name, err.stack(1).line));
end

% ---- C7: N agent types ----
nm = ['decompose C7: N agent types: RE and BR spelled out = the two-type decomposition (switching, re_smoother; ' ...
    'every component, 1e-9); {RE, BR, TB} additive and rebuilds its forecast paths; Kalman results refused'];
try
    T = @(varargin) struct(varargin{:});
    c = base;
    c.id = 'tdec_nt_two';
    c.expectations.mode = 'switching';
    c.switching.intensity = 0.25;
    cb = c;
    cb.id = 'tdec_nt_pair';
    cb.expectations.types = {T('name', 'RE', 'kind', 're'), T('name', 'BR', 'kind', 'plm')};
    cc = c;
    cc.id = 'tdec_nt_tb';
    cc.expectations.types = [cb.expectations.types, {T('name', 'TB', 'kind', 'rule', 'rule', '0')}];
    cc.shares.init = struct('RE', 0.4, 'BR', 0.4, 'TB', 0.2);
    D = cell(1, 3);
    rr = cell(1, 3);
    mdl = cell(1, 3);
    cs = {c, cb, cc};
    for j = 1:3
        rr{j} = run(cs{j});
        oj = hetlearn.load_options(cs{j});
        [mj, ij] = hetlearn.load_model(spec, oj);
        mdl{j} = struct('spec', spec, 'm', mj, 'info', ij);
        qj = struct('save', false, 'quiet', true, 'model', mdl{j});
        D{j} = hetlearn.decompose(rr{j}, vars, [], qj);
    end
    d = 0;
    for v = vars
        d = max([d, max(abs(D{1}.values.(v{1})(:) - D{2}.values.(v{1})(:))), max(abs(D{1}.total.(v{1}) - D{2}.total.(v{1})))]);
    end
    same = isequal(D{1}.components, D{2}.components) && strcmp(D{2}.method, 'tv');
    tbOk = D{3}.check.additivity_maxerr < 1e-12 && D{3}.check.recon_maxerr < 1e-9 && strcmp(D{3}.method, 'tv');
    % refusal: a Kalman result
    rk = rr{1};
    rk.history_mode = 'kalman';
    kErr = refused(@() hetlearn.decompose(rk, vars, [], struct('save', false, 'quiet', true, 'model', mdl{1})), 'kalman');
    ok = d <= 1e-9 && same && tbOk && kErr;
    R = add(R, nm, ok, sprintf(['pair vs two-type %.3g (components equal %d); TB additivity %.2g, path rebuild %.2g; ' ...
        'Kalman result refused %d'], d, same, D{3}.check.additivity_maxerr, D{3}.check.recon_maxerr, kErr));
catch err
    R = add(R, nm, false, sprintf('%s (%s, line %d)', err.message, err.stack(1).name, err.stack(1).line));
end
end


function tf = refused(fun, needle)
% true when fun stops with hetlearn:options:unsupported and a message containing needle
try
    fun();
    tf = false;
catch err
    tf = strcmp(err.identifier, 'hetlearn:options:unsupported') && contains(err.message, needle);
end
end


function t = dater_of(full, td)
t = full(find(abs(double(full) - td) < 1e-6, 1));
end


% =========================================================================
function R = sw07_checks(R, outDir)
ids = {'tinv_sw07_re', 'RE'; 'tinv_sw07_switch_pinf', 'switching pinf'; ...
    'tinv_sw07_switch_pinf_anch', 'switching pinf, anchored'};
rng = [qq(2019, 1), qq(2026, 2)];
t22 = qq(2022, 2);
for k = 1:size(ids, 1)
    nm = sprintf('decompose C5: SW07 %s, pinfobs and dy 2019Q1-2026Q2', ids{k, 2});
    file = fullfile(outDir, ids{k, 1}, 'results.mat');
    if exist(file, 'file') ~= 2
        R = add(R, nm, false, sprintf('missing %s: run test_inversion(''sw07_re''/''sw07_learn'') first', file));
        continue
    end
    try
        L = load(file, 'res');
        res = L.res;
        spec = hetlearn.load_spec('sw07');
        [m, info] = hetlearn.load_model(spec, res.cfg);
        mdl = struct('spec', spec, 'm', m, 'info', info);
        D = hetlearn.decompose(res, {'pinfobs', 'dy'}, rng, struct('results_dir', outDir, 'model', mdl));
        i = find(abs(double(D.dates) - double(t22)) < 1e-6, 1);
        v = D.values.pinfobs(i, :) * D.scale.pinfobs;
        [~, ord] = sort(abs(v), 'descend');
        top = arrayfun(@(j) sprintf('%s %+.2f', D.components{j}, v(j)), ord(1:min(5, end)), 'UniformOutput', false);
        tot = D.total.pinfobs(i) * D.scale.pinfobs;
        vdy = D.values.dy(i, :) * D.scale.dy;
        [~, od] = sort(abs(vdy), 'descend');
        topdy = arrayfun(@(j) sprintf('%s %+.2f', D.components{j}, vdy(j)), od(1:min(3, end)), 'UniformOutput', false);
        fprintf('C5 %s (%s, %.1f s): 2022Q2 inflation deviation %+.2f pp annualised = %s\n', ids{k, 2}, ...
            D.method, D.runtime_s, tot, strjoin(top, ', '));
        fprintf('C5 %s: 2022Q2 output growth deviation %+.2f pp annualised; largest %s\n', ids{k, 2}, ...
            D.total.dy(i) * D.scale.dy, strjoin(topdy, ', '));
        msg = sprintf('%s, %.1f s, additivity %.2g; 2022Q2 pinfobs dev %+.2f: %s', D.method, D.runtime_s, ...
            D.check.additivity_maxerr, tot, strjoin(top(1:min(3, end)), ', '));
        ok = D.check.additivity_maxerr < 1e-10;
        if strcmp(D.method, 'tv')
            msg = sprintf('%s; rebuild %.2g', msg, D.check.recon_maxerr);
            ok = ok && D.check.recon_maxerr < 1e-8;
        else
            Dt = hetlearn.decompose(res, {'pinfobs', 'dy'}, rng, struct('save', false, 'quiet', true, ...
                'model', mdl, 'method', 'tv'));
            w = max([max(abs(Dt.values.pinfobs - D.values.pinfobs), [], 'all'), ...
                max(abs(Dt.values.dy - D.values.dy), [], 'all')]);
            msg = sprintf('%s; tv = iris to %.2g (tv %.1f s)', msg, w, Dt.runtime_s);
            ok = ok && w < 1e-9;
        end
        R = add(R, nm, ok, msg);
    catch err
        R = add(R, nm, false, err.message);
    end
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
if ~pass
    fprintf('FAILED %s: %s\n', name, msg);
end
end
