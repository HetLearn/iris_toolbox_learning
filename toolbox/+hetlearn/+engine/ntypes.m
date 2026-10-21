function varargout = ntypes(cmd, varargin)
%NTYPES  Engine support for N agent types (docs/DESIGN_br_extensions.md 1.1-1.2, phase P2).
%
%   tf       = hetlearn.engine.ntypes('on', ctx)
%   [S, ctx] = hetlearn.engine.ntypes('init', ctx, m, H)
%   F        = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, src, t)
%   S        = hetlearn.engine.ntypes('store', ctx, S, F)
%   d        = hetlearn.engine.ntypes('seed', ctx, S, d, t0)
%   out      = hetlearn.engine.ntypes('no_update', ctx)
%
%   The N-type path of the engine is on when hetlearn.load_model returned
%   info.nt (expectations.types, or the default pair RE/BR with the switching
%   options of DESIGN_br_extensions 1.2; hetlearn.agent_types). Without it
%   every engine function runs its two-type code of 2026-10-20 unchanged.
%
%   'on'         true when ctx.nt is set (by 'init', from ctx.info.nt)
%   'init'       called by hetlearn.engine.state_init: ctx.nt; share groups
%                ctx.groups(g) (.G, .members as before, plus .types =
%                population types of the group, indices into ctx.nt.types,
%                .chi intensity, .C costs) and ctx.groupOf; the initial state
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
%                  S.fh.<x>.<type>          own forecasts of rule types with
%                                           self{-k} terms, newest first
%                Initial shares: shares.init (struct by type; a type not listed
%                0); [] = shares.init_n2 for the default pair RE/BR, equal
%                shares otherwise. Initial fitness:
%                hetlearn.switching.init_fitness_n. Initial beliefs as before
%                (beliefs.init.method), per type with its own system.
%                switching.intensity 'model:bma': chi = 1/(2 sigma^2) per
%                group, sigma^2 the mean over its variables of
%                ctx.info.nt.model_values.bma.sigma2. Errors
%                (hetlearn:engine:types): history.mode other than
%                're_smoother', density forecasts, mode 'learning' with
%                more than one non-RE type in a group, fixed_n2 without
%                exactly one non-RE type, universal groups whose variables
%                have different types.
%   'forecasts'  struct F.<x>.<type>: the forecast of x_{t+1} made in t by
%                each type. src 'history' (RE smoother history, nothing
%                simulated): 're' types read <x>_exp1_<type>(t) from the
%                history databank (a second RE type that forecasts as the RE
%                type reads <x>_exp1_RE, which hetlearn.engine.history_db takes
%                from the predictions under 'filtered' RE states), 'plm' types
%                hetlearn.plm.forecast_value with phi_{t-1} on the type's
%                information set, 'rule' types their expression (self{-k}
%                from S.fh, or the databank before the first own forecast;
%                mean = the type's mean belief in force). src 'model'
%                (forecast stage): every <x>_exp1_<type>(t) of the simulated
%                databank, the 'plm' and 'rule' ones asserted equal to the
%                same formulas (1e-9, error hetlearn:engine:timing).
%   'store'      S.f = F and the own-forecast history S.fh moved by one period
%   'seed'       the forecast databank d at t0 (the origin) and before: the
%                own forecasts S.fh of rule types with self{-k} terms, so the
%                simulated rule continues from the history stage's forecasts
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
        varargout{1} = forecasts(varargin{:});
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
if ~strcmp(o.history.mode, 're_smoother')
    error(ID, ['N agent types (or the switching options of DESIGN_br_extensions 1.2) with history.mode = ''%s'' ' ...
        'are not supported yet: use history.mode = ''re_smoother''.'], o.history.mode);
end
if logical(o.density.enabled)
    error(ID, 'Density forecasts (density.enabled) with N agent types are not supported yet (phase P6).');
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
groups = struct('G', {}, 'members', {}, 'types', {}, 'chi', {}, 'C', {});
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
chi0 = o.switching.intensity;
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
    groups(g).C = [nt.types(tix).cost];
    if ischar(chi0)
        s2 = cellfun(@(v) nt.model_values.bma.sigma2.(v), groups(g).G);
        groups(g).chi = 1 / (2 * mean(s2));
    else
        groups(g).chi = chi0;
    end
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
    S.U{g} = hetlearn.switching.init_fitness_n(n0, groups(g).chi, groups(g).C);
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
S.fh = struct();
for i = 1:numel(lv)
    x = lv{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        t = nt.types(b.types(jj));
        S.f.(x).(t.name) = NaN;
        if strcmp(t.kind, 'rule') && t.self_maxlag > 0
            S.fh.(x).(t.name) = zeros(0, 1);
        end
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
function F = forecasts(ctx, S, getVal, src, t)
nt = ctx.nt;
lv = ctx.learnVars;
model = strcmp(src, 'model');
re = nt.types(nt.re);
F = struct();
for i = 1:numel(lv)
    x = lv{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        j = b.types(jj);
        ty = nt.types(j);
        k = ty.name;
        fv = b.fvars{jj};
        switch ty.kind
            case 're'
                if ~model && j ~= nt.re && strcmp(ty.variant, re.variant) && strcmp(ty.info, re.info)
                    fv = b.fvars{b.re_pos};      % forecasts as the RE type (history databank of history_db)
                end
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
                f = rule_value(ty, x, S, getVal, fv);
                if model
                    fm = getVal(fv, 0);
                    if ~(abs(f - fm) < 1e-9 * max(1, abs(fm)))
                        error('hetlearn:engine:timing', ['Period %s: %s from the model (%.12g) differs from the ' ...
                            'rule of type %s evaluated on the data (%.12g).'], char(dat2str(t)), fv, fm, k, f);
                    end
                    f = fm;
                end
        end
        F.(x).(k) = f;
    end
end
end


function p = type_phi(phi, ty)
% the type's beliefs by (unkeyed) target
p = struct();
for q = 1:numel(ty.sys.eq)
    tg = ty.sys.eq(q).target;
    p.(tg) = phi.([tg '__' ty.name]);
end
end


function f = rule_value(ty, x, S, getVal, fv)
R = ty.rule.(x);
v = zeros(max(1, numel(R.terms)), 1);
for j = 1:numel(R.terms)
    tm = R.terms(j);
    switch tm.kind
        case 'var'
            v(j) = getVal(tm.name, -tm.lag);
        case 'self'
            h = [];
            if isfield(S.fh, x) && isfield(S.fh.(x), ty.name)
                h = S.fh.(x).(ty.name);
            end
            if numel(h) >= tm.lag && isfinite(h(tm.lag))
                v(j) = h(tm.lag);
            else
                v(j) = getVal(fv, -tm.lag);          % before the first own forecast: the databank
                if ~isfinite(v(j))
                    v(j) = 0;
                end
            end
        case 'mean'
            p = S.phi.([x '__' ty.name]);
            v(j) = p(1);
        case 'param'
            v(j) = R.param_values.(tm.name);
    end
end
f = ty.fn.(x)(v);
end


% =========================================================================
function S = store(ctx, S, F)
nt = ctx.nt;
lv = ctx.learnVars;
for i = 1:numel(lv)
    x = lv{i};
    if ~isfield(S.fh, x)
        continue
    end
    ks = fieldnames(S.fh.(x));
    for q = 1:numel(ks)
        k = ks{q};
        j = find(strcmp(nt.names, k), 1);
        L = nt.types(j).self_maxlag;
        h = [F.(x).(k); S.fh.(x).(k)];
        S.fh.(x).(k) = h(1:min(L, numel(h)));
    end
end
S.f = F;
end


% =========================================================================
function d = seed(ctx, S, d, t0)
nt = ctx.nt;
lv = ctx.learnVars;
for i = 1:numel(lv)
    x = lv{i};
    if ~isfield(S.fh, x)
        continue
    end
    b = nt.byvar.(x);
    ks = fieldnames(S.fh.(x));
    for q = 1:numel(ks)
        k = ks{q};
        jj = find(strcmp(b.names, k), 1);
        fv = b.fvars{jj};
        h = S.fh.(x).(k);
        for lag = 1:numel(h)
            if isfinite(h(lag))
                d.(fv)(t0 - lag + 1) = h(lag);
            end
        end
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
