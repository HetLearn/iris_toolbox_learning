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
%                    hetlearn.extend_model (generator version 6; 7 with
%                    transforms, 8 with an 're_mean' type;
%                    <name>_ext_n<hash>.model). Transforms without types spell
%                    out the default pair RE ('re') and BR ('plm').
%     .engine        true when the engine takes its N-type path: N types, or the
%                    default pair RE/BR with shares.init or shares.fixed. False:
%                    the two-type code of 2026-10-20
%                    (hetlearn.switching.discrete_choice), unchanged.
%     .legacy_file   true for the default pair on the N-type engine path: the
%                    model is the two-type file (x_exp1_RE, x_exp1_BR, n1_x,
%                    n2_x, alpha_x, beta_x)
%     .types(i)      one struct per type, the RE type first, then the others in
%                    the order given:
%                      name, kind ('re' | 'plm' | 'rule' | 're_mean')
%                      variant   '' (the re_anchored switch of the generated file)
%                      variant_resolved  expectations.re_variant ('re', 're_mean')
%                      info      're', 're_mean', 'rule': resolved ('lagged' |
%                                'current': expectations.re_info, or
%                                beliefs.info for rule types); 'plm': '' (the
%                                br_info_current switch)
%                      info_resolved
%                      plm       'plm': beliefs.plm; otherwise []
%                      rule      'rule': struct('expr', ..., 'params', struct)
%                      variables {} (every type forecasts every learning variable)
%                      update    beliefs.update ('plm', 'rule', 're_mean')
%                      gain      the gain subtree ('plm', 'rule', 're_mean')
%                      inpop     true for a listed type; false for the RE type
%                                when it is not listed (always generated, share 0)
%     .names         {types.name}; .re index of the RE type (1)
%     .default_pair  true when the population is exactly RE (kind 're') and
%                    BR (kind 'plm'): shares.init = [] then means shares.init_n2
%     .gen           the generator's view (hetlearn.extend_model option 'types'):
%                    name, kind, variant, info, plm, rule, variables
%
%   Every type inherits its information set, PLM, update and gain: the
%   per-type fields, the kind 'level' and a second 're' type were removed on
%   2026-10-22 with the portfolio variants that used them (docs/BR_audit.txt).
%   Kind 're_mean' (mechanism 23): the RE type's forecast plus a learned mean
%   of its own error, with the RE type's variant and information. Only
%   switching.rule = 'discrete_choice' (error hetlearn:types:unsupported).
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
A.engine = A.ntype || ~isempty(opts.shares.init) || ~isempty(opts.shares.fixed);
A.legacy_file = ~A.ntype && A.engine;
if A.engine && ~strcmp(sw.rule, 'discrete_choice')
    error('hetlearn:types:unsupported', ['switching.rule = ''%s'': with N agent types (or shares.init / ' ...
        'shares.fixed) only ''discrete_choice'' is available (its N-type form ' ...
        'hetlearn.switching.discrete_choice_n).'], sw.rule);
end

base = struct('name', '', 'kind', '', 'variant', '', 'variant_resolved', '', 'info', '', ...
    'info_resolved', '', 'plm', [], 'rule', [], 'variables', {{}}, 'update', '', 'gain', [], 'inpop', true);
types = base([]);
if ~A.ntype
    if A.engine
        types(1) = re_type(base, 'RE', opts, true);
        types(2) = plm_type(base, 'BR', opts);
    end
else
    names = {T.name};
    iRE = find(strcmp(names, 'RE'), 1);
    types(1) = re_type(base, 'RE', opts, ~isempty(iRE));
    for i = 1:numel(T)
        if i == iRE
            continue
        end
        t = T(i);
        switch t.kind
            case 'plm'
                b = plm_type(base, t.name, opts);
            case 'rule'
                b = base;
                b.name = t.name;
                b.kind = 'rule';
                r = t.rule;
                if ~isstruct(r)
                    r = struct('expr', char(r), 'params', struct());
                elseif ~isfield(r, 'params') || isempty(r.params)
                    r.params = struct();
                end
                b.rule = struct('expr', char(r.expr), 'params', r.params);
                b.info = char(opts.beliefs.info);
                b.info_resolved = b.info;
                b.update = char(opts.beliefs.update);
                b.gain = opts.gain;
            case 're_mean'
                % the RE type's forecast plus a learned mean of its error (mechanism 23, phase P4)
                b = base;
                b.name = t.name;
                b.kind = 're_mean';
                b.variant_resolved = opts.expectations.re_variant;
                b.info = opts.expectations.re_info;
                b.info_resolved = b.info;
                b.update = char(opts.beliefs.update);
                b.gain = opts.gain;
            otherwise
                error('hetlearn:types:unsupported', 'expectations.types: kind ''%s'' (type %s) is not known.', ...
                    t.kind, t.name);
        end
        types(end+1) = b; %#ok<AGROW>
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
        'plm', b.plm, 'rule', b.rule, 'variables', {b.variables});
end
A.gen = gen;
end


% -------------------------------------------------------------------------
function T = default_pair_types()
% RE (kind 're') and BR (kind 'plm'), as hetlearn.load_options normalises a listed type (the same
% struct array as expectations.types spelled out)
T = struct('name', {'RE', 'BR'}, 'kind', {'re', 'plm'}, 'rule', {[], []});
end


function b = re_type(b, name, opts, inpop)
% the RE type: it is the RE limit of every variant, so it follows expectations.re_variant and
% .re_info, which the RE filter (hetlearn.re_filter) and the history databank
% (hetlearn.engine.history_db) read; its variant stays the re_anchored switch of the generated file
b.name = name;
b.kind = 're';
b.variant = '';
b.variant_resolved = opts.expectations.re_variant;
b.info = char(opts.expectations.re_info);
b.info_resolved = b.info;
b.inpop = inpop;
end


function b = plm_type(b, name, opts)
% a learned PLM with the global beliefs.plm, beliefs.info (the br_info_current switch), update and gain
b.name = name;
b.kind = 'plm';
b.plm = opts.beliefs.plm;
b.info = '';
b.info_resolved = opts.beliefs.info;
b.update = opts.beliefs.update;
b.gain = opts.gain;
end
