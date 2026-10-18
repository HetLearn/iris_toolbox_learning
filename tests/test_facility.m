function R = test_facility()
%TEST_FACILITY  Projection facility (DESIGN 4.4; user decision 2026-10-18): F1-F9, unit systems and the toy NK model.
%
%   R = test_facility()   returns a struct array of checks (name, pass, msg).
%
%   F1 AR(1) candidate with |beta| > 1: block reverted under 'plm_alm',
%      kept under 'alm' and 'none' (unit call); run level: under 'alm' the
%      explosive PLM is kept while the ALM is stable (path = 'none'), under
%      'plm_alm' the block keeps its beliefs (projection_plm events)
%   F2 several learning variables, one explosive block: only that block is
%      reverted; the same outcome with the equations in reverse order; a
%      VAR block next to an AR(1) block
%   F3 block detection: a regressor with an auxiliary PLM joins the block of
%      the equation that uses it; a shared auxiliary regressor links two
%      learning variables; a VAR is one block; separate AR(1)s are separate
%   F4 unstable ALM after an update (toy, model-consistent RE, n2 = 0.5,
%      candidates beta_y = beta_pie = 0.99 < 1, previous 0.95): every belief
%      reverted under 'alm' and 'plm_alm', event 'projection_alm', model solved
%   F5 run level, high gain: the history ALM check on the RE-smoothed data
%      catches unstable ALMs (projection_alm events, stage 'history'), the
%      run continues, recorded beliefs at event dates = the previous ones
%   F6 no earlier solved model (the initial beliefs and shares are unstable:
%      forecast with history.learn = false, first history check): error
%      hetlearn:engine:almUnstable (date, stage, shares); also for a model
%      without leads whose transition root exceeds 1
%   F7 'none' without a solution: error hetlearn:engine:noSolution naming
%      the date; 'none' with a no-lead model: explosive path simulated,
%      'explosive' events, no error
%   F8 KOZ gain: in every period where the facility keeps or reverts
%      beliefs, Rg_t and gamma follow the recursion with FE_t (hand loop)
%   F9 stages: 'none' solves nothing in the RE-smoothed history; 'plm_alm'
%      checks every history period; mode 'rational' skips the solve
%   F10 model shares kept when reverting the beliefs is not enough (user
%      decision 2026-10-18): a run that used to stop completes, n1_model =
%      the previous quarter's at projection_alm_shares periods while n1
%      moves, 'none' stops, the 'tv' decomposition rebuilds the paths
%   Results go to tests/output/results/ (not the project results/).

R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
toyDir = fullfile(here, 'toy_nk');
outDir = fullfile(here, 'output', 'results');
if exist(fullfile(toyDir, 'data', 'nk3_database.csv'), 'file') ~= 2
    addpath(toyDir);
    build_toy_database();
end
spec = hetlearn.load_spec(toyDir);
run = @(cfg, varargin) hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false, varargin{:});
t1 = qq(2021, 1);

% ---- F1 (unit): AR(1) candidate |beta| > 1 ---------------------------------------------
nm = 'facility F1: AR(1) candidate |beta| > 1: reverted under plm_alm, kept under alm and none (unit)';
try
    sys = hetlearn.plm.build_system('ar1', {'x'}, {'x'});
    phi0 = [0; 0.9];
    R0 = 0.01 * eye(2);
    S = unit_state(sys, struct('x', phi0), struct('x', R0));
    vals = struct('x', [1, 5]);                           % x_{t-1}, x_t
    getVal = @(n, k) vals.(n)(2 + k);
    [pc, ~] = hetlearn.rls.update(phi0, R0, [1; 1], 5, 0.5);
    out = struct();
    for f = {'plm_alm', 'alm', 'none'}
        o = hetlearn.defaults();
        o.gain.value = 0.5;
        o.projection.facility = f{1};
        [S1, ~, ev] = hetlearn.engine.update_learning(unit_ctx(o, sys, {}), S, t1, getVal, struct(), struct(), false);
        out.(f{1}) = struct('phi', S1.phi.x, 'R', S1.R.x, 'ev', ev);
    end
    ok = abs(pc(2)) > 1 && isequal(out.plm_alm.phi, phi0) && isequal(out.plm_alm.R, R0) ...
        && numel(out.plm_alm.ev) == 1 && strcmp(out.plm_alm.ev.type, 'projection_plm') ...
        && max(abs(out.alm.phi - pc)) < 1e-15 && isempty(out.alm.ev) ...
        && max(abs(out.none.phi - pc)) < 1e-15 && isempty(out.none.ev);
    R = add(R, nm, ok, sprintf('candidate beta %.4f; plm_alm: %s', pc(2), ev_detail(out.plm_alm.ev)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- F1 (run): explosive PLM kept under 'alm' while the ALM is stable ----------------------
nm = ['facility F1: toy, 5% learners with beta_pie = 1.02 (explosive PLM, stable ALM): alm keeps the ' ...
    'updates (= none), plm_alm keeps the block (projection_plm every period)'];
try
    c = struct('model', toyDir);
    c.forecast = struct('origin', qq(2020, 4), 'horizon', 8);
    c.expectations = struct('mode', 'fixed_shares', 'variables', {{'pie'}});
    c.shares.fixed_n2 = 0.05;
    c.beliefs.init = struct('method', 'user', 'values', struct('pie', struct('alpha', 0, 'beta', 1.02)));
    c.history.learn = false;
    c.shocks.add = {{'e_u', qq(2021, 1):qq(2022, 4), 0.5 * ones(8, 1)}};
    rr = struct();
    for f = {'plm_alm', 'alm', 'none'}
        cf = c;
        cf.id = ['tfac_f1_' f{1}];
        cf.projection.facility = f{1};
        rr.(f{1}) = run(cf);
    end
    hzF = rr.alm.dates.horizon;
    bA = rr.alm.learning.pie.beta_pie(hzF);
    bN = rr.none.learning.pie.beta_pie(hzF);
    bP = rr.plm_alm.learning.pie.beta_pie(hzF);
    isP = strcmp(rr.plm_alm.events.type, 'projection_plm');
    nP = sum(isP);
    dP = cellfun(@(s) double(str2dat(s)), rr.plm_alm.events.date(isP));
    bPrev = [1.02; bP(1:end-1)];
    okP = nP > 0;
    for k = 1:numel(hzF)
        if any(abs(dP - double(hzF(k))) < 1e-6)
            okP = okP && bP(k) == bPrev(k);          % block kept its previous beliefs
        else
            okP = okP && abs(bP(k)) <= 1;            % accepted updates are not explosive
        end
    end
    ok = height(rr.alm.events) == 0 && max(abs(bA - bN)) == 0 && any(abs(bA - 1.02) > 1e-6) ...
        && any(abs(bA) > 1) && okP;
    R = add(R, nm, ok, sprintf('alm beta %.4f..%.4f (events %d); plm_alm %d projection_plm events, beta %.4f', ...
        min(bA), max(bA), height(rr.alm.events), nP, bP(end)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- F2: one explosive block among several; equation order -----------------------------
nm = 'facility F2: two AR(1) blocks, one explosive: only it is reverted, same result in reverse order; VAR block + AR(1)';
try
    o = hetlearn.defaults();
    o.gain.value = 0.5;
    vals = struct('x', [1, 5], 'y', [1, 1.05], 'a', [1, 6], 'b', [1, 1], 'c', [1, 1.02]);
    getVal = @(n, k) vals.(n)(2 + k);
    res2 = cell(1, 2);
    orders = {{'x', 'y'}, {'y', 'x'}};
    for q = 1:2
        sys = hetlearn.plm.build_system('ar1', orders{q}, {'x', 'y'});
        S = unit_state(sys, struct('x', [0; 0.9], 'y', [0; 0.5]), struct('x', 0.01 * eye(2), 'y', 0.01 * eye(2)));
        [S1, ~, ev] = hetlearn.engine.update_learning(unit_ctx(o, sys, {}), S, t1, getVal, struct(), struct(), false);
        res2{q} = struct('phi', S1.phi, 'ev', ev);
    end
    [pcy, ~] = hetlearn.rls.update([0; 0.5], 0.01 * eye(2), [1; 1], 1.05, 0.5);
    okA = isequal(res2{1}.phi.x, [0; 0.9]) && max(abs(res2{1}.phi.y - pcy)) < 1e-15 && abs(pcy(2)) < 1 ...
        && isequal(res2{1}.phi, res2{2}.phi) && numel(res2{1}.ev) == 1 && strcmp(res2{1}.ev.variable, 'x');
    plmV = struct('default', 'ar1', 'var', struct('variables', {{'a', 'b'}}, 'lags', 1, 'constant', true));
    sysV = hetlearn.plm.build_system(plmV, {'a', 'b', 'c'}, {'a', 'b', 'c'});
    phiV = struct('a', [0; 0.5; 0], 'b', [0; 0; 0.5], 'c', [0; 0.5]);
    RV = struct('a', 0.01 * eye(3), 'b', 0.01 * eye(3), 'c', 0.01 * eye(2));
    S = unit_state(sysV, phiV, RV);
    [S1, ~, ev] = hetlearn.engine.update_learning(unit_ctx(o, sysV, {}), S, t1, getVal, struct(), struct(), false);
    okB = isequal(S1.phi.a, phiV.a) && isequal(S1.phi.b, phiV.b) && ~isequal(S1.phi.c, phiV.c) ...
        && numel(ev) == 1 && strcmp(ev.variable, 'a,b');
    R = add(R, nm, okA && okB, sprintf('AR(1) case: %s; VAR case: %s', ev_detail(res2{1}.ev), ev_detail(ev)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- F3: block detection ---------------------------------------------------------------
nm = 'facility F3: blocks: own regressor + auxiliary PLM = one block; shared auxiliary links; VAR one block; AR(1)s separate';
try
    allV = {'pinf', 'ygap', 'w', 'a', 'b', 'c', 'x', 'y'};
    p1 = struct('default', 'ar1', 'by_var', struct('pinf', struct('regressors', {{'pinf{-1}', 'ygap{-1}'}}, 'constant', true)));
    B1 = hetlearn.plm.blocks(hetlearn.plm.build_system(p1, {'pinf'}, allV));
    p2 = struct('default', 'ar1', 'by_var', struct( ...
        'pinf', struct('regressors', {{'pinf{-1}', 'ygap{-1}'}}, 'constant', true), ...
        'w', struct('regressors', {{'w{-1}', 'ygap{-2}'}}, 'constant', true)));
    B2 = hetlearn.plm.blocks(hetlearn.plm.build_system(p2, {'pinf', 'w', 'x'}, allV));
    p3 = struct('default', 'ar1', 'var', struct('variables', {{'a', 'b', 'c'}}, 'lags', 2, 'constant', true));
    B3 = hetlearn.plm.blocks(hetlearn.plm.build_system(p3, {'a', 'b', 'x', 'y'}, allV));
    lab = @(B) strjoin({B.label}, ' | ');
    ok = strcmp(lab(B1), 'pinf,ygap') && strcmp(lab(B2), 'pinf,w,ygap | x') ...
        && strcmp(lab(B3), 'a,b,c | x | y');
    R = add(R, nm, ok, sprintf('[%s]  [%s]  [%s]', lab(B1), lab(B2), lab(B3)));
catch err
    R = add(R, nm, false, err.message);
end

% ---- toy model with an unstable ALM region (model-consistent RE, n2 = 0.5, y and pie) -------
cM = struct('model', toyDir);
cM.forecast = struct('origin', qq(2020, 4), 'horizon', 8);
cM.expectations = struct('mode', 'fixed_shares', 'variables', {{'y', 'pie'}}, 're_variant', 'model_consistent');
cM.shares.fixed_n2 = 0.5;

% ---- F4: unstable ALM after an update, unit call with the model ----------------------------
nm = ['facility F4: candidates beta_y = beta_pie = 0.99 (PLMs stable) make the ALM unstable: every belief ' ...
    'reverted (alm, plm_alm), projection_alm event, model solved with the previous beliefs'];
try
    detail = '';
    okAll = true;
    for f = {'alm', 'plm_alm'}
        cf = cM;
        cf.id = 'tfac_f4';
        cf.projection.facility = f{1};
        cf.gain.value = 0.5;
        o = hetlearn.load_options(cf, struct());
        [m, info] = hetlearn.load_model(spec, o);
        sys = info.sys;
        phi0 = struct('y', [0; 0.95], 'pie', [0; 0.95]);
        R0 = struct('y', 0.01 * eye(2), 'pie', 0.01 * eye(2));
        S = unit_state(sys, phi0, R0);
        % data so that each RLS candidate slope is 0.99: y_t = phi0'z + (0.99 - b0)/(g [R_t^-1 z]_2)
        z = [1; 1];
        Rt = R0.y + 0.5 * (z * z' - R0.y);
        v = Rt \ z;
        yt = 0.95 + (0.99 - 0.95) / (0.5 * v(2));
        vals = struct('y', [1, yt], 'pie', [1, yt]);
        getVal = @(n, k) vals.(n)(2 + k);
        ctx = unit_ctx(o, sys, info.learnVars);
        ctx.spec = spec;
        [pcY, ~] = hetlearn.rls.update(phi0.y, R0.y, z, yt, 0.5);
        A = struct('m', m, 'stage', 'forecast');
        fR = struct('y', 0, 'pie', 0);
        [S1, out, ev] = hetlearn.engine.update_learning(ctx, S, t1, getVal, fR, fR, true, A);
        isA = strcmp({ev.type}, 'projection_alm');
        ok = abs(pcY(2) - 0.99) < 1e-12 && isequal(S1.phi, phi0) && isequal(S1.R, R0) && sum(isA) == 1 ...
            && out.alm.checked && out.alm.reverted && out.alm.n_solve == 2 && ~any(strcmp({ev.type}, 'projection_plm'));
        okAll = okAll && ok;
        detail = sprintf('%s%s: %s; ', detail, f{1}, ev_detail(ev(isA)));
    end
    R = add(R, nm, okAll, detail);
catch err
    R = add(R, nm, false, err.message);
end

% ---- F5: run level, history ALM check catches unstable ALMs; the run continues ----------------
nm = ['facility F5: high-gain toy run (model-consistent, n2 = 0.5): projection_alm events in the RE-smoothed ' ...
    'history, run completes, beliefs at event dates = previous period''s (every equation)'];
try
    msg = '';
    okAll = true;
    for f = {'alm', 'plm_alm'}
        cf = cM;
        cf.id = ['tfac_f5_' f{1}];
        cf.projection.facility = f{1};
        cf.gain.value = 0.3;
        r5 = run(cf);
        E = r5.events;
        isA = strcmp(E.type, 'projection_alm');
        dA = cellfun(@(s) double(str2dat(s)), E.date(isA));
        dA = dA(dA > double(r5.dates.record(1)) + 1e-6);
        okRev = true;
        for j = 1:numel(dA)
            for q = {'y', 'pie'}
                L = r5.learning.(q{1});
                okRev = okRev && L.(['beta_' q{1}])(dA(j)) == L.(['beta_' q{1}])(dA(j) - 1) ...
                    && L.(['alpha_' q{1}])(dA(j)) == L.(['alpha_' q{1}])(dA(j) - 1);
            end
        end
        nH = sum(isA & strcmp(E.stage, 'history'));
        nPl = sum(strcmp(E.type, 'projection_plm'));
        if strcmp(f{1}, 'alm')
            premise = nH > 0;
        else
            premise = nH > 0 || nPl > 0;     % plm_alm may catch the explosive candidates first
        end
        ok = premise && okRev && r5.meta.history_alm_n_check > 0 && all(isfinite(r5.paths.pie(r5.dates.horizon)));
        okAll = okAll && ok;
        msg = sprintf('%s%s: %d projection_alm (%d history), %d projection_plm, %d checks %.2f s; ', msg, f{1}, ...
            sum(isA), nH, sum(strcmp(E.type, 'projection_plm')), r5.meta.history_alm_n_check, r5.meta.history_alm_check_s);
    end
    R = add(R, nm, okAll, msg);
catch err
    R = add(R, nm, false, err.message);
end

% ---- F6: no earlier solved model: the initial beliefs and shares are unstable -------------------
% Since 2026-10-18 (user decision) the facility keeps the previous quarter's beliefs and model
% shares when reverting the beliefs is not enough; it stops only when no earlier solved model
% exists. Two cases: the forecast's first quarter with history.learn = false (initial beliefs at
% the origin), and the first history check (initial beliefs at beliefs.init.date).
nm = ['facility F6: initial beliefs and shares unstable, no earlier solved model: hetlearn:engine:almUnstable ' ...
    '(forecast with history.learn = false; first history check)'];
almTxt = 'no stable solution and no earlier solved model to fall back on';
try
    cf = cM;
    cf.id = 'tfac_f6';
    b99 = struct('alpha', 0, 'beta', 0.99);
    cf.beliefs.init = struct('method', 'user', 'values', struct('y', b99, 'pie', b99));
    cf.history.learn = false;
    msg = '';
    okAll = true;
    for f = {'alm', 'plm_alm', 'alm_history'}
        cg = cf;
        if strcmp(f{1}, 'alm_history')
            cg.history.learn = true;
            cg.beliefs.update = 'fixed';         % the first check sees the initial beliefs and shares
            cg.projection.facility = 'alm';
        else
            cg.projection.facility = f{1};
        end
        try
            run(cg);
            okAll = false;
            msg = [msg f{1} ': no error; ']; %#ok<AGROW>
        catch e6
            if strcmp(f{1}, 'alm_history')
                where = 'history stage';
            else
                where = '2021Q1 (forecast stage)';
            end
            ok = strcmp(e6.identifier, 'hetlearn:engine:almUnstable') && contains(e6.message, where) ...
                && contains(e6.message, almTxt) && contains(e6.message, 'n2_pie = 0.5');
            okAll = okAll && ok;
            msg = sprintf('%s%s: %s (%s); ', msg, f{1}, e6.identifier, e6.message(1:min(end, 60)));
        end
    end
    R = add(R, nm, okAll, msg);
catch err
    R = add(R, nm, false, err.message);
end

% ---- F10: model shares kept when reverting the beliefs is not enough ----------------------------
% Model-consistent toy, switching on y and pie, fixed beliefs (0.99, 0.99) that are stable at
% n2 = 0.9 (start) and unstable near n2 = 0.5 (chi = 0.05, memory 0: the discrete-choice shares
% jump to about 0.5 and keep moving). Before 2026-10-18 this run stopped (almUnstable); now the
% previous quarter's model shares stay in force, projection_alm_shares events, n1 keeps moving.
nm = ['facility F10: run that used to stop completes: n1_model = previous quarter''s at every ' ...
    'projection_alm_shares period while n1 moves; the discrete-choice shares would not solve; none stops; tv rebuilds'];
try
    c10 = struct('model', toyDir, 'id', 'tfac_f10');
    c10.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
    c10.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}}, 're_variant', 'model_consistent');
    c10.beliefs.update = 'fixed';
    c10.beliefs.init = struct('method', 'user', 'values', struct('y', b99, 'pie', b99));
    c10.history.learn = false;
    c10.shares.init_n2 = 0.9;
    c10.switching = struct('intensity', 0.05, 'memory', 0);
    msg = '';
    okAll = true;
    for f = {'alm', 'plm_alm'}
        c = c10;
        c.projection.facility = f{1};
        r10 = run(c);
        E = r10.events;
        isK = strcmp(E.type, 'projection_alm_shares');
        dK = cellfun(@(s) double(str2dat(s)), E.date(isK));
        hz10 = r10.dates.horizon;
        okK = numel(dK) > 0;
        moved = 0;
        for j = 1:numel(dK)
            tk = dK(j);
            for q = {'y', 'pie'}
                L = r10.learning.(q{1});
                if tk + 1 <= double(hz10(end)) + 1e-6
                    okK = okK && L.n1_model(tk + 1) == L.n1_model(tk);   % kept for the next quarter
                end
                moved = moved + (L.n1(tk) ~= L.n1(tk - 1));
            end
        end
        okK = okK && moved > 0 && all(isfinite(r10.paths.pie(hz10)));
        % the discrete-choice shares of the first event period would not solve with these beliefs
        o10 = hetlearn.load_options(c, struct());
        [m10, i10] = hetlearn.load_model(spec, o10);
        n1d = struct('y', r10.learning.y.n1(dK(1)), 'pie', r10.learning.pie.n1(dK(1)));
        P10 = hetlearn.engine.facility('params', i10.sys, r10.state.phi, i10.learnVars, n1d);
        ws = warning('off', 'all');
        [~, flag10] = solve(assign(m10, P10));
        warning(ws);
        D10 = hetlearn.decompose(r10, {'obs_pie', 'pie'}, [], struct('save', false, 'quiet', true, ...
            'model', struct('spec', spec, 'm', m10, 'info', i10)));
        ok = okK && ~hasSucceeded(flag10) && D10.check.recon_maxerr < 1e-9 && ~any(strcmp(E.type, 'projection_alm'));
        okAll = okAll && ok;
        msg = sprintf(['%s%s: %d projection_alm_shares events, n1 moved %d times, n2_model kept %.3f, n2 at the ' ...
            'first event %.3f (IRIS %s), tv rebuild %.1e; '], msg, f{1}, numel(dK), moved, ...
            1 - r10.learning.pie.n1_model(hz10(end)), 1 - n1d.pie, char(string(flag10)), D10.check.recon_maxerr);
    end
    c = c10;
    c.projection.facility = 'none';
    try
        run(c);
        okAll = false;
        msg = [msg 'none: no error'];
    catch e10
        okAll = okAll && strcmp(e10.identifier, 'hetlearn:engine:noSolution');
        msg = sprintf('%snone: %s', msg, e10.identifier);
    end
    R = add(R, nm, okAll, msg);
catch err
    R = add(R, nm, false, sprintf('%s (line %d)', err.message, err.stack(1).line));
end

% ---- F7: 'none' -----------------------------------------------------------------------------
nm = 'facility F7: none without a solution: hetlearn:engine:noSolution naming the date, flag and block roots';
try
    cf.projection.facility = 'none';
    try
        run(cf);
        R = add(R, nm, false, 'no error');
    catch e7
        ok = strcmp(e7.identifier, 'hetlearn:engine:noSolution') && contains(e7.message, '2021Q1') ...
            && contains(e7.message, 'forecast stage') && contains(e7.message, 'NO_STABLE') ...
            && contains(e7.message, '{y} 0.99') && contains(e7.message, '{pie} 0.99');
        R = add(R, nm, ok, e7.message(1:min(end, 220)));
    end
catch err
    R = add(R, nm, false, err.message);
end

spec1 = spec;
spec1.name = 'nk3l1';
spec1.model_file = 'nk3_lead1.model';
cX = struct('id', 'tfac_noleads', 'model', toyDir);
cX.forecast = struct('origin', qq(2020, 4), 'horizon', 12);
cX.expectations = struct('mode', 'fixed_shares', 'variables', 'all', 're_variant', 'anchored');
cX.shares.fixed_n2 = 0.9;
cX.beliefs.update = 'fixed';
b11 = struct('alpha', 0, 'beta', 1.1);
cX.beliefs.init = struct('method', 'user', 'values', struct('y', b11, 'pie', b11, 'r', b11));
cX.history.learn = false;
nm = 'facility F7: none with a no-lead model (anchored, all variables learning): explosive path, explosive events, no error';
try
    cX.projection.facility = 'none';
    oX = hetlearn.load_options(cX, struct());
    [mX, infoX] = hetlearn.load_model(spec1, oX);
    rX = run(cX, 'model', struct('spec', spec1, 'm', mX, 'info', infoX));
    isX = strcmp(rX.events.type, 'explosive');
    p = rX.paths.pie(rX.dates.horizon);
    ok = sum(isX) == 12 && all(isfinite(p)) && abs(p(end)) > abs(p(1)) && height(rX.events) == 12;
    R = add(R, nm, ok, sprintf('%d explosive events; pie %.3g -> %.3g', sum(isX), p(1), p(end)));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'facility F6: the same no-lead model under plm_alm: transition root > 1 with fixed beliefs is hetlearn:engine:almUnstable';
try
    cX.projection.facility = 'plm_alm';
    oX = hetlearn.load_options(cX, struct());
    try
        run(cX, 'model', struct('spec', spec1, 'm', mX, 'info', infoX));
        R = add(R, nm, false, 'no error');
    catch e6
        ok = strcmp(e6.identifier, 'hetlearn:engine:almUnstable') && contains(e6.message, 'backward system');
        R = add(R, nm, ok, e6.message(1:min(end, 200)));
    end
catch err
    R = add(R, nm, false, err.message);
end

% ---- F8: KOZ gain moves in periods where the facility keeps or reverts beliefs ----------------
nm = 'facility F8: KOZ gain (common, master pie, rls error) follows its recursion with FE_t at every projection event';
try
    cf = cM;
    cf.id = 'tfac_f8';
    cf.projection.facility = 'plm_alm';
    cf.gain.value = 0.3;
    cf.gain.rule = 'koz';
    cf.gain.koz = struct('mu', 0.05, 'master', 'pie', 'bounds', [0.001 0.6]);
    r8 = run(cf);
    E = r8.events;
    isE = strcmp(E.type, 'projection_alm') | strcmp(E.type, 'projection_plm');
    dE = unique(cellfun(@(s) double(str2dat(s)), E.date(isE)));
    L = r8.learning.pie;
    d = r8.paths;
    worst = 0;
    moved = 0;
    for j = 1:numel(dE)
        t = dE(j);
        if t <= double(r8.dates.record(1)) + 1e-6
            continue
        end
        fe = d.pie(t) - (L.alpha_pie(t - 1) + L.beta_pie(t - 1) * d.pie(t - 1));
        rg = (1 - L.gain(t)) * L.gain_R(t - 1) + fe;
        worst = max(worst, abs(rg - L.gain_R(t)));
        if t + 1 <= double(r8.dates.record(end)) + 1e-6
            gNext = min(max(L.gain(t) + 0.05 * L.gain_R(t - 1) * fe, 0.001), 0.6);
            worst = max(worst, abs(gNext - L.gain(t + 1)));
        end
        moved = moved + (L.gain_R(t) ~= L.gain_R(t - 1));
    end
    ok = numel(dE) > 0 && worst < 1e-12 && moved == sum(dE > double(r8.dates.record(1)) + 1e-6);
    R = add(R, nm, ok, sprintf('%d event periods, recursion error %.2g, Rg moved in %d', numel(dE), worst, moved));
catch err
    R = add(R, nm, false, err.message);
end

% ---- F9: which stages solve ----------------------------------------------------------------
nm = 'facility F9: RE-smoothed history: none solves nothing, plm_alm checks every period, rational mode skips the solve';
try
    c9 = struct('model', toyDir, 'id', 'tfac_f9');
    c9.forecast = struct('origin', qq(2020, 4), 'horizon', 4);
    c9.expectations = struct('mode', 'switching', 'variables', {{'y', 'pie'}});
    c9.switching.intensity = 0.25;
    c9.projection.facility = 'none';
    rN = run(c9);
    c9.projection.facility = 'plm_alm';
    rP = run(c9);
    c9.expectations.mode = 'rational';
    rR = run(c9);
    nPer = numel(rP.dates.init_date:rP.dates.origin);
    ok = rN.meta.history_alm_n_check == 0 && rP.meta.history_alm_n_check == nPer ...
        && rR.meta.history_alm_n_check == 0 && rR.meta.history_alm_n_solve == 0;
    R = add(R, nm, ok, sprintf('none %d, plm_alm %d of %d periods (%.2f s), rational %d', ...
        rN.meta.history_alm_n_check, rP.meta.history_alm_n_check, nPer, rP.meta.history_alm_check_s, ...
        rR.meta.history_alm_n_check));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function S = unit_state(sys, phi, Rm)
S = struct('phi', phi, 'R', Rm, 'fe_hist', struct(), 'phi_hist', struct(), 'fRE', struct(), 'fBR', struct(), ...
    'zetaRE', [], 'zetaBR', [], 'n1', []);
for i = 1:numel(sys.eq)
    tg = sys.eq(i).target;
    S.fe_hist.(tg) = zeros(0, 1);
    S.phi_hist.(tg) = zeros(numel(sys.eq(i).param_names), 0);
end
end


function ctx = unit_ctx(o, sys, lv)
ctx = struct('opts', o, 'sys', sys, 'learnVars', {lv}, 'groups', [], 'groupOf', struct());
end


function s = ev_detail(ev)
if isempty(ev)
    s = 'no event';
else
    s = strjoin(arrayfun(@(e) sprintf('%s [%s] %s', e.type, e.variable, e.detail), ev, 'UniformOutput', false), ' || ');
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
