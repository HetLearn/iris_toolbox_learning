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
%   See also hetlearn.extend_model, hetlearn.re_filter, hetlearn.run,
%   hetlearn.re_anchor_coefficients.

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
