function varargout = anchor_update(cmd, varargin)
%ANCHOR_UPDATE  Per-quarter level-k coefficients (docs/DESIGN_br_extensions.md 1.4, phase P4).
%
%   [S, ev] = hetlearn.engine.anchor_update('compute', ctx, S, t)
%   P       = hetlearn.engine.anchor_update('params', ctx, S)
%   f       = hetlearn.engine.anchor_update('value', ctx, S, j, x, getVal)
%   tf      = hetlearn.engine.anchor_update('on', ctx)
%
%   Level types ('level', fields base and k of expectations.types) forecast
%   with the coefficients of the level below, iterated from a level-0 rule:
%   for a chain (one per level-0 type, ctx.nt.levels(c)), in quarter t after
%   the belief update and before the ALM check,
%     level-0 economy: the model with share 1 on the level-0 type for the
%                      chain's variables (the other learning variables on the
%                      RE type), its beliefs phi_t;
%     level j >= 1   : the slot (the chain's level type with the largest k)
%                      with the level-j coefficients and share 1;
%   each economy is solved by IRIS and the level-(j+1) coefficients are the
%   anchored forecast E_{t-L} x_{t+1} = k + C s_{t-L} of that economy on the
%   original states (hetlearn.anchor_coefficients; L = 1 for 'lagged'
%   information, the two-step forecast of the review's F_{j+1} = H_j^2, and 0
%   for 'current'), j = 0 .. K-1. Level type q gets level k_q. K IRIS solves per
%   chain and quarter. The coefficients are in force in t+1 (the beliefs they
%   come from are phi_t), so the history stage evaluates level forecasts with
%   them on the history databank and the forecast stage assigns them as model
%   parameters (hetlearn.engine.facility 'params').
%
%   'compute'  S.levels.<type>.<x> = [k; C] (column, C aligned with
%              ctx.nt.levels(c).states). A level economy without a unique
%              stable solution stops the run under projection.facility 'none'
%              (error hetlearn:engine:levelNoSolution); under 'alm' and
%              'plm_alm' every belief goes back to its value before this
%              period's update and the levels of S.prev are kept (event
%              'projection_level'), or the run stops when there is nothing to
%              revert. ctx.nt.level_m is the engine's model (set by
%              hetlearn.engine.ntypes 'init').
%   'params'   the level coefficients of S as model parameters (struct; empty
%              without level types or before the first 'compute')
%   'value'    the forecast of x by level type j (index into ctx.nt.types)
%              from S.levels and getVal(name, k) = value at t + k
%
%   See also hetlearn.anchor_coefficients, hetlearn.engine.ntypes,
%   hetlearn.engine.update_learning.

switch cmd
    case 'on'
        ctx = varargin{1};
        varargout{1} = isfield(ctx, 'nt') && ~isempty(ctx.nt) && isfield(ctx.nt, 'levels') && ~isempty(ctx.nt.levels);
    case 'compute'
        [varargout{1:2}] = compute(varargin{:});
    case 'params'
        varargout{1} = params(varargin{:});
    case 'value'
        varargout{1} = value(varargin{:});
    otherwise
        error('hetlearn:engine:anchor', 'Unknown call hetlearn.engine.anchor_update(''%s'', ...).', cmd);
end
end


% =========================================================================
function [S, ev] = compute(ctx, S, t)
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
nt = ctx.nt;
if ~isfield(nt, 'levels') || isempty(nt.levels)
    return
end
m = nt.level_m;
lv = ctx.learnVars;
lev = struct();
for c = 1:numel(nt.levels)
    L = nt.levels(c);
    coef = cell(1, L.K);
    for j = 0:L.K - 1
        n = struct();
        for i = 1:numel(lv)
            x = lv{i};
            b = nt.byvar.(x);
            v = zeros(1, numel(b.types));
            if any(strcmp(L.vars, x))
                if j == 0
                    v(b.types == L.base) = 1;
                else
                    v(b.types == L.slot) = 1;
                end
            else
                v(b.re_pos) = 1;
            end
            n.(x) = v;
        end
        P = hetlearn.engine.facility('params', ctx.sys, S.phi, lv, n);
        Q = params(ctx, S);
        if j >= 1
            st = nt.types(L.slot);
            for i = 1:numel(L.vars)
                pn = st.lev.(L.vars{i});
                cv = coef{j}(:, i);
                for q = 1:numel(pn)
                    Q.(pn{q}) = cv(q);
                end
            end
        end
        f = fieldnames(Q);
        for q = 1:numel(f)
            P.(f{q}) = Q.(f{q});
        end
        m = assign(m, P);
        ws = warning('off', 'all');
        try
            [m, ok, msg, si] = hetlearn.engine.solve_model(m, ctx.spec);
        catch err
            ok = false;
            msg = err.message;
            si = struct('iris_ok', false);
        end
        warning(ws);
        if ~(ok && si.iris_ok)
            cj = [];
            if j >= 1
                cj = coef{j};
            end
            [S, ev, done] = no_solution(ctx, S, t, L, j, msg, cj);
            if done
                return
            end
        end
        R = hetlearn.anchor_coefficients(m, L.vars, L.states, 'lag', L.lag, 'chain', L.chain, 'check', false, ...
            'error_id', 'hetlearn:engine:levelStates', 'what', sprintf('level-%d forecast (economy of level %d on %s)', ...
            j + 1, j, nt.types(L.base).name));
        coef{j + 1} = [R.k'; R.C'];      % one column per variable: [k; C]
    end
    for q = L.types
        k = nt.types(q).k;
        for i = 1:numel(L.vars)
            lev.(nt.types(q).name).(L.vars{i}) = coef{k}(:, i);
        end
    end
end
S.levels = lev;
end


function [S, ev, done] = no_solution(ctx, S, t, L, j, msg, cj)
% a level economy without a unique stable solution: stop under 'none', else revert the beliefs.
% cj: the level-j coefficients of that economy (j >= 1), for the message
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
fac = hetlearn.engine.facility('name', ctx.opts);
nt = ctx.nt;
what = sprintf(['Period %s: the level-%d economy of the level types on %s (share 1 on %s for %s) has no unique ' ...
    'stable solution (%s)'], date_text(t), j, nt.types(L.base).name, ...
    ternary(j == 0, nt.types(L.base).name, sprintf('level %d', j)), strjoin(L.vars, ', '), msg);
bt = nt.types(L.base);
if ~isempty(bt.sys)
    c = {};
    for q = 1:numel(bt.sys.eq)
        tg = [bt.sys.eq(q).target '__' bt.name];
        c{end+1} = sprintf('%s = [%s]', tg, strjoin(arrayfun(@(v) sprintf('%.6g', v), S.phi.(tg)(:)', ...
            'UniformOutput', false), ' ')); %#ok<AGROW>
    end
    what = sprintf('%s; beliefs of %s: %s', what, bt.name, strjoin(c, ', '));
end
if ~isempty(cj)
    for i = 1:numel(L.vars)
        p = 1 + find(strcmp(L.states, L.vars{i}), 1);
        if ~isempty(p)
            what = sprintf('%s; level-%d forecast of %s: constant %.4g, coefficient on %s{-1} %.4g', what, j, ...
                L.vars{i}, cj(1, i), L.vars{i}, cj(p, i));
        end
    end
end
canRevert = isfield(S, 'prev') && isstruct(S.prev) && isfield(S.prev, 'levels') && ~isempty(S.prev.levels);
if strcmp(fac, 'none') || ~canRevert
    error('hetlearn:engine:levelNoSolution', '%s. projection.facility = ''%s''%s.', what, fac, ...
        ternary(strcmp(fac, 'none'), ' restricts nothing', ', and no earlier levels to keep'));
end
S.phi = S.prev.phi;
S.R = S.prev.R;
S.levels = S.prev.levels;
ev(end+1) = struct('date', double(t), 'type', 'projection_level', 'variable', strjoin(L.vars, ','), ...
    'detail', [what '; every belief reverted to its value before this period''s update, levels kept']);
done = true;
end


% =========================================================================
function P = params(ctx, S)
P = struct();
if ~isfield(S, 'levels') || isempty(S.levels)
    return
end
nt = ctx.nt;
ks = fieldnames(S.levels);
for i = 1:numel(ks)
    j = find(strcmp(nt.names, ks{i}), 1);
    vs = fieldnames(S.levels.(ks{i}));
    for q = 1:numel(vs)
        pn = nt.types(j).lev.(vs{q});
        cv = S.levels.(ks{i}).(vs{q});
        for r = 1:numel(pn)
            P.(pn{r}) = cv(r);
        end
    end
end
end


% =========================================================================
function f = value(ctx, S, j, x, getVal)
ty = ctx.nt.types(j);
cv = S.levels.(ty.name).(x);
L = ctx.nt.levels(find(arrayfun(@(l) any(l.types == j), ctx.nt.levels), 1));
[~, sv, sl] = hetlearn.plm.anchor_names('x', L.states);
f = cv(1);
for q = 1:numel(sv)
    f = f + cv(1 + q) * getVal(sv{q}, -(sl(q) + L.lag));
end
end


function s = date_text(t)
try
    s = char(dat2str(t));
catch
    s = 'initial state';
end
end


function v = ternary(c, a, b)
if c
    v = a;
else
    v = b;
end
end
