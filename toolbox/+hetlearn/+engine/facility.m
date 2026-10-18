function varargout = facility(cmd, varargin)
%FACILITY  Projection facility: PLM block check and ALM check (DESIGN 4.4, user decision 2026-10-18).
%
%   [S, ev] = hetlearn.engine.facility('plm', ctx, S, cand, Rcand, upd, t)
%   [m, S, r, ev] = hetlearn.engine.facility('alm', ctx, m, S, t, stage)
%   [m, S, r, ev] = hetlearn.engine.facility('solve', ctx, m, S, n1m, t, stage)
%   P   = hetlearn.engine.facility('params', sys, phi, learnVars, n1m)
%   [B, rho] = hetlearn.engine.facility('block_roots', ctx, phi)
%   name = hetlearn.engine.facility('name', opts)
%
%   The only stabilising device of the toolbox, option projection.facility:
%     'none'     no restriction. A model that cannot be solved in a period
%                where it must be simulated stops the run (error
%                hetlearn:engine:noSolution: date, stage, shares, each PLM
%                block's largest root, IRIS stability flag). A linear model
%                without leads (anchored RE, every forward-looking variable
%                learning) is simulated as is by the backward simulator
%                ('explosive' event, hetlearn.engine.step). Nothing is
%                checked in a history stage that does not simulate the model.
%     'alm'      restrict the actual law of motion only: the PLMs are never
%                touched; if the model with the new beliefs and shares has
%                no unique stable solution (for a model without leads: a
%                transition root with modulus above 1), every belief (phi
%                and R of every PLM equation, auxiliary ones included) goes
%                back to its value before this period's update and the
%                model is solved again (event 'projection_alm').
%     'plm_alm'  (default) first the PLM blocks one by one (case by case): a
%                block whose candidate beliefs have a largest root above 1
%                in modulus (AR(1): |beta| > 1) keeps its previous phi and R
%                (event 'projection_plm'), the other blocks update; then the
%                ALM check of 'alm'.
%   Under 'alm' and 'plm_alm', if the model is still unstable with every
%   belief at its previous value, the previous quarter's model shares are
%   kept as well (user decision 2026-10-18): the beliefs and model shares
%   last in force, which solved, stay in the model for that quarter (event
%   'projection_alm_shares'; S.n1m_keep, read by
%   hetlearn.engine.shares_for_mode for one quarter). Switching carries on:
%   the fitness measures and discrete-choice shares (S.zetaRE, S.zetaBR,
%   S.n1) keep their update, and the next quarter tries the new shares
%   again. Only when that model was never solved (the initial beliefs and
%   shares at the first check of a run) does the run stop: error
%   hetlearn:engine:almUnstable (date, stage, shares, beliefs, IRIS flag).
%   Gain processes (S.gain) are not touched by the facility.
%
%   Calls
%     'plm'    PLM part, from hetlearn.engine.update_learning: cand, Rcand
%              are the RLS candidates by target, upd(i) true when equation
%              i of sys.eq was updated this period; S.phi/S.R hold the
%              previous beliefs. Returns S with the accepted beliefs.
%              Blocks: hetlearn.plm.blocks (ctx.blocks when present).
%     'alm'    ALM part at the end of period t (after the update): solves
%              the model with (phi_t, n_t), the model in force in t+1 (the
%              shares from hetlearn.engine.shares_for_mode). Skipped (r.skipped)
%              when every model share of the BR agents is 0 (the ALM is the RE
%              model) or the facility is 'none'. Reverts S.phi, S.R to S.prev
%              (set by update_learning) when the ALM is unstable; then, if
%              needed, keeps the model shares S.n1m_last (in force in t)
%              for t+1.
%     'solve'  start-of-period solve of the stages that simulate (forecast,
%              inversion) when the parameters differ from the last check:
%              'none' -> noSolution error on failure; 'alm'/'plm_alm' ->
%              the same steps (r.reverted: the caller re-records the
%              previous period's beliefs; r.kept_shares: the caller uses
%              r.n1m in this period) or almUnstable.
%     r        struct: .checked, .skipped, .reverted (beliefs reverted),
%              .kept_shares, .n1m (model shares of the solved model), .pv
%              (its parameter vector), .n_solve, .time (s), .flag (IRIS flag
%              of the first solve), .m (solved model; 'alm' only)
%
%   See also hetlearn.engine.update_learning, hetlearn.plm.blocks,
%   hetlearn.engine.solve_model.

switch cmd
    case 'plm'
        [varargout{1:2}] = plm_check(varargin{:});
    case 'alm'
        [varargout{1:4}] = alm_check(varargin{:});
    case 'solve'
        [varargout{1:4}] = start_solve(varargin{:});
    case 'params'
        varargout{1} = make_params(varargin{:});
    case 'block_roots'
        [varargout{1:2}] = block_roots(varargin{:});
    case 'name'
        varargout{1} = facility_name(varargin{1});
    otherwise
        error('hetlearn:engine:facility', 'Unknown call hetlearn.engine.facility(''%s'', ...).', cmd);
end
end


% =========================================================================
function f = facility_name(o)
f = 'plm_alm';
if isfield(o, 'projection') && isfield(o.projection, 'facility') && ~isempty(o.projection.facility)
    f = char(o.projection.facility);
end
end


function B = get_blocks(ctx)
if isfield(ctx, 'blocks') && ~isempty(ctx.blocks)
    B = ctx.blocks;
else
    B = hetlearn.plm.blocks(ctx.sys);
end
end


function [S, ev] = plm_check(ctx, S, cand, Rcand, upd, t)
% Case by case: each PLM block on its own, with the candidates of its
% updated equations and the previous beliefs of the others in it.
ev = empty_ev();
sys = ctx.sys;
B = get_blocks(ctx);
for b = 1:numel(B)
    ix = B(b).eqs;
    if ~any(upd(ix))
        continue
    end
    [~, rho] = hetlearn.plm.companion(sys, cand, ix);
    finR = true;
    for i = ix
        finR = finR && all(isfinite(Rcand.(sys.eq(i).target)(:)));
    end
    if isfinite(rho) && rho <= 1 && finR
        continue
    end
    for i = ix
        tg = sys.eq(i).target;
        cand.(tg) = S.phi.(tg);
        Rcand.(tg) = S.R.(tg);
    end
    if isfinite(rho)
        det = sprintf('PLM block {%s}: largest root %.6g > 1 with the candidate beliefs; phi and R of its %d equation(s) kept', ...
            B(b).label, rho, numel(ix));
    else
        det = sprintf('PLM block {%s}: non-finite candidate beliefs; phi and R of its %d equation(s) kept', ...
            B(b).label, numel(ix));
    end
    ev(end+1) = mkev(t, 'projection_plm', B(b).label, det); %#ok<AGROW>
end
S.phi = cand;
S.R = Rcand;
end


function [m, S, r, ev] = alm_check(ctx, m, S, t, stage)
r = new_r();
ev = empty_ev();
if strcmp(facility_name(ctx.opts), 'none')
    return
end
t0 = tic;
n1m = hetlearn.engine.shares_for_mode(ctx, S);
if all_re(ctx.learnVars, n1m)
    r.skipped = true;
    r.time = toc(t0);
    return
end
[m, S, r, ev] = solve_or_revert(ctx, m, S, n1m, t, stage, 'end');
r.checked = true;
r.m = m;
r.time = toc(t0);
end


function [m, S, r, ev] = start_solve(ctx, m, S, n1m, t, stage)
t0 = tic;
[m, S, r, ev] = solve_or_revert(ctx, m, S, n1m, t, stage, 'start');
r.time = toc(t0);
end


function [m, S, r, ev] = solve_or_revert(ctx, m, S, n1m, t, stage, when)
r = new_r();
ev = empty_ev();
sys = ctx.sys;
lv = ctx.learnVars;
fac = facility_name(ctx.opts);
P = make_params(sys, S.phi, lv, n1m);
[m, stable, si] = try_solve(m, P, ctx.spec, fac);
r.n_solve = 1;
r.flag = si.flag;
r.n1m = n1m;
if stable
    r.pv = cell2mat(struct2cell(P));
    return
end
if strcmp(when, 'end')
    where = sprintf('%s (%s stage; ALM check of the beliefs and shares formed at the end of %s, in force from %s)', ...
        char(dat2str(t)), stage, char(dat2str(t)), char(dat2str(t + 1)));
else
    where = sprintf('%s (%s stage)', char(dat2str(t)), stage);
end
if strcmp(fac, 'none')
    [B, rho] = block_roots(ctx, S.phi);
    error('hetlearn:engine:noSolution', ['Period %s: the model has no solution with the beliefs and ' ...
        'shares in force, and projection.facility = ''none'' restricts nothing. IRIS stability flag: %s. ' ...
        'BR shares in the model: %s. Largest root of each PLM block: %s. Beliefs: %s. With ' ...
        'projection.facility = ''plm_alm'' or ''alm'' the beliefs are restricted instead.'], ...
        where, flag_text(si), share_text(lv, n1m), roots_text(B, rho), param_text(sys, S.phi));
end
tgs = {sys.eq.target};
reason1 = flag_text(si);
reason2 = '';
% (2) every belief back to its value before this period's update, shares as they are
if isfield(S, 'prev') && isstruct(S.prev) && ~isempty(fieldnames(S.prev)) && differs(S, sys)
    S.phi = S.prev.phi;
    S.R = S.prev.R;
    r.reverted = true;
    P = make_params(sys, S.phi, lv, n1m);
    [m, stable, si] = try_solve(m, P, ctx.spec, fac);
    r.n_solve = r.n_solve + 1;
    if stable
        ev(end+1) = mkev(t, 'projection_alm', strjoin(tgs, ','), sprintf( ...
            ['ALM unstable with the updated beliefs (%s; BR shares %s); phi and R of all %d PLM equation(s) ' ...
            'reverted to their values before this period''s update'], reason1, share_text(lv, n1m), numel(tgs)));
        r.pv = cell2mat(struct2cell(P));
        return
    end
    reason2 = flag_text(si);
end
% (3) also the previous quarter's model shares (user decision 2026-10-18): the beliefs and
% model shares last in force, which solved, stay in the model; S.n1 (discrete choice) moves on
n1k = [];
if isfield(S, 'n1m_last') && isstruct(S.n1m_last) && ~isequal(S.n1m_last, n1m)
    n1k = S.n1m_last;
    P = make_params(sys, S.phi, lv, n1k);
    [m, stable, si] = try_solve(m, P, ctx.spec, fac);
    r.n_solve = r.n_solve + 1;
    if stable
        S.n1m_keep = n1k;
        if r.reverted
            how = sprintf('with the updated beliefs (%s) and with every belief reverted (%s)', reason1, reason2);
        else
            how = sprintf('with the beliefs of this period, unchanged by its update (%s)', reason1);
        end
        ev(end+1) = mkev(t, 'projection_alm_shares', strjoin(tgs, ','), sprintf( ...
            ['ALM unstable %s at BR shares %s; beliefs and model shares kept at the previous quarter''s ' ...
            'values (BR shares in the model %s; phi and R of all %d PLM equation(s) at their values before ' ...
            'this period''s update); the discrete-choice shares keep updating'], how, share_text(lv, n1m), ...
            share_text(lv, n1k), numel(tgs)));
        r.kept_shares = true;
        r.n1m = n1k;
        r.pv = cell2mat(struct2cell(P));
        return
    end
end
if isempty(n1k)
    n1k = n1m;
end
error('hetlearn:engine:almUnstable', ['Period %s: no stable solution and no earlier solved model to fall ' ...
    'back on (projection.facility = ''%s''). The projection facility reverted every belief to its previous ' ...
    'value and kept the previous model shares, but that model is the one the run started from (the initial ' ...
    'beliefs and shares, first check of the run), and it has no stable solution either. IRIS stability ' ...
    'flag: %s. BR shares in the model: %s. Beliefs: %s.'], where, fac, flag_text(si), share_text(lv, n1k), ...
    param_text(sys, S.phi));
end


function [m, stable, si] = try_solve(m, P, spec, fac)
% Assign and solve; stable per the facility ('none': any solution, the
% backward system included; 'alm'/'plm_alm': unique stable, or a backward
% system with every root inside the unit circle). IRIS warnings of failed
% trial solves are suppressed.
pv = cell2mat(struct2cell(P));
si = struct('flag', '', 'iris_ok', false, 'backward', false, 'maxroot', NaN);
if any(~isfinite(pv))
    si.flag = 'non-finite parameters (beliefs)';
    stable = false;
    return
end
m = assign(m, P);
ws = warning('off', 'all');
try
    [m, ok, ~, si] = hetlearn.engine.solve_model(m, spec);
catch err
    warning(ws);
    si.flag = ['solve error: ' err.message];
    stable = false;
    return
end
warning(ws);
if strcmp(fac, 'none')
    stable = ok;
else
    stable = ok && ~(si.backward && ~(si.maxroot <= 1));
end
end


function tf = differs(S, sys)
tf = false;
for i = 1:numel(sys.eq)
    tg = sys.eq(i).target;
    if ~isequal(S.phi.(tg), S.prev.phi.(tg)) || ~isequal(S.R.(tg), S.prev.R.(tg))
        tf = true;
        return
    end
end
end


function tf = all_re(lv, n1m)
tf = true;
for i = 1:numel(lv)
    if 1 - n1m.(lv{i}) ~= 0
        tf = false;
        return
    end
end
end


function [B, rho] = block_roots(ctx, phi)
B = get_blocks(ctx);
rho = NaN(1, numel(B));
for b = 1:numel(B)
    [~, rho(b)] = hetlearn.plm.companion(ctx.sys, phi, B(b).eqs);
end
end


function P = make_params(sys, phi, lv, n1m)
P = struct();
if ~isempty(sys.eq)
    P = hetlearn.plm.param_values(sys, phi);
end
for i = 1:numel(lv)
    x = lv{i};
    P.(['n1_' x]) = n1m.(x);
    P.(['n2_' x]) = 1 - n1m.(x);
end
end


function r = new_r()
r = struct('checked', false, 'skipped', false, 'reverted', false, 'kept_shares', false, 'n1m', [], ...
    'pv', [], 'n_solve', 0, ...
    'time', 0, 'flag', '', 'm', []);
end


function s = flag_text(si)
s = si.flag;
if isempty(s)
    s = 'none';
end
if si.backward
    s = sprintf('%s (no leads: backward system, largest transition root %.6g)', s, si.maxroot);
end
end


function s = share_text(lv, n1m)
c = cellfun(@(x) sprintf('n2_%s = %.6g', x, 1 - n1m.(x)), lv, 'UniformOutput', false);
s = strjoin(c, ', ');
if isempty(s)
    s = 'none';
end
end


function s = roots_text(B, rho)
c = arrayfun(@(b) sprintf('{%s} %.6g', B(b).label, rho(b)), 1:numel(B), 'UniformOutput', false);
s = strjoin(c, ', ');
if isempty(s)
    s = 'no PLM';
end
end


function s = param_text(sys, phi)
s = 'none';
if isempty(sys.eq)
    return
end
P = hetlearn.plm.param_values(sys, phi);
f = fieldnames(P);
c = cellfun(@(n) sprintf('%s = %.6g', n, P.(n)), f, 'UniformOutput', false);
s = strjoin(c, ', ');
end


function ev = empty_ev()
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
end


function e = mkev(t, type, var, detail)
e = struct('date', double(t), 'type', type, 'variable', var, 'detail', detail);
end
