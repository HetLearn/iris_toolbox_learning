function [S, out, ev] = update_learning(ctx, S, t, getVal, fRE, fBR, first, A)
%UPDATE_LEARNING  End-of-period learning update: errors, fitness, shares, RLS, projection facility (DESIGN 4.3-4.5).
%
%   [S, out, ev] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, first)
%   [S, out, ev] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, first, A)
%
%   Shared by every stage that updates beliefs (history, inversion,
%   forecast, density draws, evaluation runs, the Ramsey continuation).
%   Called after x_t is known.
%
%   Inputs
%     ctx     engine context (.opts, .sys, .learnVars, .groups; .blocks =
%             hetlearn.plm.blocks(sys), computed here when missing; .spec
%             for the ALM check)
%     S       state at the start of t: S.phi = phi_{t-1}, S.R = R_{t-1},
%             S.zetaRE/zetaBR/n1 by share group (t-1), S.fRE/fBR = forecasts
%             of x_t made in t-1, S.gain = gain-rule state (created with
%             hetlearn.gain.<rule>('init', ...) when missing)
%     t       current period (IRIS date)
%     getVal  getVal(name, k) = value of name at t+k (k <= 0)
%     fRE     struct by learning variable: forecast of x_{t+1} made in t, RE
%     fBR     same, BR (made with phi_{t-1})
%     first   true in the initial period: no forecast errors, fitness and
%             shares keep their initial values
%     A       optional ALM check (projection.facility 'alm' | 'plm_alm'):
%             struct with .m (the model in force in t+1, IRIS Model) and
%             .stage ('history' | 'inversion' | 'forecast'); [] or missing
%             = no ALM check (callers pass [] under 'none')
%
%   Outputs
%     S    state at the end of t (phi_t, R_t, zeta_t, n1_t, f_t); S.prev =
%          struct('phi', phi_{t-1}, 'R', R_{t-1}), the beliefs before this
%          period's update (the ALM revert goes back to them); S.n1m_last =
%          the model shares in force in t; S.n1m_keep = [] or, when the ALM
%          check kept them, the model shares in force in t+1 (read by
%          hetlearn.engine.shares_for_mode)
%     out  struct: .FE_RE.<x>, .FE_BR.<x> own squared errors (x_t - f_{t-1})^2
%          (NaN if first); .gain.<target> gain used (NaN if no update);
%          .alm = r of hetlearn.engine.facility('alm', ...) (.checked,
%          .skipped, .reverted, .pv, .m = the model solved with the beliefs
%          and shares in force in t+1, .n_solve, .time)
%     ev   struct array of events (date, type, variable, detail)
%
%   Steps: (1) FE^i_t(x) = (x_t - f^i_{t-1}(x))^2; group sums over G;
%   hetlearn.switching.discrete_choice -> zeta_t, n1_t (non-finite shares:
%   event 'shares_nan', previous fitness and shares kept). (2) S.f = f_t.
%   (3) beliefs.update = 'rls': per PLM equation z = [1; u_j at t - l_j],
%   y = target_t and the residual v_t - phi_{t-1}' z (S.fe_hist); the gain
%   of each update, g = hetlearn.gain.<rule>('gain', S.gain, errors,
%   opts.gain) (DESIGN 18; errors = these residuals and the signed BR
%   expectation errors x_t - f^BR_{t-1}; 'koz': gamma_{t-1}); every
%   candidate from hetlearn.rls.update with phi_{t-1}, R_{t-1} (missing data:
%   event 'rls_missing', that equation keeps its beliefs); then the
%   projection facility (hetlearn.engine.facility, DESIGN 4.4): under
%   'plm_alm' the PLM blocks case by case (a block with largest root > 1
%   keeps phi and R, event 'projection_plm'; the outcome does not depend on
%   the equation order), then with A the ALM check of (phi_t, n_t) (an
%   unstable ALM reverts every belief to S.prev, event 'projection_alm';
%   still unstable: the previous quarter's model shares are kept for t+1
%   as well, event 'projection_alm_shares', while the discrete-choice
%   shares S.n1 keep their update; error hetlearn:engine:almUnstable only
%   when that model was never solved, i.e. the initial beliefs and shares
%   at the first check). (4) Gain update, a
%   separate block after the RLS and projection step (DESIGN 18):
%   [S.gain, ev] = hetlearn.gain.<rule>('update', S.gain, errors, opts.gain)
%   moves the gain state to the end of t with the errors of (3), whatever
%   the projection facility did with the candidates.
%
%   N agent types (ctx.nt): fRE is then
%   the struct F.<x>.<type> of hetlearn.engine.ntypes('forecasts', ...) and
%   fBR is ignored. (1) FE^k_t(x) = (x_t - f^k_{t-1}(x))^2 for every type
%   (out.FE.<x>.<type>); per share group the population types' sums over G go
%   to hetlearn.switching.discrete_choice_n with switching.memory and the
%   group's intensity (two types, RE first: hetlearn.switching.discrete_choice,
%   as in the two-type code) -> S.U{g}, S.n{g} (event 'shares_nan' as
%   before). (2) S.f = F (hetlearn.engine.ntypes 'store'). (3) RLS on every
%   equation of every learning type whose update is 'rls' (ctx.sys keyed by
%   <target>__<type>), each type with its own gain rule and state
%   S.gain.<type> (its errors: its residuals and its signed forecast errors),
%   then the projection facility on the keyed system and the ALM check as
%   before. (4) Each type's gain update; its events name the keyed targets.
%   Forecast transforms: fRE holds the forecasts as they enter the aggregate (after the
%   transforms; fitness and errors use them), fBR the second output of
%   hetlearn.engine.ntypes('forecasts') (forecasts before the transforms).

if nargin < 8
    A = [];
end
if isfield(ctx, 'nt') && ~isempty(ctx.nt)
    [S, out, ev] = update_nt(ctx, S, t, getVal, fRE, first, A, fBR);
    return
end
o = ctx.opts;
sys = ctx.sys;
lv = ctx.learnVars;
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
out = struct('FE_RE', struct(), 'FE_BR', struct(), 'gain', struct(), 'alm', []);
if ~isfield(ctx, 'blocks') || isempty(ctx.blocks)
    ctx.blocks = hetlearn.plm.blocks(sys);
end
% model shares in force in t (a share kept by the facility at the end of t-1 included):
% the "previous quarter's model shares" of this period's ALM check (DESIGN 4.4)
S.n1m_last = hetlearn.engine.shares_for_mode(ctx, S);

% ---- (1) forecast errors, fitness, shares ----------------------------------------
feF = struct();                 % signed BR expectation errors x_t - f^BR_{t-1} (gain rules)
for i = 1:numel(lv)
    x = lv{i};
    if first
        out.FE_RE.(x) = NaN;
        out.FE_BR.(x) = NaN;
        feF.(x) = NaN;
    else
        xt = getVal(x, 0);
        out.FE_RE.(x) = (xt - S.fRE.(x))^2;
        out.FE_BR.(x) = (xt - S.fBR.(x))^2;
        feF.(x) = xt - S.fBR.(x);
    end
end
if ~first && ~isempty(ctx.groups)
    nG = numel(ctx.groups);
    FEr = zeros(1, nG);
    FEb = zeros(1, nG);
    for g = 1:nG
        for v = ctx.groups(g).G
            FEr(g) = FEr(g) + out.FE_RE.(v{1});
            FEb(g) = FEb(g) + out.FE_BR.(v{1});
        end
    end
    [n1, zRE, zBR] = feval(['hetlearn.switching.' o.switching.rule], FEr, FEb, ...
        S.zetaRE, S.zetaBR, o.switching.intensity, o.switching.memory);
    if any(~isfinite(n1))
        ev(end+1) = mkev(t, 'shares_nan', strjoin(lv, ','), ...
            'non-finite share; previous fitness and shares kept'); %#ok<AGROW>
    else
        S.n1 = n1;
        S.zetaRE = zRE;
        S.zetaBR = zBR;
    end
end

% ---- (2) forecasts made in t ------------------------------------------------------
S.fRE = fRE;
S.fBR = fBR;

% ---- (3) RLS and the projection facility (DESIGN 4.4) ---------------------------------
doRLS = strcmp(o.beliefs.update, 'rls');
S.prev = struct('phi', S.phi, 'R', S.R);        % beliefs before this period's update
nE = numel(sys.eq);
for i = 1:nE
    out.gain.(sys.eq(i).target) = NaN;
end
if doRLS
    [Z, Y, S, errs, G] = gain_of_period(o, sys, lv, S, t, getVal, feF, first);
    cand = S.phi;
    Rcand = S.R;
    upd = false(1, nE);
    for i = 1:nE
        tg = sys.eq(i).target;
        if ~all(isfinite([Z{i}; Y(i)]))
            ev(end+1) = mkev(t, 'rls_missing', tg, 'missing data; beliefs kept'); %#ok<AGROW>
            continue
        end
        g = G.(tg);
        out.gain.(tg) = g;
        [cand.(tg), Rcand.(tg)] = hetlearn.rls.update(S.phi.(tg), S.R.(tg), Z{i}, Y(i), g);
        upd(i) = true;
    end
    if strcmp(hetlearn.engine.facility('name', o), 'plm_alm')
        [S, e] = hetlearn.engine.facility('plm', ctx, S, cand, Rcand, upd, t);   % PLM blocks, case by case
        ev = [ev, e];
    else
        S.phi = cand;                % 'alm' and 'none' never touch the PLMs
        S.R = Rcand;
    end
end
S.n1m_keep = [];                 % a kept model share applies to one quarter: t+1 tries the new shares
if ~isempty(A)
    [A.m, S, r, e] = hetlearn.engine.facility('alm', ctx, A.m, S, t, A.stage);    % ALM of (phi_t, n_t)
    ev = [ev, e];
    out.alm = r;
end
for i = 1:nE
    tg = sys.eq(i).target;
    S.phi_hist.(tg)(:, end+1) = S.phi.(tg);
end

% ---- (4) gain update, after the RLS and projection step (DESIGN 18) ----------------
if doRLS
    [S, ev] = gain_update(o, S, errs, ev);
end
end


% =========================================================================
function [Z, Y, S, errs, G] = gain_of_period(o, sys, lv, S, t, getVal, feF, first)
% Regressors, residuals and this period's gains, before the RLS (DESIGN 18):
% the residuals v_t - phi_{t-1}' z_{t-1} of every equation (appended to
% S.fe_hist; NaN in errs.rls when data are missing) and the signed BR
% expectation errors feF form errs; G = hetlearn.gain.<rule>('gain', S.gain,
% errs, opts.gain) holds the gain of each equation's update in t. The gain
% state moves only in gain_update, after the RLS and projection step.
nE = numel(sys.eq);
Z = cell(1, nE);
Y = zeros(1, nE);
tgs = cell(1, nE);
rls = struct();
for i = 1:nE
    e = sys.eq(i);
    tg = e.target;
    tgs{i} = tg;
    [Z{i}, Y(i)] = regressors(e, getVal);
    fe = Y(i) - S.phi.(tg)' * Z{i};
    S.fe_hist.(tg)(end+1, 1) = fe;
    if all(isfinite([Z{i}; Y(i)]))
        rls.(tg) = fe;
    else
        rls.(tg) = NaN;
    end
end
rule = ['hetlearn.gain.' o.gain.rule];
if ~isfield(S, 'gain') || isempty(S.gain)
    S.gain = feval(rule, 'init', sys, lv, o.gain);   % states built without hetlearn.engine.state_init
end
errs = struct('t', t, 'first', logical(first), 'targets', {tgs}, 'rls', rls, ...
    'forecast', feF, 'fe_hist', S.fe_hist, 'phi_hist', S.phi_hist);
G = feval(rule, 'gain', S.gain, errs, o.gain);
end


function [S, ev] = gain_update(o, S, errs, ev)
% (4) Gain update after the RLS and projection step (DESIGN 18): the gain
% state S.gain moves to the end of t with errs (residuals with phi_{t-1},
% signed BR expectation errors), whatever the projection facility did with
% the candidates (PLM block kept or every belief reverted by the ALM
% check): the error is observed either way.
[S.gain, gev] = feval(['hetlearn.gain.' o.gain.rule], 'update', S.gain, errs, o.gain);
ev = [ev, gev];
end


function [z, y] = regressors(e, getVal)
z = zeros(numel(e.reg_names), 1);
for j = 1:numel(e.reg_names)
    z(j) = getVal(e.reg_names{j}, -e.reg_lags(j));
end
if e.constant
    z = [1; z];
end
y = getVal(e.target, 0);
end


function e = mkev(t, type, var, detail)
e = struct('date', double(t), 'type', type, 'variable', var, 'detail', detail);
end


% =========================================================================
function [S, out, ev] = update_nt(ctx, S, t, getVal, F, first, A, X)
% End-of-period update with N agent types. F: the forecasts as they
% enter the aggregate (fitness); X: the second output of hetlearn.engine.ntypes('forecasts') (forecasts
% before the transforms), [] = F itself.
o = ctx.opts;
nt = ctx.nt;
sys = ctx.sys;
lv = ctx.learnVars;
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
out = struct('FE', struct(), 'gain', struct(), 'alm', []);
if ~isfield(ctx, 'blocks') || isempty(ctx.blocks)
    ctx.blocks = hetlearn.plm.blocks(sys);
end
S.n1m_last = hetlearn.engine.shares_for_mode(ctx, S);

% ---- (1) own squared errors, fitness, shares -------------------------------------------
feF = struct();
for i = 1:numel(lv)
    x = lv{i};
    if ~first
        xt = getVal(x, 0);
    end
    for k = nt.byvar.(x).names
        if first
            out.FE.(x).(k{1}) = NaN;
            feF.(x).(k{1}) = NaN;
        else
            e = xt - S.f.(x).(k{1});
            out.FE.(x).(k{1}) = e^2;
            feF.(x).(k{1}) = e;
        end
    end
end
sw = o.switching;
if ~first
    for g = 1:numel(ctx.groups)
        gr = ctx.groups(g);
        names = {nt.types(gr.types).name};
        FEg = zeros(1, numel(names));
        for v = gr.G
            for q = 1:numel(names)
                FEg(q) = FEg(q) + out.FE.(v{1}).(names{q});
            end
        end
        if numel(names) == 2 && gr.types(1) == nt.re
            % the two-type case of hetlearn.switching.discrete_choice (RE first)
            [n1, zRE, zBR] = feval(['hetlearn.switching.' sw.rule], FEg(1), FEg(2), S.U{g}(1), ...
                S.U{g}(2), gr.chi, sw.memory);
            n = [n1, 1 - n1];
            U = [zRE, zBR];
        else
            [n, U] = hetlearn.switching.discrete_choice_n(FEg, S.U{g}, gr.chi, sw.memory);
        end
        if any(~isfinite(n))
            ev(end+1) = mkev(t, 'shares_nan', strjoin(gr.members, ','), ...
                'non-finite share; previous fitness and shares kept'); %#ok<AGROW>
        else
            S.n{g} = n;
            S.U{g} = U;
        end
    end
end

% ---- (2) forecasts made in t ---------------------------------------------------------------
S = hetlearn.engine.ntypes('store', ctx, S, F, X);

% ---- (3) RLS of every learning type and the projection facility ---------------------------------
S.prev = struct('phi', S.phi, 'R', S.R);
nE = numel(sys.eq);
for i = 1:nE
    out.gain.(sys.eq(i).target) = NaN;
end
cand = S.phi;
Rcand = S.R;
upd = false(1, nE);
anyRLS = false;
errsT = struct();
eqType = {};
if nE > 0
    eqType = {sys.eq.type};
end
for j = 1:numel(nt.types)
    ty = nt.types(j);
    if isempty(ty.sys) || ~strcmp(ty.update, 'rls')
        continue
    end
    anyRLS = true;
    k = ty.name;
    ix = find(strcmp(eqType, k));
    tgs = cell(1, numel(ix));
    Z = cell(1, numel(ix));
    Y = zeros(1, numel(ix));
    rls = struct();
    fh = struct();
    ph = struct();
    for q = 1:numel(ix)
        e = sys.eq(ix(q));
        tgs{q} = e.var;
        [Z{q}, Y(q)] = regressors_nt(e, getVal);
        fe = Y(q) - S.phi.(e.target)' * Z{q};
        S.fe_hist.(e.target)(end+1, 1) = fe;
        if all(isfinite([Z{q}; Y(q)]))
            rls.(e.var) = fe;
        else
            rls.(e.var) = NaN;
        end
        fh.(e.var) = S.fe_hist.(e.target);
        ph.(e.var) = S.phi_hist.(e.target);
    end
    fk = struct();
    for v = ty.vars
        fk.(v{1}) = feF.(v{1}).(k);
    end
    gk = ty.gain;
    rule = ['hetlearn.gain.' gk.rule];
    if ~isfield(S, 'gain') || ~isfield(S.gain, k) || isempty(S.gain.(k))
        S.gain.(k) = feval(rule, 'init', ty.sys, intersect(ty.vars, ty.sys.targets, 'stable'), gk);
    end
    errs = struct('t', t, 'first', logical(first), 'targets', {tgs}, 'rls', rls, ...
        'forecast', fk, 'fe_hist', fh, 'phi_hist', ph);
    G = feval(rule, 'gain', S.gain.(k), errs, gk);
    errsT.(k) = errs;
    for q = 1:numel(ix)
        e = sys.eq(ix(q));
        if ~all(isfinite([Z{q}; Y(q)]))
            ev(end+1) = mkev(t, 'rls_missing', e.target, 'missing data; beliefs kept'); %#ok<AGROW>
            continue
        end
        g = G.(e.var);
        out.gain.(e.target) = g;
        [cand.(e.target), Rcand.(e.target)] = hetlearn.rls.update(S.phi.(e.target), S.R.(e.target), Z{q}, Y(q), g);
        upd(ix(q)) = true;
    end
end
if anyRLS
    if strcmp(hetlearn.engine.facility('name', o), 'plm_alm')
        [S, e] = hetlearn.engine.facility('plm', ctx, S, cand, Rcand, upd, t);
        ev = [ev, e];
    else
        S.phi = cand;
        S.R = Rcand;
    end
end
S.n1m_keep = [];
if ~isempty(A)
    [A.m, S, r, e] = hetlearn.engine.facility('alm', ctx, A.m, S, t, A.stage);
    ev = [ev, e];
    out.alm = r;
end
for i = 1:nE
    tg = sys.eq(i).target;
    S.phi_hist.(tg)(:, end+1) = S.phi.(tg);
end

% ---- (4) gain updates, after the RLS and projection step ------------------------------------------
ks = fieldnames(errsT);
for q = 1:numel(ks)
    k = ks{q};
    ty = nt.types(strcmp(nt.names, k));
    [S.gain.(k), gev] = feval(['hetlearn.gain.' ty.gain.rule], 'update', S.gain.(k), errsT.(k), ty.gain);
    for i = 1:numel(gev)
        p = strsplit(gev(i).variable, ',');
        gev(i).variable = strjoin(strcat(p, ['__' k]), ',');
    end
    ev = [ev, gev]; %#ok<AGROW>
end
end


function [z, y] = regressors_nt(e, getVal)
z = zeros(numel(e.reg_vars), 1);
for j = 1:numel(e.reg_vars)
    z(j) = getVal(e.reg_vars{j}, -e.reg_lags(j));
end
if e.constant
    z = [1; z];
end
y = getVal(e.var, 0);
end
