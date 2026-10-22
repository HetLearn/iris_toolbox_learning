function [m, info] = load_model(spec, opts)
%LOAD_MODEL  Generate (if needed), load, parameterise and solve the extended model.
%
%   [m, info] = hetlearn.load_model(spec, opts)
%
%   Inputs
%     spec  model spec (hetlearn.load_spec)
%     opts  options (merged or partial); always passed through
%           hetlearn.load_options, so a res.cfg saved by an older version works;
%           used: beliefs.plm, beliefs.info, expectations.variables,
%           expectations.re_variant, expectations.re_info, model_params (a
%           parameter function in spec.folder used instead of spec.params;
%           '' = spec.params; hetlearn:load_model:params if the file is missing).
%
%   Lagged RE information (expectations.re_info = 'lagged', DESIGN 19): the
%   model comes from hetlearn.extend_model(spec, plm, 're_info', 'lagged')
%   (<name>_ext_<tag>_relag.model), where the RE expectation of each learning
%   variable is E_{t-1} x_{t+1}; learning variables need a maximum lead of 1
%   (hetlearn:load_model:reInfo). For 'anchored', the model-consistent lagged
%   model at n1 = 1 (the RE(t-1) model of this learning set) is loaded and
%   solved first, the coefficients come from
%   hetlearn.re_anchor_coefficients(..., 're_info', 'lagged'), and the IRFs of
%   the two models at n1 = 1 must agree (< 1e-10, info.re_info_check).
%
%   Outputs
%     m     solved IRIS Model of <spec.folder>/generated/<name>_ext_<tag>.model
%           loaded with br_<x> = true for the learning variables and false
%           for the other forward-looking variables, re_anchored = true for
%           expectations.re_variant = 'anchored' (DESIGN 11),
%           br_info_current = true for beliefs.info = 'current' (BR
%           forecasts on period-t data, IJCB eq. 12; DESIGN 4.2), at the
%           parameters of spec.params, with every n1_<x> = 1, n2_<x> = 0,
%           every belief parameter = 0 and the anchored-RE coefficients
%           are_* from hetlearn.re_anchor_coefficients (0 for
%           'model_consistent'): the RE model (DESIGN 3.4 makes it exact).
%     info  struct
%       .meta       generator meta (hetlearn.extend_model, collapse test run)
%       .learnVars  row cellstr of learning variables ('all' resolved to
%                   meta.forward_vars, declaration order)
%       .plm        PLM spec given to the generator: a VAR over the learning
%                   set (beliefs.plm.default = 'var1' or
%                   beliefs.plm.var.variables = 'learning') is resolved to
%                   learnVars first, so that generated file depends on the
%                   learning set
%       .sys        PLM system hetlearn.plm.build_system(info.plm,
%                   learnVars, xList); checked to reproduce the BR forecast
%                   equations the generator wrote for the learning variables
%                   and to use only parameters declared in the model
%       .params     struct returned by spec.params (or by opts.model_params)
%       .toggles    struct of the br_<x> values used
%       .assign     full assign struct passed to Model.fromFile (incl.
%                   re_anchored)
%       .re_variant 'model_consistent' | 'anchored'
%       .re_info    'current' | 'lagged'; with 'lagged' also .re_info_check
%                   ([] for 'model_consistent', else .anchored_vs_mc_maxdiff)
%       .anchor     [] or the info output of hetlearn.re_anchor_coefficients
%                   (states, k, c, check_maxdiff; lagged: also cz, k_full,
%                   c_full, xb, fixed_point_rcond)
%       .has_leads  false if the loaded model has no leads (a backward
%                   model: hetlearn.engine.solve_model then falls back to
%                   the backward simulator when IRIS finds no stable
%                   solution)
%       .xList, .yList, .eList, .pList   name lists of the loaded model
%       .model_hash MD5 of the extended model file
%       .policy     [] without spec.policy, else hetlearn.policy.setup output
%                   (DESIGN 13) with, for policy.mode = 'ramsey', .multipliers
%                   (IRIS Lagrange multipliers Mu_Eq<k>), .rule_model (the
%                   solved rule model with the same toggles: RE moments for
%                   the initial beliefs, error scales, RE filter) and
%                   .rule_assign
%
%   Policy (DESIGN 13): the w_<k>, ramsey_disc_on, ramsey_disc parameters
%   are set from policy.loss and policy.discount in both models. With
%   policy.mode = 'ramsey', m is loaded with ramsey = true and
%   Model.fromFile(..., 'optimal', {'type', policy.type}); otherwise (and
%   always for the RE filter) ramsey = false, the estimated rule.
%
%   Errors: a learning variable that is not forward-looking
%   (hetlearn:load_model:notForward); a PLM system that differs from the
%   generated equations (hetlearn:load_model:plmMismatch); solve failure
%   (hetlearn:load_model:solveFailed); 'anchored' for a model without
%   plain state names or a nonlinear model (hetlearn:load_model:anchored).
%
%   N agent types (expectations.types, docs/DESIGN_br_extensions.md 1.1-1.2,
%   phase P2): hetlearn.agent_types resolves the types; the model comes from
%   hetlearn.extend_model(spec, plm, 'types', ...) (<name>_ext_n<hash>.model),
%   loaded at its RE limit (n_RE_<x> = 1, every other share 0, beliefs 0,
%   rule constants at their values, anchored coefficients as above for the RE
%   type's information set). Each learning type k (kind 'plm', and the
%   're_mean' type's mean of x_feRE) gets its PLM system
%   hetlearn.plm.build_system(..., info_k, k) on the learning variables,
%   checked against the generated equations. info.sys is then the combined
%   system of every learning type with keyed targets <target>__<k> (fields
%   .type, .var, .reg_vars added; .nt.share_names for hetlearn.engine.facility),
%   and info.nt the engine's description of the types (hetlearn.engine.ntypes).
%   The default pair RE/BR on the N-type engine path (shares.init or
%   shares.fixed without expectations.types) keeps the two-type file; info.nt
%   and the keyed info.sys are then built on it (info.nt.sys_two holds the
%   two-type system). N types with policy.mode = 'ramsey' are not supported
%   (hetlearn:load_model:types).
%
%   Forecast transforms (expectations.transforms, DESIGN_br_extensions 1.3,
%   phase P3) take the N-type path (the default pair spelled out when no types
%   are given; generator version 7). Their factors are parameters set here from
%   the options: multipliers D(h) = m^h per type, h = 2 for a type with t-1
%   information and 1 otherwise, theta, omega_f and b; recorded in
%   info.nt.model_values.transforms (res.meta.model_values). Anchored RE
%   coefficients (D11) come from the variant's own RE limit, model-consistent:
%   hetlearn.re_anchor_coefficients ('lagged') or, with period-t information,
%   the RE limit's state space over the original states; the IRFs of the
%   anchored and model-consistent RE limits must agree (1e-10). The factor
%   values enter info.params, so the RE filter's cache key separates them.
%   Errors (hetlearn:load_model:transforms): a diagnostic transform on the
%   anchored RE type of a learning variable under period-t information, and a
%   transform the generator left out of a learning variable's type
%   (meta.transforms.blocked).
%
%   Generalised anchor (DESIGN_br_extensions 1.4, phase P4): with extra anchored
%   terms (the memory states of diagnostic expectations, the anchored
%   diagnostic reference) the RE type's coefficients come from
%   hetlearn.anchor_coefficients in the anchor economy (anchor_general);
%   're_mean' types get a mean-only PLM of x_feRE. The level types, the rule
%   term re1(...), the wedge and partial-adjustment transforms, the multiplier
%   profiles other than m^h and the model values model:bma, model:sd_ygap_half,
%   model:projection and model:acd51 were removed on 2026-10-22
%   (docs/BR_audit.txt).
%
%   See also hetlearn.extend_model, hetlearn.re_filter, hetlearn.run,
%   hetlearn.re_anchor_coefficients, hetlearn.anchor_coefficients.

if nargin < 2 || isempty(opts)
    opts = struct();
end
% Always (re)merge: a partial cfg gets the defaults, and a merged tree saved
% by an older version (e.g. res.cfg of an earlier run) gets the options
% added since; an up-to-date merged tree comes back unchanged.
opts = hetlearn.load_options(opts);
% Parameter set of this run (option model_params, 2026-10-20): another parameter function of the
% same package replaces spec.params here and in everything below (generator checks, anchored
% coefficients, policy discount, info.params and so the RE filter cache key)
if ~isempty(opts.model_params)
    if exist(fullfile(spec.folder, [opts.model_params '.m']), 'file') ~= 2
        error('hetlearn:load_model:params', ['model_params = ''%s'': %s.m is not in the model package ' ...
            '%s. Set model_params = '''' to use the package''s own parameters (spec.params = ''%s'').'], ...
            opts.model_params, opts.model_params, spec.folder, spec.params);
    end
    spec.params = opts.model_params;
end
AT = hetlearn.agent_types(opts);          % N agent types (DESIGN_br_extensions 1.1); default: off
if AT.ntype
    [m, info] = load_ntype(spec, opts, AT);
    return
end

% ---- PLM spec: a VAR over the learning set needs the learning variables first ----
plm = opts.beliefs.plm;
v = opts.expectations.variables;
if uses_learning_set(plm)
    meta0 = hetlearn.extend_model(spec, 'ar1', 'validate', false);
    plm = resolve_learning_set(plm, learning_vars(v, meta0.forward_vars, spec));
end
reInfo = 'current';
if isfield(opts.expectations, 're_info')
    reInfo = char(opts.expectations.re_info);
end
lagged = strcmp(reInfo, 'lagged');       % RE expectations of the learning set dated t-1 (DESIGN 19)
if lagged
    meta = hetlearn.extend_model(spec, plm, 're_info', 'lagged');   % own file <name>_ext_<tag>_relag.model
else
    meta = hetlearn.extend_model(spec, plm);
end
learnVars = learning_vars(v, meta.forward_vars, spec);
if lagged
    long = learnVars(cellfun(@(x) meta.max_lead.(x) > 1, learnVars));
    if ~isempty(long)
        error('hetlearn:load_model:reInfo', ['expectations.re_info = ''lagged'' needs learning variables with ' ...
            'a maximum lead of 1 (the k-step expectations x_expk = x_exp(k-1){+1} would keep period-t ' ...
            'information); %s has longer leads in %s.'], strjoin(long, ', '), spec.model_file);
    end
end

anchored = strcmp(opts.expectations.re_variant, 'anchored');
if anchored && ~(isfield(meta, 'anchor_ok') && meta.anchor_ok && logical(spec.linear))
    error('hetlearn:load_model:anchored', ...
        ['expectations.re_variant = ''anchored'' needs a linear model whose IRIS state ' ...
        'names are plain (no log variables); %s does not qualify.'], spec.model_file);
end

% ---- toggles and model ---------------------------------------------------------
A = struct();
if isfield(spec, 'assign') && isstruct(spec.assign) && ~isempty(spec.assign)
    A = spec.assign;
end
tog = struct();
for i = 1:numel(meta.toggles)
    x = meta.forward_vars{i};
    tog.(meta.toggles{i}) = ismember(x, learnVars);
    A.(meta.toggles{i}) = tog.(meta.toggles{i});
end
A.(meta.anchor_toggle) = anchored;
info_ = char(opts.beliefs.info);                       % 'lagged' | 'current' (DESIGN 4.2)
if isfield(meta, 'info_toggle') && ~isempty(meta.info_toggle)
    A.(meta.info_toggle) = strcmp(info_, 'current');
elseif strcmp(info_, 'current')
    error('hetlearn:load_model:info', ...
        'beliefs.info = ''current'' needs a model generated by extend_model version 4 or later.');
end
P = call_params(spec);
pol = hetlearn.policy.setup(spec, meta, opts, P);      % [] without spec.policy (DESIGN 13)
if ~isempty(pol) && pol.wrapped
    A.(pol.toggle) = false;                             % the rule model first
end
m = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', A);

pList = cellstr(get(m, 'pList'));
eList = cellstr(get(m, 'eList'));
f = fieldnames(P);
keep = ismember(f, pList) | ismember(f, strcat('std_', eList)) | strncmp(f, 'corr_', 5);
Pm = struct();
for i = find(keep)'
    Pm.(f{i}) = P.(f{i});
end
Z = struct();
for i = 1:numel(meta.forward_vars)
    x = meta.forward_vars{i};
    Z.(['n1_' x]) = 1;
    Z.(['n2_' x]) = 0;
end
bf = fieldnames(meta.belief_params);
for i = 1:numel(bf)
    pn = meta.belief_params.(bf{i});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
af = fieldnames(meta.anchor_params);
for i = 1:numel(af)
    pn = meta.anchor_params.(af{i});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
if ~isempty(pol)
    pf = fieldnames(pol.params);
    for i = 1:numel(pf)
        Z.(pf{i}) = pol.params.(pf{i});                % loss weights, discount override
    end
end
m = assign(m, Pm);
m = assign(m, Z);
anchorInfo = [];
reCheck = [];
if anchored && ~lagged
    [Aa, anchorInfo] = hetlearn.re_anchor_coefficients(spec, P, 'vars', meta.forward_vars, ...
        'states', meta.re_states, 'ref_file', meta.ref_file);
    m = assign(m, Aa);
elseif anchored
    % Lagged RE information (DESIGN 19): the anchored agents forecast with the RE(t-1)
    % model of this learning set, i.e. the model-consistent lagged model at n1 = 1
    Amc = A;
    Amc.(meta.anchor_toggle) = false;
    mMC = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', Amc);
    mMC = assign(mMC, Pm);
    mMC = assign(mMC, Z);
    [mMC, ok, msg] = hetlearn.engine.solve_model(mMC, spec);
    if ~ok
        error('hetlearn:load_model:solveFailed', ['solve failed for %s (the RE model with information up ' ...
            'to t-1 for {%s}): %s'], meta.ext_file, strjoin(learnVars, ', '), msg);
    end
    if logical(spec.linear)
        mMC = sstate(mMC);
    end
    [Aa, anchorInfo] = hetlearn.re_anchor_coefficients(spec, P, 're_info', 'lagged', 'model', mMC, ...
        'vars', learnVars, 'states', meta.re_states, 'chain', meta.re_chain);
    m = assign(m, Aa);
end
[m, ok, msg] = hetlearn.engine.solve_model(m, spec);
if ~ok
    error('hetlearn:load_model:solveFailed', 'solve failed for %s (RE model): %s', meta.ext_file, msg);
end
if logical(spec.linear)
    m = sstate(m);
end
if anchored && lagged
    % collapse check for this learning set (DESIGN 19): at n1 = 1 the anchored model with
    % information up to t-1 is the model-consistent one (IRFs of every variable of both, 40 periods)
    common = intersect(cellstr(get(m, 'xList')), cellstr(get(mMC, 'xList')), 'stable');
    sA = srf(m, 1:40);
    sM = srf(mMC, 1:40);
    dd = 0;
    for i = 1:numel(common)
        e = abs(sA.(common{i})(1:40, :) - sM.(common{i})(1:40, :));
        e(isnan(e)) = Inf;
        dd = max([dd; e(:)]);
    end
    reCheck = struct('anchored_vs_mc_maxdiff', dd, 'variables', {common});
    if ~(dd < 1e-10)
        error('hetlearn:load_model:reInfo', ['With information up to t-1 the anchored RE model at n1 = 1 ' ...
            'differs from the model-consistent one by %.3g (IRFs, learning {%s}).'], dd, strjoin(learnVars, ', '));
    end
end
mRule = [];
if ~isempty(pol) && pol.ramsey
    % Ramsey model (DESIGN 13): same file, ramsey = true, IRIS optimal policy
    mRule = m;
    AR = A;
    AR.(pol.toggle) = true;
    m = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', AR, ...
        'optimal', {'type', pol.type});
    m = assign(m, Pm);
    m = assign(m, Z);
    if anchored
        m = assign(m, Aa);
    end
    [m, ok, msg] = hetlearn.engine.solve_model(m, spec);
    if ~ok
        error('hetlearn:load_model:solveFailed', 'solve failed for %s (Ramsey %s model): %s', ...
            meta.ext_file, pol.type, msg);
    end
    if logical(spec.linear)
        m = sstate(m);
    end
    pol.multipliers = reshape(setdiff(cellstr(get(m, 'xList')), cellstr(get(mRule, 'xList')), 'stable'), 1, []);
    pol.rule_model = mRule;
    pol.rule_assign = A;
    A = AR;
end

% ---- PLM system for the learning variables -----------------------------------------
xList = cellstr(get(m, 'xList'));
sys = hetlearn.plm.build_system(plm, learnVars, xList, info_);
for i = 1:numel(learnVars)
    x = learnVars{i};
    a = hetlearn.plm.forecast_expr(sys, x);                 % sys.info
    b = hetlearn.plm.forecast_expr(meta.sys, x, sys.info);  % the active branch of the generated file
    if ~strcmp(a, b)
        error('hetlearn:load_model:plmMismatch', ...
            ['The PLM system for the learning variables gives %s_exp1_BR = %s, ' ...
            'but the generated model has %s_exp1_BR = %s. Set beliefs.plm.by_var ' ...
            'for the auxiliary variables so that both agree.'], x, a, x, b);
    end
end
allp = {};
if ~isempty(sys.eq)
    allp = [sys.eq.param_names];
end
miss = setdiff(allp, pList);
if ~isempty(miss)
    error('hetlearn:load_model:plmMismatch', ...
        'PLM parameter(s) not declared in %s: %s.', meta.ext_file, strjoin(miss, ', '));
end

info = struct();
info.meta = meta;
info.learnVars = learnVars;
info.plm = plm;
info.sys = sys;
info.params = P;
info.toggles = tog;
info.assign = A;
info.re_variant = opts.expectations.re_variant;
info.re_info = reInfo;
if lagged
    info.re_info_check = reCheck;         % [] for 'model_consistent' (no second model)
end
info.anchor = anchorInfo;
info.has_leads = get(m, 'maxLead') > 0;
info.xList = xList;
info.yList = cellstr(get(m, 'yList'));
info.eList = eList;
info.pList = pList;
info.model_hash = hetlearn.util.md5(hetlearn.util.file_bytes(meta.ext_file));
info.policy = pol;
if AT.engine
    % the default pair RE/BR on the N-type engine path (DESIGN_br_extensions 1.2), two-type file
    if ~isempty(pol) && pol.ramsey
        error('hetlearn:load_model:types', ['shares.init and shares.fixed (the N-type engine path) are not ' ...
            'supported with policy.mode = ''ramsey'' yet.']);
    end
    info.nt = nt_descriptor(AT, meta, learnVars, xList, opts, sys);
    info.sys = nt_system(info.nt, meta, opts);
end
end


% =========================================================================
% N agent types (DESIGN_br_extensions 1.1, phase P2)
% =========================================================================
function [m, info] = load_ntype(spec, opts, AT)
v = opts.expectations.variables;
gen = AT.gen;
% a VAR over the learning set: the learning variables first (as the two-type path)
needLv = any(arrayfun(@(g) strcmp(g.kind, 'plm') && uses_learning_set(g.plm), gen));
if needLv
    meta0 = hetlearn.extend_model(spec, 'ar1', 'validate', false);
    lv0 = learning_vars(v, meta0.forward_vars, spec);
    for i = 1:numel(gen)
        if strcmp(gen(i).kind, 'plm') && uses_learning_set(gen(i).plm)
            gen(i).plm = resolve_learning_set(gen(i).plm, lv0);
            AT.types(i).plm = gen(i).plm;
        end
    end
end
X = opts.expectations.transforms;          % forecast transforms (DESIGN_br_extensions 1.3, phase P3)
if isempty(X)
    meta = hetlearn.extend_model(spec, opts.beliefs.plm, 'types', gen);
else
    meta = hetlearn.extend_model(spec, opts.beliefs.plm, 'types', gen, 'transforms', X);
end
hasTF = isfield(meta, 'transforms') && ~isempty(meta.transforms);
learnVars = learning_vars(v, meta.forward_vars, spec);
lagged = strcmp(meta.re_info, 'lagged');
if lagged
    long = learnVars(cellfun(@(x) meta.max_lead.(x) > 1, learnVars));
    if ~isempty(long)
        error('hetlearn:load_model:reInfo', ['expectations.re_info = ''lagged'' needs learning variables with ' ...
            'a maximum lead of 1 (the k-step expectations x_expk = x_exp(k-1){+1} would keep period-t ' ...
            'information); %s has longer leads in %s.'], strjoin(long, ', '), spec.model_file);
    end
end
anchTog = strcmp(opts.expectations.re_variant, 'anchored');
anchored = anchTog;                       % the RE type follows expectations.re_variant
if anchored && ~(isfield(meta, 'anchor_ok') && meta.anchor_ok && logical(spec.linear))
    error('hetlearn:load_model:anchored', ...
        ['expectations.re_variant = ''anchored'' needs a linear model whose IRIS state ' ...
        'names are plain (no log variables); %s does not qualify.'], spec.model_file);
end
if hasTF && anchTog && ~isempty(meta.transforms.deferred)
    % a diagnostic transform on an RE type that follows re_variant: with information up to t-1 the
    % anchored version has the reference x_DEg_RE{-1} (phase P4, meta.transforms.deg_vars); with
    % period-t information the anchored reference is not built
    degv = {};
    if isfield(meta.transforms, 'deg_vars')
        degv = meta.transforms.deg_vars;
    end
    dv = meta.transforms.deferred(ismember({meta.transforms.deferred.var}, learnVars) ...
        & ~ismember({meta.transforms.deferred.var}, degv));
    if ~isempty(dv)
        error('hetlearn:load_model:transforms', ['expectations.transforms(%d) (diagnostic) acts on the anchored ' ...
            'RE forecast of %s (type %s, expectations.re_variant = ''anchored'') with period-t information: its ' ...
            'anchored reference E_{t-1} x_{t+1} is built for RE information up to t-1 only (phase P4). Set ' ...
            'expectations.re_info = ''lagged'' or expectations.re_variant = ''model_consistent''.'], dv(1).i, ...
            dv(1).var, dv(1).type);
    end
end
if hasTF && ~isempty(meta.transforms.blocked)
    % a transform that phase P3 leaves out of a type's forecast, on a variable that learns in this run
    bv = meta.transforms.blocked(ismember({meta.transforms.blocked.var}, learnVars));
    if ~isempty(bv)
        error('hetlearn:load_model:transforms', ['expectations.transforms(%d) (%s) acts on the forecast of %s ' ...
            '(a learning variable) of type %s: %s.'], bv(1).i, bv(1).kind, bv(1).var, bv(1).type, bv(1).reason);
    end
end

% ---- toggles and model ---------------------------------------------------------------
A = struct();
if isfield(spec, 'assign') && isstruct(spec.assign) && ~isempty(spec.assign)
    A = spec.assign;
end
tog = struct();
for i = 1:numel(meta.toggles)
    x = meta.forward_vars{i};
    tog.(meta.toggles{i}) = ismember(x, learnVars);
    A.(meta.toggles{i}) = tog.(meta.toggles{i});
end
A.(meta.anchor_toggle) = anchTog;
info_ = char(opts.beliefs.info);
A.(meta.info_toggle) = strcmp(info_, 'current');
P = call_params(spec);
pol = hetlearn.policy.setup(spec, meta, opts, P);
if ~isempty(pol) && pol.ramsey
    error('hetlearn:load_model:types', 'N agent types (expectations.types) are not supported with policy.mode = ''ramsey'' yet.');
end
if ~isempty(pol) && pol.wrapped
    A.(pol.toggle) = false;
end
m = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', A);
pList = cellstr(get(m, 'pList'));
eList = cellstr(get(m, 'eList'));
f = fieldnames(P);
keep = ismember(f, pList) | ismember(f, strcat('std_', eList)) | strncmp(f, 'corr_', 5);
Pm = struct();
for i = find(keep)'
    Pm.(f{i}) = P.(f{i});
end
Z = re_limit(meta);
if ~isempty(pol)
    pf = fieldnames(pol.params);
    for i = 1:numel(pf)
        Z.(pf{i}) = pol.params.(pf{i});
    end
end
m = assign(m, Pm);
m = assign(m, Z);
anchorInfo = [];
reCheck = [];
mMC = [];
TFI = [];
if hasTF
    % forecast transforms: factors and the anchor economy (D11)
    [m, TFI, anchorInfo, mMC] = tf_prepare(spec, meta, opts, AT, A, Pm, Z, P, m, anchored, lagged, learnVars);
elseif anchored && ~lagged
    [Aa, anchorInfo] = hetlearn.re_anchor_coefficients(spec, P, 'vars', meta.forward_vars, ...
        'states', meta.re_states, 'ref_file', meta.ref_file);
    m = assign(m, Aa);
elseif anchored
    Amc = A;
    Amc.(meta.anchor_toggle) = false;
    mMC = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', Amc);
    mMC = assign(mMC, Pm);
    mMC = assign(mMC, Z);
    [mMC, ok, msg] = hetlearn.engine.solve_model(mMC, spec);
    if ~ok
        error('hetlearn:load_model:solveFailed', ['solve failed for %s (the RE model with information up ' ...
            'to t-1 for {%s}): %s'], meta.ext_file, strjoin(learnVars, ', '), msg);
    end
    if logical(spec.linear)
        mMC = sstate(mMC);
    end
    [Aa, anchorInfo] = hetlearn.re_anchor_coefficients(spec, P, 're_info', 'lagged', 'model', mMC, ...
        'vars', learnVars, 'states', meta.re_states, 'chain', meta.re_chain);
    m = assign(m, Aa);
end
[m, ok, msg] = hetlearn.engine.solve_model(m, spec);
if ~ok
    error('hetlearn:load_model:solveFailed', 'solve failed for %s (RE limit of the agent types): %s', meta.ext_file, msg);
end
if logical(spec.linear)
    m = sstate(m);
end
if hasTF
    % anchored = model-consistent at n_RE = 1 (D11)
    reCheck = tf_finish(m, mMC, anchored, learnVars);
end
if ~hasTF && anchored && lagged
    common = intersect(cellstr(get(m, 'xList')), cellstr(get(mMC, 'xList')), 'stable');
    sA = srf(m, 1:40);
    sM = srf(mMC, 1:40);
    dd = 0;
    for i = 1:numel(common)
        e = abs(sA.(common{i})(1:40, :) - sM.(common{i})(1:40, :));
        e(isnan(e)) = Inf;
        dd = max([dd; e(:)]);
    end
    reCheck = struct('anchored_vs_mc_maxdiff', dd, 'variables', {common});
    if ~(dd < 1e-10)
        error('hetlearn:load_model:reInfo', ['With information up to t-1 the anchored RE model at n_RE = 1 ' ...
            'differs from the model-consistent one by %.3g (IRFs, learning {%s}).'], dd, strjoin(learnVars, ', '));
    end
end

% ---- PLM systems of the learning types, checked against the generated equations -----------
xList = cellstr(get(m, 'xList'));
nt = nt_descriptor(AT, meta, learnVars, xList, opts, []);
for j = 1:numel(nt.types)
    t = nt.types(j);
    if isempty(t.sys) || ~strcmp(t.kind, 'plm')
        continue
    end
    for i = 1:numel(t.vars)
        x = t.vars{i};
        a = hetlearn.plm.forecast_expr(t.sys, x);
        b = hetlearn.plm.forecast_expr(meta.type_sys.(t.name), x, t.sys.info);
        if ~strcmp(a, b)
            error('hetlearn:load_model:plmMismatch', ['Type %s: the PLM system for the learning variables gives ' ...
                '%s_exp1_%s = %s, but the generated model has %s. Set the type''s plm by_var entries for the ' ...
                'auxiliary variables so that both agree.'], t.name, x, t.name, a, b);
        end
    end
end
sysN = nt_system(nt, meta, opts);
allp = {};
if ~isempty(sysN.eq)
    allp = [sysN.eq.param_names];
end
miss = setdiff(allp, pList);
if ~isempty(miss)
    error('hetlearn:load_model:plmMismatch', 'PLM parameter(s) not declared in %s: %s.', meta.ext_file, strjoin(miss, ', '));
end

info = struct();
info.meta = meta;
info.learnVars = learnVars;
info.plm = opts.beliefs.plm;
info.sys = sysN;
info.params = P;
info.toggles = tog;
info.assign = A;
info.re_variant = opts.expectations.re_variant;
info.re_info = meta.re_info;
if lagged
    info.re_info_check = reCheck;
end
info.anchor = anchorInfo;
info.has_leads = get(m, 'maxLead') > 0;
info.xList = xList;
info.yList = cellstr(get(m, 'yList'));
info.eList = eList;
info.pList = pList;
info.model_hash = hetlearn.util.md5(hetlearn.util.file_bytes(meta.ext_file));
info.policy = pol;
if hasTF
    % the factors are parameters, not text: in info.params they enter the RE filter's cache key
    fv = fieldnames(TFI.values);
    for i = 1:numel(fv)
        info.params.(fv{i}) = TFI.values.(fv{i});
    end
    info.transforms = TFI;
    nt.model_values.transforms = struct('values', TFI.values);
    if ~lagged && anchored
        info.re_transform_check = reCheck;   % anchored = model-consistent at n_RE = 1 (period-t information)
    end
end
info.nt = nt;
end


% =========================================================================
% Forecast transforms (DESIGN_br_extensions 1.3 and D11, phase P3)
% =========================================================================
function [m, TFI, anchorInfo, mA] = tf_prepare(spec, meta, opts, AT, A, Pm, Z, P, m, anchored, lagged, learnVars)
% Factors of the transforms (from the options: the generated file holds their structure only) and
% the anchored coefficients. The anchor economy (D11) is the variant's own RE limit: this file at
% n_RE = 1, model-consistent (re_anchored = false).
Tm = meta.transforms;
V = tf_values(Tm, opts.expectations.transforms, AT);
m = assign(m, V);
anchorInfo = [];
mA = [];
if anchored
    Amc = A;
    Amc.(meta.anchor_toggle) = false;
    mA = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', Amc);
    mA = assign(mA, Pm);
    mA = assign(mA, Z);
    mA = assign(mA, V);
    mA = tf_solve(mA, spec, meta);
    if has_extra(meta, learnVars)
        % phase P4: the anchored expression has terms on states that the transforms add (memory states
        % of diagnostic expectations, the anchored diagnostic reference): the generalised anchor
        [Aa, anchorInfo] = anchor_general(mA, meta, learnVars, lagged, A);
    elseif lagged
        try
            [Aa, anchorInfo] = hetlearn.re_anchor_coefficients(spec, P, 're_info', 'lagged', 'model', mA, ...
                'vars', learnVars, 'states', meta.re_states, 'chain', meta.re_chain);
        catch err
            if strcmp(err.identifier, 'hetlearn:anchor:lagged') && contains(err.message, 'loads on')
                error('hetlearn:load_model:transforms', ['Anchored RE agents with information up to t-1 in an ' ...
                    'economy whose forecast transforms add states: %s The generated file has no anchored term on ' ...
                    'this state (hetlearn.extend_model, anchor_extra).'], err.message);
            end
            rethrow(err);
        end
    else
        [Aa, anchorInfo] = tf_anchor_current(mA, meta, learnVars);
    end
    m = assign(m, Aa);
end
TFI = struct('values', V);
end


function m = tf_solve(m, spec, meta)
[m, ok, msg] = hetlearn.engine.solve_model(m, spec);
if ~ok
    error('hetlearn:load_model:solveFailed', ['solve failed for %s (the RE limit with the forecast transforms, ' ...
        'model-consistent): %s'], meta.ext_file, msg);
end
if logical(spec.linear)
    m = sstate(m);
end
end


function V = tf_values(Tm, X, AT)
% parameter values of the transforms
ID = 'hetlearn:load_model:transforms';
X = reshape(X, 1, []);
if numel(X) ~= Tm.n || ~isequal({X.kind}, Tm.kinds)
    error(ID, ['expectations.transforms (%d entries) does not match the generated file (%d); regenerate with ' ...
        'hetlearn.extend_model(..., ''force'', true).'], numel(X), Tm.n);
end
V = struct();
for q = 1:numel(Tm.params)
    p = Tm.params(q);
    x = X(p.i);
    switch p.role
        case 'D'
            % multiplier D(h) = m^h (DESIGN_br_extensions 1.3): h = 1 for the model-consistent E_t x_{t+1},
            % h = 2 for a type with t-1 information (E_{t-1} x_{t+1})
            h = 1;
            if ~isempty(p.type)
                j = find(strcmp(AT.names, p.type), 1);
                h = 1 + strcmp(AT.types(j).info_resolved, 'lagged');
            end
            V.(p.name) = x.value^h;
        case 'theta'
            V.(p.name) = x.value;
        case 'omega'
            V.(p.name) = x.value(1);
        case 'b'
            V.(p.name) = x.value(2);
        otherwise
            error(ID, 'Parameter %s of the generated file has the role ''%s'', which no transform kind has now.', ...
                p.name, p.role);
    end
end
end


function [A, info] = tf_anchor_current(mA, meta, learnVars)
% Anchored E_t x_{t+1} = k + c' s_t (period-t information) in the variant's RE limit mA (D11), over
% the original model's states; a loading on any other state needs the generalised anchor (P4)
xv = cellstr(get(mA, 'xVector'));
xb = reshape(cellstr(get(mA, 'xbVector')), 1, []);
states = reshape(cellstr(meta.re_states), 1, []);
[T, ~, K] = sspace(mA, 'triangular', false);
T = T(:, :, 1);
K = K(:, 1, 1);
iS = zeros(1, numel(states));
for j = 1:numel(states)
    q = find(strcmp(xb, states{j}), 1);
    if isempty(q)
        error('hetlearn:load_model:transforms', 'State %s of the original model is not a state of the RE limit with the transforms.', states{j});
    end
    iS(j) = q;
end
iO = setdiff(1:numel(xb), iS);
A = struct();
info = struct('states', {states}, 'vars', {learnVars}, 'k', struct(), 'c', struct(), 'param_names', struct(), ...
    'check_maxdiff', NaN, 're_info', 'current', 'economy', 'RE limit of the variant with its forecast transforms (D11)');
for i = 1:numel(learnVars)
    x = learnVars{i};
    pos = find(strcmp(xv, x), 1);
    c = T(pos, :);
    if ~isempty(iO)
        [big, w] = max(abs(c(iO)));
        if big >= 1e-12
            error('hetlearn:load_model:transforms', ['The anchored RE forecast of %s in the RE limit with the forecast ' ...
                'transforms loads on %s (coefficient %.3g), not a state of the original model: this needs the ' ...
                'generalised anchor of phase P4. Set expectations.re_variant = ''model_consistent'' meanwhile.'], ...
                x, xb{iO(w)}, big);
        end
    end
    pn = hetlearn.plm.anchor_names(x, states);
    A.(pn{1}) = K(pos);
    for j = 1:numel(states)
        A.(pn{1 + j}) = c(iS(j));
    end
    info.k.(x) = K(pos);
    info.c.(x) = c(iS)';
    info.param_names.(x) = pn;
end
end


function reCheck = tf_finish(m, mA, anchored, learnVars)
% With anchored RE agents, the check that the anchored RE limit m equals the model-consistent one (the
% anchor economy mA) in the IRFs to every shock (1e-10)
reCheck = [];
if anchored
    common = intersect(cellstr(get(m, 'xList')), cellstr(get(mA, 'xList')), 'stable');
    sA = srf(m, 1:40);
    sM = srf(mA, 1:40);
    dd = 0;
    for i = 1:numel(common)
        e = abs(sA.(common{i})(1:40, :) - sM.(common{i})(1:40, :));
        e(isnan(e)) = Inf;
        dd = max([dd; e(:)]);
    end
    reCheck = struct('anchored_vs_mc_maxdiff', dd, 'variables', {common});
    if ~(dd < 1e-10)
        error('hetlearn:load_model:reInfo', ['With the forecast transforms the anchored RE limit (n_RE = 1) differs ' ...
            'from the model-consistent one by %.3g (IRFs, learning {%s}).'], dd, strjoin(learnVars, ', '));
    end
end
end


function Z = re_limit(meta)
% n_RE_x = 1 and every other share 0, belief and anchored parameters 0, rule constants at their values
Z = struct();
fwd = meta.forward_vars;
for i = 1:numel(fwd)
    x = fwd{i};
    sp = meta.share_params.(x);
    for j = 1:numel(sp)
        Z.(sp{j}) = double(strcmp(meta.type_order.(x){j}, 'RE'));
    end
end
for f = reshape(fieldnames(meta.belief_params), 1, [])
    pn = meta.belief_params.(f{1});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
for f = reshape(fieldnames(meta.anchor_params), 1, [])
    pn = meta.anchor_params.(f{1});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
if isfield(meta, 'anchor_extra')          % phase P4: the anchored diagnostic reference
    for f = reshape(fieldnames(meta.anchor_extra), 1, [])
        pn = meta.anchor_extra.(f{1});
        for j = 1:numel(pn)
            Z.(pn{j}) = 0;
        end
    end
end
for f = reshape(fieldnames(meta.rule_params), 1, [])
    Z.(f{1}) = meta.rule_params.(f{1});
end
end


% =========================================================================
% Generalised anchor (DESIGN_br_extensions 1.4, phase P4)
% =========================================================================
function tf = has_extra(meta, learnVars)
% the RE type's anchored expression of a learning variable has terms beyond the original states
tf = false;
if ~isfield(meta, 'anchor_xstates') || isempty(meta.anchor_xstates)
    return
end
n0 = numel(meta.re_states);
for i = 1:numel(learnVars)
    x = learnVars{i};
    if isfield(meta.anchor_xstates, x) && numel(meta.anchor_xstates.(x)) > n0
        tf = true;
        return
    end
end
end


function ok = cond_true(c, A)
% an !if condition of the anchored text ('', 'br_z' or '~br_z') under the toggles A
if isempty(c)
    ok = true;
elseif c(1) == '~'
    ok = ~logical(A.(c(2:end)));
else
    ok = logical(A.(c));
end
end


function [tg, ch, deg] = anchor_targets(meta, learnVars, lagged, mE)
% targets of the RE type's anchored forecasts in the model-consistent anchor economy mE, and the chain
% states that stand for them: x_REt2 = E_{t-1} x_{t+1} (DESIGN 19); with the anchored diagnostic
% reference also E_{t-1} x_{t+2}, whose chain states are x_REt3 (lag 0) and x_REt3{-1} (lag 1)
xb = reshape(cellstr(get(mE, 'xbVector')), 1, []);
degv = {};
if isfield(meta, 'transforms') && ~isempty(meta.transforms) && isfield(meta.transforms, 'deg_vars')
    degv = meta.transforms.deg_vars;
end
tg = struct('var', {}, 'h', {});
ch = struct('state', {}, 'target', {}, 'lag', {});
deg = false(1, numel(learnVars));
for i = 1:numel(learnVars)
    x = learnVars{i};
    tg(end+1) = struct('var', x, 'h', 1); %#ok<AGROW>
    it = numel(tg);
    if lagged && isfield(meta, 're_chain') && isfield(meta.re_chain, x) && any(strcmp(xb, meta.re_chain.(x){2}))
        ch(end+1) = struct('state', meta.re_chain.(x){2}, 'target', it, 'lag', 0); %#ok<AGROW>
    end
    if lagged && any(strcmp(degv, x))
        tg(end+1) = struct('var', x, 'h', 2); %#ok<AGROW>
        id = numel(tg);
        deg(i) = true;
        ch(end+1) = struct('state', [x '_REt3'], 'target', id, 'lag', 0); %#ok<AGROW>
        ch(end+1) = struct('state', [x '_REt3{-1}'], 'target', id, 'lag', 1); %#ok<AGROW>
    end
end
end


function st = active_states(meta, learnVars, A)
% the original states and the extra anchored states that exist under the toggles A (the anchored
% diagnostic reference x_DEg_RE is an own lag, not a state of the anchor economy)
st = reshape(cellstr(meta.re_states), 1, []);
n0 = numel(st);
for i = 1:numel(learnVars)
    x = learnVars{i};
    if ~isfield(meta, 'anchor_xstates') || ~isfield(meta.anchor_xstates, x)
        continue
    end
    xs = meta.anchor_xstates.(x);
    cd = meta.anchor_xconds.(x);
    for j = n0 + 1:numel(xs)
        if ~strcmp(xs{j}, [x '_DEg_RE']) && cond_true(cd{j}, A) && ~any(strcmp(st, xs{j}))
            st{end+1} = xs{j}; %#ok<AGROW>
        end
    end
end
end


function [Aa, info] = anchor_general(mA, meta, learnVars, lagged, A)
% Anchored RE coefficients (D11, phase P4) over the original states and the extra terms of the
% generated text: E_{t-j} x_{t+1} (and E_{t-1} x_{t+2}, the anchored diagnostic reference) in the anchor
% economy mA, the chain states of the RE type solved out; the reference's own lag x_DEg_RE{-1} takes
% the coefficient on x_REt3{-1}. Terms whose state does not exist under the toggles are 0.
ID = 'hetlearn:load_model:transforms';
[tg, ch, deg] = anchor_targets(meta, learnVars, lagged, mA);
st = active_states(meta, learnVars, A);
[R, ic] = hetlearn.anchor_coefficients(mA, tg, st, 'lag', double(lagged), 'chain', ch, 'check', true, ...
    'error_id', ID, 'what', 'anchored RE forecast in the economy with the forecast transforms');
degRows = [];
for a = 1:numel(R.own_lags)
    for c = 1:numel(tg)
        okLag = R.own_lags(a) == 1 && tg(c).h == 2;
        if ~okLag && max(abs(R.L{a}(:, c))) >= 1e-12
            error(ID, 'The anchored RE forecast loads on its own forecast of %s{+%d} made %d periods earlier, which the generated text does not carry.', ...
                tg(c).var, tg(c).h, R.own_lags(a));
        end
    end
end
Aa = struct();
info = struct('states', {st}, 'vars', {learnVars}, 'k', struct(), 'c', struct(), 'param_names', struct(), ...
    'check_maxdiff', ic.check_maxdiff, 're_info', ternary(lagged, 'lagged', 'current'), 'cz', ic.cz, ...
    'fixed_point_rcond', ic.fixed_point_rcond, 'targets', tg, 'own_lags', R.own_lags, ...
    'economy', 'RE limit of the variant with its forecast transforms (D11), generalised anchor (phase P4)');
for i = 1:numel(learnVars)
    x = learnVars{i};
    xs = meta.anchor_xstates.(x);
    cd = meta.anchor_xconds.(x);
    it = find(strcmp({tg.var}, x) & [tg.h] == 1, 1);
    sets = {it, meta.anchor_params.(x)};
    if deg(i)
        id = find(strcmp({tg.var}, x) & [tg.h] == 2, 1);
        sets(end+1, :) = {id, meta.anchor_deg.(x)};
        degRows(end+1) = id; %#ok<AGROW>
    else
        id = [];
    end
    for r = 1:size(sets, 1)
        row = sets{r, 1};
        pn = sets{r, 2};
        Aa.(pn{1}) = R.k(row);
        for j = 1:numel(xs)
            v = 0;
            if strcmp(xs{j}, [x '_DEg_RE'])
                a = find(R.own_lags == 1, 1);
                if ~isempty(a) && ~isempty(id)
                    v = R.L{a}(row, id);
                end
            elseif cond_true(cd{j}, A)
                v = R.C(row, strcmp(st, xs{j}));
            end
            Aa.(pn{1 + j}) = v;
        end
    end
    info.k.(x) = R.k(it);
    info.c.(x) = R.C(it, :)';
    info.param_names.(x) = meta.anchor_params.(x);
end
info.deg_rows = degRows;
end


function v = ternary(c, a, b)
if c
    v = a;
else
    v = b;
end
end


function nt = nt_descriptor(AT, meta, learnVars, xList, ~, sysTwo)
% The engine's description of the agent types (hetlearn.engine.ntypes). Every type forecasts every
% learning variable.
legacy = AT.legacy_file;
nt = struct();
nt.legacy_file = legacy;
nt.names = AT.names;
nt.re = 1;
nt.default_pair = AT.default_pair;
T = struct('name', {}, 'kind', {}, 'variant', {}, 'info', {}, 'inpop', {}, 'update', {}, 'gain', {}, ...
    'vars', {}, 'sys', {}, 'rule', {}, 'data_maxlag', {}, 'zvar', {});
for j = 1:numel(AT.types)
    a = AT.types(j);
    t = struct('name', a.name, 'kind', a.kind, 'variant', a.variant_resolved, 'info', a.info_resolved, ...
        'inpop', a.inpop, 'update', a.update, 'gain', a.gain, 'vars', {learnVars}, 'sys', [], ...
        'rule', struct(), 'data_maxlag', 0, 'zvar', struct());
    switch a.kind
        case 'plm'
            if legacy
                t.sys = sysTwo;
            else
                t.sys = hetlearn.plm.build_system(a.plm, t.vars, xList, t.info, a.name);
            end
            t.data_maxlag = t.sys.maxlag;
        case 'rule'
            for i = 1:numel(t.vars)
                x = t.vars{i};
                R = meta.rules.(a.name).(x);
                t.rule.(x) = R;
                t.data_maxlag = max(t.data_maxlag, R.maxlag);
            end
        case 're_mean'
            % RE forecast plus a learned mean of its error (phase P4, mechanism 23): a mean-only PLM of the
            % generated target <x>_feRE = x - x_exp1_RE{-1}
            zv = strcat(t.vars, '_feRE');
            bv = struct();
            for i = 1:numel(zv)
                bv.(zv{i}) = struct('regressors', {{}}, 'constant', true);
                t.zvar.(t.vars{i}) = zv{i};
            end
            pl = struct('default', 'ar1', 'by_var', bv, 'derived', struct(), ...
                'var', struct('variables', {{}}, 'lags', 1, 'constant', true));
            t.sys = hetlearn.plm.build_system(pl, zv, xList, 'lagged', a.name);
    end
    T(j) = t;
end
nt.types = T;
nt.byvar = struct();
for i = 1:numel(learnVars)
    x = learnVars{i};
    ix = find(arrayfun(@(t) any(strcmp(t.vars, x)), T));
    b = struct();
    b.types = ix;
    b.names = {T(ix).name};
    if legacy
        b.fvars = {[x '_exp1_RE'], [x '_exp1_BR']};
        b.share_names = {['n1_' x], ['n2_' x]};
    else
        b.fvars = cellfun(@(k) sprintf('%s_exp1_%s', x, k), b.names, 'UniformOutput', false);
        b.share_names = meta.share_params.(x);
        if ~isequal(meta.type_order.(x), b.names)
            error('hetlearn:load_model:types', 'Type order of %s differs from the generated file.', x);
        end
    end
    b.inpop = arrayfun(@(j) T(j).inpop, ix);
    b.re_pos = find(ix == 1, 1);
    nt.byvar.(x) = b;
end
nt.model_values = struct();      % transform factors added by load_ntype (.transforms)
if legacy
    nt.sys_two = sysTwo;
end
end


function sysN = nt_system(nt, meta, opts)
% Combined PLM system of every learning type with keyed targets <target>__<type>
eq = struct('target', {}, 'isAux', {}, 'constant', {}, 'reg_names', {}, 'reg_lags', {}, ...
    'param_names', {}, 'type', {}, 'var', {}, 'reg_vars', {});
maxlag = 0;
for j = 1:numel(nt.types)
    t = nt.types(j);
    maxlag = max([maxlag, t.data_maxlag]);
    if isempty(t.sys)
        continue
    end
    for q = 1:numel(t.sys.eq)
        e = t.sys.eq(q);
        k = t.name;
        eq(end+1) = struct('target', [e.target '__' k], 'isAux', e.isAux, 'constant', e.constant, ...
            'reg_names', {cellfun(@(u) [u '__' k], e.reg_names, 'UniformOutput', false)}, ...
            'reg_lags', e.reg_lags, 'param_names', {e.param_names}, 'type', k, 'var', e.target, ...
            'reg_vars', {e.reg_names}); %#ok<AGROW>
    end
end
sysN = struct();
sysN.eq = eq;
sysN.targets = {eq.target};
sysN.learn = {};
sysN.maxlag = maxlag;
sysN.var = struct('variables', {{}}, 'lags', 1, 'constant', true);
sysN.derived = struct();
if isfield(meta, 'derived') && isstruct(meta.derived)
    sysN.derived = meta.derived;
end
sysN.info = char(opts.beliefs.info);
sysN.nt = struct('share_names', struct());
f = fieldnames(nt.byvar);
for i = 1:numel(f)
    sysN.nt.share_names.(f{i}) = nt.byvar.(f{i}).share_names;
end
end


function learnVars = learning_vars(v, fwd, spec)
% expectations.variables -> learning variables in declaration order.
if ischar(v) && strcmpi(v, 'all')
    learnVars = fwd;
    return
end
v = reshape(cellstr(v), 1, []);
bad = setdiff(v, fwd, 'stable');
if ~isempty(bad)
    error('hetlearn:load_model:notForward', ...
        ['expectations.variables: %s not forward-looking in %s ' ...
        '(forward-looking: %s).'], strjoin(bad, ', '), spec.model_file, strjoin(fwd, ', '));
end
learnVars = fwd(ismember(fwd, v));
end


function tf = uses_learning_set(plm)
tf = false;
if ~isstruct(plm)
    return
end
if isfield(plm, 'default') && ischar(plm.default) && strcmp(plm.default, 'var1')
    tf = true;
elseif isfield(plm, 'var') && isstruct(plm.var) && isfield(plm.var, 'variables') ...
        && ischar(plm.var.variables) && strcmpi(plm.var.variables, 'learning')
    tf = true;
end
end


function plm = resolve_learning_set(plm, learnVars)
% default 'var1' -> var = VAR(1) with constant over learnVars; var.variables
% = 'learning' -> learnVars. A spec setting both is left for build_system
% to reject.
if strcmp(plm.default, 'var1')
    if isfield(plm, 'var') && isstruct(plm.var) && isfield(plm.var, 'variables') ...
            && ~isempty(plm.var.variables)
        return
    end
    plm.default = 'ar1';
    plm.var = struct('variables', {learnVars}, 'lags', 1, 'constant', true);
else
    plm.var.variables = learnVars;
end
end


function P = call_params(spec)
added = false;
if ~any(strcmpi(strsplit(path, pathsep), spec.folder))
    addpath(spec.folder);
    added = true;
end
c = onCleanup(@() cleanup(added, spec.folder));
P = feval(spec.params);
if ~isstruct(P)
    error('hetlearn:load_model:params', '%s() must return a struct.', spec.params);
end
end


function cleanup(added, folder)
if added
    rmpath(folder);
end
end
