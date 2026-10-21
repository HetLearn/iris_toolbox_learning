function A = agent_types(opts)
%AGENT_TYPES  Agent types of a run: expectations.types resolved against the other options (DESIGN_br_extensions 1.1-1.2).
%
%   A = hetlearn.agent_types(opts)
%
%   Input
%     opts  merged options (hetlearn.load_options)
%
%   Output A (struct)
%     .ntype         true when expectations.types or expectations.transforms is
%                    set: the model comes from the N-type writer of
%                    hetlearn.extend_model (generator version 6, 7 with
%                    transforms; <name>_ext_n<hash>.model). Transforms without
%                    types (phase P3) spell out the default pair RE ('re') and
%                    BR ('plm'), every other field inherited.
%     .engine        true when the engine takes its N-type path: N types, or the
%                    default pair RE/BR with any of switching.inertia ~= 0,
%                    nonzero costs, switching.fitness = 'unnormalized',
%                    switching.intensity = 'model:<rule>', shares.init or
%                    shares.fixed. False: the two-type code of 2026-10-20
%                    (hetlearn.switching.discrete_choice), unchanged.
%     .legacy_file   true for the default pair on the N-type engine path: the
%                    model is the two-type file (x_exp1_RE, x_exp1_BR, n1_x,
%                    n2_x, alpha_x, beta_x)
%     .types(i)      one struct per type, the RE type first, then the others in
%                    the order given:
%                      name, kind ('re' | 'plm' | 'rule')
%                      variant   're': type.variant, '' = expectations.re_variant
%                                (the re_anchored switch of the generated file)
%                      variant_resolved
%                      info      're', 'rule': resolved ('lagged' | 'current';
%                                [] = expectations.re_info / beliefs.info);
%                                'plm': '' = beliefs.info (the br_info_current
%                                switch), or the type's own
%                      info_resolved
%                      plm       'plm': the PLM spec (shorthand -> struct with
%                                that default; partial subtree merged over
%                                beliefs.plm; [] = beliefs.plm); otherwise []
%                      rule      'rule': struct('expr', ..., 'params', struct)
%                      variables cellstr of learning variables, {} = all
%                      cost      Brock-Hommes cost (type.cost, switching.costs.<name>, 0)
%                      update    'rls' | 'fixed' (type.update or beliefs.update)
%                      gain      gain subtree (type.gain merged over gain)
%                      inpop     true for a listed type; false for the RE type
%                                when it is not listed (always generated, share 0)
%     .names         {types.name}; .re index of the RE type (1)
%     .default_pair  true when the population is exactly RE (kind 're') and
%                    BR (kind 'plm'): shares.init = [] then means shares.init_n2
%     .gen           the generator's view (hetlearn.extend_model option 'types'):
%                    name, kind, variant, info, plm, rule, variables
%
%   Restrictions of phase P2 (error hetlearn:types:unsupported): kinds 'level'
%   and 're_mean' (P4, P5); a second 're' type must be model-consistent with
%   period-t information, or forecast exactly as the RE type (same variant and
%   information); only switching.rule = 'discrete_choice'.
%
%   See also hetlearn.load_model, hetlearn.extend_model, hetlearn.engine.ntypes.

T = opts.expectations.types;
sw = opts.switching;
A = struct();
hasTF = isfield(opts.expectations, 'transforms') && ~isempty(opts.expectations.transforms);
if isempty(T) && hasTF
    % forecast transforms (DESIGN_br_extensions 1.3, phase P3) are written by the N-type writer: without
    % expectations.types the population is the default pair, spelled out (RE kind 're', BR kind 'plm')
    T = default_pair_types();
end
A.ntype = ~isempty(T);
costsOn = false;
if isstruct(sw.costs) && ~isempty(sw.costs)
    c = struct2cell(sw.costs);
    costsOn = any(cellfun(@(v) ~isempty(v) && v ~= 0, c));
end
if A.ntype
    costsOn = costsOn || any(arrayfun(@(t) ~isempty(t.cost) && t.cost ~= 0, T));
end
A.engine = A.ntype || sw.inertia ~= 0 || costsOn || strcmp(sw.fitness, 'unnormalized') ...
    || ischar(sw.intensity) || ~isempty(opts.shares.init) || ~isempty(opts.shares.fixed);
A.legacy_file = ~A.ntype && A.engine;
if A.engine && ~strcmp(sw.rule, 'discrete_choice')
    error('hetlearn:types:unsupported', ['switching.rule = ''%s'': with N agent types (or the switching ' ...
        'options of DESIGN_br_extensions 1.2) only ''discrete_choice'' is available (its N-type form ' ...
        'hetlearn.switching.discrete_choice_n).'], sw.rule);
end

base = struct('name', '', 'kind', '', 'variant', '', 'variant_resolved', '', 'info', '', ...
    'info_resolved', '', 'plm', [], 'rule', [], 'variables', {{}}, 'cost', 0, 'update', '', ...
    'gain', [], 'inpop', true);
types = base([]);
if ~A.ntype
    if A.engine
        types(1) = re_type(base, struct('name', 'RE', 'kind', 're'), opts, true);
        b = base;
        b.name = 'BR';
        b.kind = 'plm';
        b.plm = opts.beliefs.plm;
        b.info = '';
        b.info_resolved = opts.beliefs.info;
        b.update = opts.beliefs.update;
        b.gain = opts.gain;
        b.cost = cost_of(sw, 'BR', []);
        types(2) = b;
    end
else
    names = {T.name};
    iRE = find(strcmp(names, 'RE'), 1);
    if isempty(iRE)
        types(1) = re_type(base, struct('name', 'RE', 'kind', 're'), opts, false);
    else
        types(1) = re_type(base, T(iRE), opts, true);
    end
    for i = 1:numel(T)
        if i == iRE
            continue
        end
        t = T(i);
        b = base;
        b.name = t.name;
        b.kind = t.kind;
        b.variables = cellify(t.variables);
        b.cost = cost_of(sw, t.name, t.cost);
        switch t.kind
            case 're'
                b = re_type(b, t, opts, true);
            case 'plm'
                b.plm = type_plm(opts.beliefs.plm, t.plm);
                b.info = char_or_empty(t.info);
                b.info_resolved = b.info;
                if isempty(b.info_resolved)
                    b.info_resolved = opts.beliefs.info;
                end
                b.update = pick(t.update, opts.beliefs.update);
                b.gain = type_gain(opts.gain, t.gain);
            case 'rule'
                r = t.rule;
                if ~isstruct(r)
                    r = struct('expr', char(r), 'params', struct());
                elseif ~isfield(r, 'params') || isempty(r.params)
                    r.params = struct();
                end
                r.expr = char(r.expr);
                b.rule = struct('expr', r.expr, 'params', r.params);
                b.info = pick(t.info, opts.beliefs.info);
                b.info_resolved = b.info;
                b.update = pick(t.update, opts.beliefs.update);
                b.gain = type_gain(opts.gain, t.gain);
            otherwise
                error('hetlearn:types:unsupported', ['expectations.types: kind ''%s'' (type %s) is built in ' ...
                    'phase P4/P5 (docs/DESIGN_br_extensions.md sec. 6).'], t.kind, t.name);
        end
        types(end+1) = b; %#ok<AGROW>
    end
    re = types(1);
    for i = 2:numel(types)
        b = types(i);
        if ~strcmp(b.kind, 're')
            continue
        end
        same = strcmp(b.variant_resolved, re.variant_resolved) && strcmp(b.info_resolved, re.info_resolved);
        mcCur = strcmp(b.variant_resolved, 'model_consistent') && strcmp(b.info_resolved, 'current');
        if ~(same || mcCur)
            error('hetlearn:types:unsupported', ['Type %s (kind ''re'', %s, ''%s'' information): a second RE ' ...
                'type must be model-consistent with period-t information or forecast as the RE type does ' ...
                '(%s, ''%s''); other combinations need the generalised anchor of phase P4.'], b.name, ...
                b.variant_resolved, b.info_resolved, re.variant_resolved, re.info_resolved);
        end
    end
end
A.types = types;
A.names = {types.name};
A.re = 1;
pop = types([types.inpop]);
A.default_pair = numel(pop) == 2 && all(ismember({'RE', 'BR'}, {pop.name})) ...
    && strcmp(pop(strcmp({pop.name}, 'RE')).kind, 're') && strcmp(pop(strcmp({pop.name}, 'BR')).kind, 'plm');
gen = struct('name', {}, 'kind', {}, 'variant', {}, 'info', {}, 'plm', {}, 'rule', {}, 'variables', {});
for i = 1:numel(types)
    b = types(i);
    gen(i) = struct('name', b.name, 'kind', b.kind, 'variant', b.variant, 'info', b.info, ...
        'plm', b.plm, 'rule', b.rule, 'variables', {b.variables}); %#ok<AGROW>
end
A.gen = gen;
end


% -------------------------------------------------------------------------
function T = default_pair_types()
% RE (kind 're') and BR (kind 'plm') with every other field inherited, as hetlearn.load_options
% normalises a listed type (the same struct array as expectations.types spelled out)
F = {'name', 'kind', 'variant', 'info', 'plm', 'update', 'gain', 'rule', 'base', 'k', 'variables', 'cost'};
T = repmat(cell2struct(cell(numel(F), 1), F, 1), 1, 2);
T(1).name = 'RE';
T(1).kind = 're';
T(2).name = 'BR';
T(2).kind = 'plm';
end


function b = re_type(b, t, opts, inpop)
b.name = t.name;
b.kind = 're';
b.variant = '';
if isfield(t, 'variant')
    b.variant = char_or_empty(t.variant);
end
b.variant_resolved = b.variant;
if isempty(b.variant_resolved)
    b.variant_resolved = opts.expectations.re_variant;
end
info = [];
if isfield(t, 'info')
    info = t.info;
end
b.info = pick(info, opts.expectations.re_info);
b.info_resolved = b.info;
if strcmp(b.name, 'RE')
    % the RE type is the RE limit of every variant: the RE filter (hetlearn.re_filter) and the
    % history databank (hetlearn.engine.history_db) read expectations.re_variant/.re_info, so the
    % type follows them (its variant stays the re_anchored switch of the generated file)
    if ~isempty(b.variant) && ~strcmp(b.variant, opts.expectations.re_variant)
        error('hetlearn:types:unsupported', ['expectations.types: the RE type''s variant ''%s'' differs from ' ...
            'expectations.re_variant = ''%s''; set expectations.re_variant instead.'], b.variant, ...
            opts.expectations.re_variant);
    end
    if ~strcmp(b.info, opts.expectations.re_info)
        error('hetlearn:types:unsupported', ['expectations.types: the RE type''s info ''%s'' differs from ' ...
            'expectations.re_info = ''%s''; set expectations.re_info instead.'], b.info, opts.expectations.re_info);
    end
    b.variant = '';
end
if isfield(t, 'variables')
    b.variables = cellify(t.variables);
end
c = [];
if isfield(t, 'cost')
    c = t.cost;
end
b.cost = cost_of(opts.switching, b.name, c);
b.inpop = inpop;
end


function c = cost_of(sw, name, own)
c = 0;
if ~isempty(own)
    c = double(own);
elseif isstruct(sw.costs) && isfield(sw.costs, name) && ~isempty(sw.costs.(name))
    c = double(sw.costs.(name));
end
end


function v = pick(v, dflt)
if isempty(v)
    v = dflt;
end
v = char(v);
end


function v = char_or_empty(v)
if isempty(v)
    v = '';
else
    v = char(v);
end
end


function c = cellify(v)
if isempty(v)
    c = {};
else
    c = reshape(cellstr(v), 1, []);
end
end


function p = type_plm(globalPlm, own)
% a shorthand replaces the PLM; a partial subtree is merged over beliefs.plm
if isempty(own)
    p = globalPlm;
elseif ischar(own) || isstring(own)
    p = struct('default', char(own), 'by_var', struct(), 'derived', struct(), ...
        'var', struct('variables', {{}}, 'lags', 1, 'constant', true));
else
    p = merge(globalPlm, own);
end
end


function g = type_gain(globalGain, own)
g = globalGain;
if isempty(own)
    return
end
g = merge(globalGain, own);
g.rule = char(g.rule);
g.koz.structure = char(g.koz.structure);
g.koz.error = char(g.koz.error);
m = g.koz.master;
if isstring(m), m = cellstr(m); end
if ischar(m)
    if isempty(m), m = {}; else, m = {m}; end
end
g.koz.master = reshape(m, 1, []);
end


function a = merge(a, b)
% recursive merge of struct b over struct a (leaves replaced)
f = fieldnames(b);
for i = 1:numel(f)
    v = b.(f{i});
    if isfield(a, f{i}) && isstruct(v) && isscalar(v) && isstruct(a.(f{i})) && isscalar(a.(f{i}))
        a.(f{i}) = merge(a.(f{i}), v);
    else
        a.(f{i}) = v;
    end
end
end
