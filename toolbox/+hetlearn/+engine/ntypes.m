function varargout = ntypes(cmd, varargin)
%NTYPES  Engine support for N agent types (docs/USER_GUIDE.md sections 7.1-7.2).
%
%   tf       = hetlearn.engine.ntypes('on', ctx)
%   [S, ctx] = hetlearn.engine.ntypes('init', ctx, m, H)
%   [F, X]   = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, src, t)
%   S        = hetlearn.engine.ntypes('store', ctx, S, F, X)
%   d        = hetlearn.engine.ntypes('seed', ctx, S, d, t0)
%   out      = hetlearn.engine.ntypes('no_update', ctx)
%
%   The N-type path of the engine is on when hetlearn.load_model returned
%   info.nt (expectations.types, forecast transforms, shares.init or
%   shares.fixed; hetlearn.agent_types). Without it every engine function
%   runs its two-type code unchanged.
%
%   'on'         true when ctx.nt is set (by 'init', from ctx.info.nt)
%   'init'       called by hetlearn.engine.state_init: ctx.nt; share groups
%                ctx.groups(g) (.G, .members as before, plus .types =
%                population types of the group, indices into ctx.nt.types,
%                .chi intensity = switching.intensity) and ctx.groupOf; the
%                initial state
%                  S.phi.<key>, S.R.<key>   beliefs of every learning type, key
%                                           <target>__<type> (ctx.sys, the keyed
%                                           system of hetlearn.load_model)
%                  S.fe_hist.<key>, S.phi_hist.<key>
%                  S.gain.<type>            gain state of each learning type,
%                                           hetlearn.gain.<rule>('init', its system,
%                                           its targets, its gain options)
%                  S.U{g}, S.n{g}           fitness and discrete-choice shares of
%                                           group g (its population types)
%                  S.f.<x>.<type>           last forecasts (NaN at the start)
%                Initial shares: shares.init (struct by type; a type not listed
%                0); [] = shares.init_n2 for the default pair RE/BR, equal
%                shares otherwise. Initial fitness:
%                hetlearn.switching.init_fitness_n. Initial beliefs as before
%                (beliefs.init.method), per type with its own system. Errors
%                (hetlearn:engine:types): history.mode 'inversion' (the
%                history stages are 're_smoother' and
%                'kalman'), mode 'learning' with more than one non-RE type
%                in a group, fixed_n2 without exactly one non-RE type,
%                universal groups whose variables have different types.
%                Density forecasts run on the general path of
%                hetlearn.density.run.
%   'forecasts'  [F, X]: F.<x>.<type> the forecast of x_{t+1} made in t by
%                each type, as it enters the aggregate expectation x_exp1:
%                the type's forecast <x>_exp1_<type> after the forecast
%                transforms that act on its term (without
%                transforms the forecast itself), the forecast that fitness,
%                FE_<type> and f_<type> use. X.base.<x>.<type> = the forecast
%                before the transforms. src 'history' (RE smoother history,
%                nothing simulated; also the Kalman history, whose getVal
%                serves the agents' real-time data,
%                hetlearn.engine.kalman_history): the 're' type reads
%                <x>_exp1_RE(t) from the history databank, 'plm' types
%                hetlearn.plm.forecast_value with phi_{t-1} on the type's
%                information set, 'rule' types their expression on the
%                databank, 're_mean' types the RE type's forecast plus the
%                mean belief in force. Transforms use the databank (x{-1}
%                and the diagnostic reference). src 'model' (forecast stage):
%                every <x>_exp1_<type>(t) of the simulated databank, the
%                'plm', 'rule' and 're_mean' ones asserted equal to the same
%                formulas (1e-9, error hetlearn:engine:timing).
%   'store'      S.f = F, S.fb = X.base
%   'seed'       the forecast databank d at t0 (the origin): with a 're_mean'
%                type, <x>_exp1_RE(t0) = the RE forecast of the history stage
%                (the target <x>_feRE of t0+1 uses it)
%   'no_update'  the per-period output of a period without an update (record)
%
%   See also hetlearn.agent_types, hetlearn.engine.update_learning,
%   hetlearn.switching.discrete_choice_n.

switch cmd
    case 'on'
        ctx = varargin{1};
        varargout{1} = isfield(ctx, 'nt') && ~isempty(ctx.nt);
    case 'init'
        [varargout{1:2}] = init(varargin{:});
    case 'forecasts'
        [varargout{1:2}] = forecasts(varargin{:});
    case 'store'
        varargout{1} = store(varargin{:});
    case 'seed'
        varargout{1} = seed(varargin{:});
    case 'no_update'
        varargout{1} = no_update(varargin{:});
    otherwise
        error('hetlearn:engine:ntypes', 'Unknown call hetlearn.engine.ntypes(''%s'', ...).', cmd);
end
end


% =========================================================================
function [S, ctx] = init(ctx, m, H)
o = ctx.opts;
nt = ctx.info.nt;
ID = 'hetlearn:engine:types';
if ~any(strcmp(o.history.mode, {'re_smoother', 'kalman'}))
    % hetlearn.load_options refuses this first (hetlearn:options:unsupported); kept for direct engine calls
    error(ID, ['N agent types, forecast transforms, shares.init or shares.fixed with ' ...
        'history.mode = ''%s'' are not supported: use history.mode = ''re_smoother'' or ''kalman''.'], o.history.mode);
end
lv = ctx.learnVars;
sys = ctx.sys;
if ~nt.types(nt.re).inpop
    for nm = {'init', 'fixed'}
        s = o.shares.(nm{1});
        if isstruct(s) && isfield(s, 'RE') && s.RE ~= 0
            error(ID, ['shares.%s.RE = %g, but the RE type is not in expectations.types (not listed, it is ' ...
                'generated with share 0); list it to give it a share.'], nm{1}, s.RE);
        end
    end
end

% ---- rule functions ------------------------------------------------------------
for j = 1:numel(nt.types)
    nt.types(j).fn = struct();
    if strcmp(nt.types(j).kind, 'rule')
        for i = 1:numel(nt.types(j).vars)
            x = nt.types(j).vars{i};
            nt.types(j).fn.(x) = str2func(['@(v) ' nt.types(j).rule.(x).mexpr]);
        end
    end
end

% ---- beliefs of every learning type ---------------------------------------------------
phi = struct();
R = struct();
for j = 1:numel(nt.types)
    t = nt.types(j);
    if isempty(t.sys)
        continue
    end
    switch o.beliefs.init.method
        case 're_moments'
            [p, r] = hetlearn.init.re_moments(m, t.sys);
        case 'training_ols'
            [p, r] = hetlearn.init.training_ols(t.sys, hetlearn.engine.history_db(o, H), ...
                hetlearn.util.to_dates(o.beliefs.init.training_range));
        case 'user'
            [pf, rf] = hetlearn.init.re_moments(m, t.sys);
            [p, r] = hetlearn.init.user(t.sys, o.beliefs.init.values, pf, rf);
    end
    for q = 1:numel(t.sys.eq)
        tg = t.sys.eq(q).target;
        phi.([tg '__' t.name]) = p.(tg);
        R.([tg '__' t.name]) = r.(tg);
    end
end

% ---- share groups -----------------------------------------------------------------------
groups = struct('G', {}, 'members', {}, 'types', {}, 'chi', {});
groupOf = struct();
switch o.shares.structure
    case 'per_variable'
        for i = 1:numel(lv)
            groups(i).G = lv(i);
            groups(i).members = lv(i);
            groupOf.(lv{i}) = i;
        end
    case 'universal'
        G = reshape(cellstr(o.shares.master), 1, []);
        bad = setdiff(G, lv);
        if ~isempty(bad)
            error('hetlearn:engine:master', ...
                'shares.master must name learning variables; not learning: %s.', strjoin(bad, ', '));
        end
        if ~isempty(lv)
            groups(1).G = G;
            groups(1).members = lv;
            for i = 1:numel(lv)
                groupOf.(lv{i}) = 1;
            end
        end
end
for g = 1:numel(groups)
    vs = unique([groups(g).G, groups(g).members], 'stable');
    b = nt.byvar.(vs{1});
    tix = b.types(b.inpop);
    for i = 2:numel(vs)
        bi = nt.byvar.(vs{i});
        if ~isequal(bi.types(bi.inpop), tix)
            error(ID, ['shares.structure = ''universal'': the variables of the share group (%s) must have the ' ...
                'same agent types; %s and %s differ.'], strjoin(vs, ', '), vs{1}, vs{i});
        end
    end
    if isempty(tix)
        error(ID, 'Share group {%s} has no agent types.', strjoin(vs, ', '));
    end
    groups(g).types = tix;
    groups(g).chi = o.switching.intensity;
end
ctx.groups = groups;
ctx.groupOf = groupOf;

% ---- initial shares and fitness -----------------------------------------------------------
S = struct();
S.phi = phi;
S.R = R;
S.U = cell(1, numel(groups));
S.n = cell(1, numel(groups));
for g = 1:numel(groups)
    tix = groups(g).types;
    names = {nt.types(tix).name};
    n0 = initial_shares(o, nt, names, o.shares.init, 'shares.init');
    S.n{g} = n0;
    S.U{g} = hetlearn.switching.init_fitness_n(n0, groups(g).chi);
end

% ---- mode semantics ----------------------------------------------------------------------------
nt.fixed = struct();
for i = 1:numel(lv)
    x = lv{i};
    b = nt.byvar.(x);
    nonRE = b.types(b.inpop & b.types ~= nt.re);
    switch o.expectations.mode
        case 'learning'
            if numel(nonRE) ~= 1
                error(ID, ['expectations.mode = ''learning'' puts share 1 on the single non-RE type of each ' ...
                    'variable; %s has %d (%s). Use ''fixed_shares'' or ''switching''.'], x, numel(nonRE), ...
                    strjoin({nt.types(nonRE).name}, ', '));
            end
        case 'fixed_shares'
            v = zeros(1, numel(b.types));
            if ~isempty(o.shares.fixed)
                for jj = 1:numel(b.types)
                    k = nt.types(b.types(jj)).name;
                    if b.inpop(jj) && isfield(o.shares.fixed, k)
                        v(jj) = o.shares.fixed.(k);
                    end
                end
                if abs(sum(v) - 1) > 1e-10
                    error(ID, 'shares.fixed: the shares of the types of %s sum to %.12g, not 1.', x, sum(v));
                end
            else
                f2 = o.shares.fixed_n2;
                if isstruct(f2)
                    if ~isfield(f2, x)
                        error('hetlearn:engine:fixedShares', ...
                            'shares.fixed_n2 is a struct but has no entry for learning variable %s.', x);
                    end
                    f2 = f2.(x);
                end
                if numel(nonRE) ~= 1
                    error(ID, ['shares.fixed_n2 is the two-type shorthand (RE and one other type); %s has %d ' ...
                        'non-RE types: use shares.fixed.'], x, numel(nonRE));
                end
                v(b.types == nt.re) = 1 - f2;
                v(b.types == nonRE) = f2;
            end
            nt.fixed.(x) = v;
    end
end
ctx.nt = nt;

% ---- forecasts, histories, gains -----------------------------------------------------------
S.f = struct();
for i = 1:numel(lv)
    x = lv{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        t = nt.types(b.types(jj));
        S.f.(x).(t.name) = NaN;
    end
end
S.fe_hist = struct();
S.phi_hist = struct();
for q = 1:numel(sys.eq)
    S.fe_hist.(sys.eq(q).target) = zeros(0, 1);
    S.phi_hist.(sys.eq(q).target) = zeros(numel(sys.eq(q).param_names), 0);
end
S.gain = struct();
for j = 1:numel(nt.types)
    t = nt.types(j);
    if isempty(t.sys)
        continue
    end
    % the type's learning variables with a PLM equation (gain.koz.master '' = the first of them)
    S.gain.(t.name) = feval(['hetlearn.gain.' t.gain.rule], 'init', t.sys, ...
        intersect(t.vars, t.sys.targets, 'stable'), t.gain);
end

% ---- forecasts as they enter the aggregate: the transforms of each type's term ------------------
ctx.nt.score = score_steps(ctx);
ctx.nt.has_tf = ~isempty(fieldnames(ctx.nt.score));
end


% =========================================================================
function sc = score_steps(ctx)
% sc.<x>.<type>: the forecast transforms acting on the type's term of x_exp1 (the aggregate, not
% the equation copies), in list order, as the generator writes them (hetlearn.extend_model tf_chain,
% tf_unblocked, tf_expr), with their parameter values. Empty without transforms.
sc = struct();
info = ctx.info;
if ~isfield(info, 'meta') || ~isfield(info.meta, 'transforms') || isempty(info.meta.transforms)
    return
end
Tm = info.meta.transforms;
T = Tm.list;
nt = ctx.nt;
P = info.params;
anch = strcmp(ctx.opts.expectations.re_variant, 'anchored');
degv = {};
if isfield(Tm, 'deg_vars')
    degv = Tm.deg_vars;
end
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        ty = nt.types(b.types(jj));
        k = ty.name;
        st = struct('kind', {}, 'a', {}, 'b', {}, 'ref', {}, 'reflag', {});
        for q = 1:numel(T)
            t = T(q);
            if ~((t.typesAll || any(strcmp(t.types, k))) && any(strcmp(t.globL, x)))
                continue
            end
            if ~isempty(Tm.blocked) && any(strcmp({Tm.blocked.var}, x) & strcmp({Tm.blocked.type}, k) & [Tm.blocked.i] == q)
                continue
            end
            p = t.prefix;
            s = struct('kind', t.kind, 'a', 0, 'b', 0, 'ref', '', 'reflag', 0);
            switch t.kind
                case 'multiplier'
                    s.a = P.([p '_D__' k]);
                case 'myopia_anchoring'
                    s.a = P.([p '_omega']);
                    s.b = P.([p '_b']);
                case 'diagnostic'
                    s.a = P.([p '_theta']);
                    if anch && strcmp(ty.kind, 're')
                        if strcmp(ty.info, 'lagged') && any(strcmp(degv, x))
                            s.ref = [x '_DEg_RE'];
                            s.reflag = 1;
                        else
                            continue               % not in the anchored text (refused by hetlearn.load_model)
                        end
                    elseif strcmp(ty.info, 'lagged')
                        s.ref = [x '_REt3'];
                        s.reflag = 2;
                    else
                        s.ref = [x '_REt2'];
                        s.reflag = 1;
                    end
            end
            st(end+1) = s; %#ok<AGROW>
        end
        if ~isempty(st)
            sc.(x).(k) = st;
        end
    end
end
end


function f = apply_steps(st, f, getVal, x)
% a type's forecast through the transforms of its term (score_steps)
for q = 1:numel(st)
    s = st(q);
    switch s.kind
        case 'multiplier'
            f = s.a * f;
        case 'myopia_anchoring'
            f = s.a * f;
            if s.b ~= 0
                f = f + s.b * getVal(x, -1);
            end
        case 'diagnostic'
            f = (1 + s.a) * f;
            if s.a ~= 0
                f = f - s.a * getVal(s.ref, -s.reflag);
            end
    end
end
end


function n0 = initial_shares(o, nt, names, s, what)
% shares by type name of one group (population types, in nt order)
N = numel(names);
if isempty(s)
    if nt.default_pair && N == 2
        n0 = zeros(1, 2);
        n0(strcmp(names, 'BR')) = o.shares.init_n2;
        n0(strcmp(names, 'RE')) = 1 - o.shares.init_n2;
    else
        n0 = ones(1, N) / N;
    end
    return
end
n0 = zeros(1, N);
for k = 1:N
    if isfield(s, names{k})
        n0(k) = s.(names{k});
    end
end
if abs(sum(n0) - 1) > 1e-10
    error('hetlearn:engine:types', '%s: the shares of %s sum to %.12g, not 1.', what, strjoin(names, ', '), sum(n0));
end
end


% =========================================================================
function [F, X] = forecasts(ctx, S, getVal, src, t)
nt = ctx.nt;
lv = ctx.learnVars;
model = strcmp(src, 'model');
F = struct();
Fb = struct();
hasSc = isfield(nt, 'score') && ~isempty(fieldnames(nt.score));
for i = 1:numel(lv)
    x = lv{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        ty = nt.types(b.types(jj));
        k = ty.name;
        fv = b.fvars{jj};
        switch ty.kind
            case 're_mean'
                p = S.phi.([ty.zvar.(x) '__' k]);
                f = getVal(b.fvars{b.re_pos}, 0) + p(1);
                if model
                    fm = getVal(fv, 0);
                    if ~(abs(f - fm) < 1e-9 * max(1, abs(fm)))
                        error('hetlearn:engine:timing', ['Period %s: %s from the model (%.12g) differs from the RE ' ...
                            'forecast plus the mean belief of type %s (%.12g).'], char(dat2str(t)), fv, fm, k, f);
                    end
                    f = fm;
                end
            case 're'
                f = getVal(fv, 0);
            case 'plm'
                f = hetlearn.plm.forecast_value(ty.sys, type_phi(S.phi, ty), getVal, x);
                if model
                    fm = getVal(fv, 0);
                    if ~(abs(f - fm) < 1e-9)
                        error('hetlearn:engine:timing', ['Period %s: %s from the model (%.12g) differs from the ' ...
                            'PLM forecast of type %s with phi_{t-1} (%.12g, information ''%s'').'], ...
                            char(dat2str(t)), fv, fm, k, f, ty.sys.info);
                    end
                    f = fm;
                end
            case 'rule'
                f = rule_value(ty, x, getVal);
                if model
                    fm = getVal(fv, 0);
                    if ~(abs(f - fm) < 1e-9 * max(1, abs(fm)))
                        error('hetlearn:engine:timing', ['Period %s: %s from the model (%.12g) differs from the ' ...
                            'rule of type %s evaluated on the data (%.12g).'], char(dat2str(t)), fv, fm, k, f);
                    end
                    f = fm;
                end
        end
        Fb.(x).(k) = f;
        if hasSc && isfield(nt.score, x) && isfield(nt.score.(x), k)
            f = apply_steps(nt.score.(x).(k), f, getVal, x);
        end
        F.(x).(k) = f;
    end
end
X = struct('base', Fb);
end


function p = type_phi(phi, ty)
% the type's beliefs by (unkeyed) target
p = struct();
for q = 1:numel(ty.sys.eq)
    tg = ty.sys.eq(q).target;
    p.(tg) = phi.([tg '__' ty.name]);
end
end


function f = rule_value(ty, x, getVal)
% a rule type's forecast: its expression on the databank (terms 'var' and 'param', hetlearn.plm.rule_terms)
R = ty.rule.(x);
v = zeros(max(1, numel(R.terms)), 1);
for j = 1:numel(R.terms)
    tm = R.terms(j);
    switch tm.kind
        case 'var'
            v(j) = getVal(tm.name, -tm.lag);
        case 'param'
            v(j) = R.param_values.(tm.name);
    end
end
f = ty.fn.(x)(v);
end


% =========================================================================
function S = store(~, S, F, X)
% S.f = F (the forecasts as they enter the aggregate); S.fb = the forecasts before the transforms
% (X.base, = F without transforms)
Fb = F;
if nargin >= 4 && isstruct(X) && isfield(X, 'base')
    Fb = X.base;
end
S.f = F;
S.fb = Fb;
end


% =========================================================================
function d = seed(ctx, S, d, t0)
nt = ctx.nt;
lv = ctx.learnVars;
for i = 1:numel(lv)
    x = lv{i};
    % a re_mean type: its target <x>_feRE = x - <x>_exp1_RE{-1} of t0+1 uses the RE forecast made
    % at the origin, which the history stage took from its databank (the predictions under 'filtered')
    b = nt.byvar.(x);
    if any(arrayfun(@(j) strcmp(nt.types(j).kind, 're_mean'), b.types)) && isfield(S, 'fb') ...
            && isfield(S.fb, x) && isfield(S.fb.(x), 'RE') && isfinite(S.fb.(x).RE)
        d.([x '_exp1_RE'])(t0) = S.fb.(x).RE;
    end
end
end


% =========================================================================
function out = no_update(ctx)
nt = ctx.nt;
out = struct('FE', struct(), 'gain', struct(), 'alm', []);
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    for k = nt.byvar.(x).names
        out.FE.(x).(k{1}) = NaN;
    end
end
for q = 1:numel(ctx.sys.eq)
    out.gain.(ctx.sys.eq(q).target) = NaN;
end
end
