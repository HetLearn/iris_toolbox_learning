function meta = extend_model(spec, plm, varargin)
%EXTEND_MODEL  Write the extended (heterogeneous-expectations) model file (DESIGN 3, 11, 12).
%
%   meta = hetlearn.extend_model(spec, plm)
%   meta = hetlearn.extend_model(spec, plm, 'force', true, 'validate', false)
%
%   Inputs
%     spec   model_spec struct with fields
%              name        model name, e.g. 'sw07'
%              folder      absolute path of the model folder
%              model_file  IRIS model file, relative to folder
%              linear      true/false (passed to Model.fromFile)
%              assign      struct of the model file's own !if switches (may
%                          be empty)
%              params      name of a function in folder returning a struct
%                          of parameter values (incl. std_<shock>)
%              sstate      optional: function name/handle m = f(m)
%     plm    PLM spec (beliefs.plm subtree or a shorthand such as 'ar1');
%            see hetlearn.plm.build_system. Every forward-looking variable
%            gets a primary PLM here; a VAR over 'learning' (or default
%            'var1') therefore means all forward-looking variables in a
%            direct call (hetlearn.load_model resolves it to the scenario's
%            learning set first). plm.derived.<name> = '<expr>' adds the
%            transition variable <name> with <name> = <expr>; outside every
%            toggle (current-dated names, numbers, + - * / and parentheses;
%            a name collision is an error).
%   Options
%     'force'     regenerate even if nothing changed (default false)
%     'validate'  run the collapse test of DESIGN 3.4 (default true)
%     'types'     N agent types (hetlearn.agent_types(...).gen): the N-type
%                 writer, generator version 6 (DESIGN_br_extensions 1.1);
%                 version 8 with an 're_mean' type (phase P4: the target
%                 x_feRE = x - x_exp1_RE{-1}). With transforms the RE type's
%                 anchored expression also runs over the states they add
%                 (anchor_extra: memory states of diagnostic expectations in
%                 !if blocks, the anchored diagnostic reference x_DEg_RE{-1})
%     'transforms'  expectations.transforms as normalised by
%                 hetlearn.load_options (needs 'types'; phase P3,
%                 DESIGN_br_extensions 1.3): generator version 7. In the
%                 learning branch x_exp1 = sum_k n_k_x*T_k(x_exp1_<k>) (the
%                 type forecasts x_exp1_<k> stay untransformed), outside it
%                 x_exp1 = T(x{+1}); scope entries 'x@<label>' write a copy
%                 x_exp1__<tag> that replaces x{+1} in that equation only.
%                 Factors are parameters tf<i>_* (D__<type>, d1, theta,
%                 omega, b) that hetlearn.load_model sets. meta.transforms
%                 holds the structure, parameter roles and identity values
%                 (the collapse test runs at them); see tf_setup. Kinds
%                 'multiplier', 'diagnostic', 'myopia_anchoring' (the
%                 kinds 'partial_adjustment' and 'wedge', the level types
%                 and the rule terms self, mean, dn, re1 were removed on
%                 2026-10-22, docs/BR_audit.txt).
%
%   Files written (in <folder>/generated/)
%     <name>_ext_<plmtag>.model       the extended model
%     <name>_ext_<plmtag>_meta.mat    variable meta (below)
%     <name>_norm.model               only when the source needs notation
%                                     normalisation (x[+1], x{t+1}, x{1},
%                                     x{t-1}, ...) or preparsing: the source
%                                     with leads/lags in IRIS notation and
%                                     nothing else changed; reference model
%                                     of the collapse test.
%   plmtag is 'ar1' when every PLM equation is the default AR(1) with
%   constant on the own lag and there are no derived regressors, else 'p' +
%   the first 8 hex digits of the MD5 of the normalised PLM spec.
%
%   Output meta (struct)
%     source_file, source_hash   model file and MD5 of its bytes
%     plm          normalised PLM spec: .default, .by_var.<target>.regressors
%                  (cellstr 'u{-l}') and .constant, for every PLM equation
%                  (VAR equations included), .derived
%     plm_key      canonical text of the PLM spec (cache key)
%     plmtag, ext_file, ref_file (reference for the collapse test)
%     forward_vars cellstr of forward-looking transition variables
%     max_lead     struct by variable, maximum lead K
%     exp_vars     struct by variable: .agg {x_exp1..x_expK}, .re
%                  'x_exp1_RE', .br 'x_exp1_BR'
%     toggles      cellstr {'br_<x>', ...}, aligned with forward_vars
%     belief_params struct by PLM target: cellstr of parameter names
%     share_params struct by variable: {'n1_x', 'n2_x'}
%     sys          closed PLM system (hetlearn.plm.build_system)
%     derived      struct of derived PLM regressors (name -> expression)
%     re_states    cellstr, IRIS predetermined state vector of the ORIGINAL
%                  model (get(m,'xbVector'), loaded with spec.assign)
%     anchor_ok    false if a state name is not plain (log variables); then
%                  no anchored block is written
%     anchor_params struct by forward variable: cellstr of the anchored-RE
%                  coefficient names (hetlearn.plm.anchor_names), declared
%                  unconditionally
%     anchor_toggle 're_anchored', the global !if switch (DESIGN 11): inside
%                  each br_<x> block, true gives x_exp1_RE = are_x__const +
%                  sum_j are_x__<s_j> * s_j, false keeps x_exp1_RE = x{+1}
%     info_toggle  'br_info_current', the global !if switch of the BR
%                  information set (beliefs.info, DESIGN 4.2): inside each
%                  br_<x> block, true gives x_exp1_BR on period-t data
%                  (AR(1): alpha_x + beta_x*x), false the t-1 form
%                  (alpha_x + beta_x*(alpha_x + beta_x*x{-1}))
%     preparsed    true if the IRIS preparser expanded !for/!import/!include
%     validated, collapse_maxdiff ([br=true, br=false, br=true with
%                  re_anchored=true at hetlearn.re_anchor_coefficients], all
%                  with br_info_current=false; NaN where not run)
%     collapse_info_maxdiff  same test with br=true, br_info_current=true
%     policy       [] without spec.policy; else the parsed policy section
%                  (DESIGN 13): .ok (rule label found), .error, .toggle
%                  ('ramsey'), .instrument, .rule_label, .rule_text, .targets,
%                  .target_names, .weight_params (w_<k>), .disc_params
%                  ({'ramsey_disc_on', 'ramsey_disc'}), .discount,
%                  .discount_expanded (substitutions pasted in), .rule_vars,
%                  .rule_shocks (names used only by the rule, e.g. ms, em)
%     policy_key, policy_toggle ('' unless the rule is wrapped)
%     assign_key, generator_version, created
%
%   Parsing rules (DESIGN 3.1): leads are detected on declared transition
%   variables only, inside !transition_equations / !equations and
%   !substitutions, before '!!'. Comments (%, //, %{ %}, /* */, and the
%   rest of a line after IRIS '...') and quoted labels are never modified,
%   except that the delimiters '//', '/*', '*/', which IRIS 20230622 does
%   not accept, become '%%', '%{', '%}' (comment text unchanged).
%   Notations x{+k}, x{k}, x{t+k}, x[+k], x(+k)
%   (whitespace tolerant) are accepted; non-IRIS lag notations (x[-k],
%   x{t-k}, x(-k)) are normalised to x{-k}. Pseudo-functions with a lead
%   or a forward window (diff, dot, roc, pct, difflog, movsum, movprod,
%   movavg, movgeom) raise an error naming the equation. Files with !for,
%   !import or !include are expanded first with parser.Preparser.parse
%   (comments are dropped and the model's own !if blocks are resolved with
%   spec.assign in that case). Otherwise a file with its own !if/!switch
%   blocks keeps them, but the forward-looking variables and max leads are
%   detected on the branches spec.assign selects (IRIS preparser, review
%   m6): a variable whose leads sit only in inactive branches is not
%   forward-looking and keeps x{+k} there. Generated names that collide
%   with declared names are an error.
%
%   Policy (spec.policy, DESIGN 13): the transition equation whose label is
%   exactly spec.policy.rule_label is wrapped in the extended file as
%       !if ramsey  min((1 - ramsey_disc_on)*(<discount>) + ramsey_disc_on*ramsey_disc)
%                   sum_k w_<k>*(<target_k>)^2;  !else  <rule equation>  !end
%   and w_<k>, ramsey_disc_on, ramsey_disc are declared unconditionally (a
%   trailing policy block). The reference file never has the wrap; the
%   collapse test runs with ramsey = false. Without spec.policy the output
%   is unchanged.
%
%   See also hetlearn.plm.build_system, hetlearn.plm.forecast_expr,
%   hetlearn.re_anchor_coefficients.

GENERATOR_VERSION = 4;     % 2 (2026-10-18): anchored-RE block, derived regressors, VAR PLMs; 3: spec.policy (Ramsey wrap);
                           % 4: br_info_current toggle (beliefs.info), leads detected on the active !if branches
GENERATOR_VERSION_RELAG = 5;   % files with the lagged RE information block only (re_info = 'lagged', DESIGN 19,
                               % 2026-10-19: <name>_ext_<tag>_relag.model); the default files stay at version 4
ANCHOR_TOGGLE = 're_anchored';
INFO_TOGGLE = 'br_info_current';   % global !if switch of the BR information set (beliefs.info, DESIGN 4.2)
POLICY_TOGGLE = 'ramsey';  % global !if switch of the Ramsey wrap (DESIGN 13)

ip = inputParser;
ip.addParameter('force', false);
ip.addParameter('validate', true);
ip.addParameter('re_info', 'current');
ip.addParameter('types', []);      % N agent types (DESIGN_br_extensions 1.1): generator version 6, see ntype_generate
ip.addParameter('transforms', []); % forecast transforms (DESIGN_br_extensions 1.3, phase P3): N-type writer, version 7
ip.parse(varargin{:});
ntypes = ip.Results.types;
tforms = ip.Results.transforms;
if ~isempty(tforms) && isempty(ntypes)
    error('hetlearn:extend_model:transforms', ['Forecast transforms are written by the N-type writer: pass the agent ' ...
        'types too (option ''types'', as hetlearn.load_model does through hetlearn.agent_types).']);
end
force = logical(ip.Results.force);
doValidate = logical(ip.Results.validate);
reInfo = char(ip.Results.re_info);
if ~any(strcmp(reInfo, {'current', 'lagged'}))
    error('hetlearn:extend_model:reInfo', 're_info must be ''current'' or ''lagged'' (got ''%s'').', reInfo);
end
lagged = strcmp(reInfo, 'lagged');     % DESIGN 19: RE expectations of the learning set dated t-1
if lagged
    GENERATOR_VERSION = GENERATOR_VERSION_RELAG;
end

if nargin < 2 || isempty(plm)
    plm = 'ar1';
end
need = {'name', 'folder', 'model_file', 'linear', 'params'};
miss = need(~isfield(spec, need));
if ~isempty(miss)
    error('hetlearn:extend_model:spec', 'model spec lacks field(s): %s.', strjoin(miss, ', '));
end
assign = struct();
if isfield(spec, 'assign') && isstruct(spec.assign) && ~isempty(spec.assign)
    assign = spec.assign;
end
srcFile = fullfile(spec.folder, spec.model_file);
if exist(srcFile, 'file') ~= 2
    error('hetlearn:extend_model:noFile', 'Model file not found: %s', srcFile);
end

% ---- read source -------------------------------------------------------
fid = fopen(srcFile, 'r');
bytes = fread(fid, Inf, '*uint8')';
fclose(fid);
srcHash = md5hex(bytes);
code = native2unicode(bytes, 'UTF-8');
code = reshape(code, 1, []);
if ~isempty(code) && code(1) == char(65279)
    code(1) = [];
end
code = strrep(code, sprintf('\r\n'), newline);
code = strrep(code, sprintf('\r'), newline);

[masked, conv] = mask_code(code);
preparsed = false;
if ~isempty(regexp(masked, '(?<!!)!(for|import|include)\>', 'once'))
    code = preparse(srcFile, assign);
    [masked, conv] = mask_code(code);
    preparsed = true;
    srcHash = md5hex([bytes, unicode2native(struct_key(assign), 'UTF-8')]);
end

% ---- parse ---------------------------------------------------------------
S = parse_structure(code, masked);
occ = find_occurrences(code, masked, S);
check_pseudofunctions(code, masked, S, occ);

% Forward-looking variables and max leads come from the branches that
% spec.assign selects (the model's own !if/!switch blocks resolved by the
% IRIS preparser, review m6). The file keeps every branch; only detected
% variables are rewritten, so a lead that sits only in an inactive branch
% stays x{+k} there.
act = active_leads(code, masked, conv, occ, assign, preparsed);
fwdSet = unique({act.name});
fwd = S.tvars(ismember(S.tvars, fwdSet));      % declaration order
if isempty(fwd)
    error('hetlearn:extend_model:noLeads', ...
        'No leads of transition variables found in %s (active !if branches under spec.assign).', srcFile);
end
maxLead = struct();
for i = 1:numel(fwd)
    maxLead.(fwd{i}) = max([act(strcmp({act.name}, fwd{i})).k]);
end
if ~isempty(occ)
    notFwd = [occ.k] >= 1 & ismember([occ.sec], [2 3]) & ~ismember({occ.name}, fwd);
    for q = find(notFwd)
        occ(q).ext = occ(q).norm;      % lead of a variable that is not forward-looking under spec.assign
    end
end
occ = [occ, conv];     % comment delimiters '//', '/* */' -> '%%', '%{ %}'

derived = derived_defs(plm, S, assign);
derNames = fieldnames(derived)';
sys = hetlearn.plm.build_system(plm, fwd, [S.tvars, derNames]);
[plmN, plmKey, plmtag] = normalise_plm(plm, sys);
assignKey = struct_key(assign);
pol = policy_setup(spec, code, masked, S, POLICY_TOGGLE);     % spec.policy (DESIGN 13)
if ~isempty(ntypes)
    % N agent types (DESIGN_br_extensions 1.1): own writer and files; the two-type code below is not used
    B = struct('spec', spec, 'assign', assign, 'srcFile', srcFile, 'srcHash', srcHash, 'code', code, ...
        'preparsed', preparsed, 'S', S, 'occ', occ, 'fwd', {fwd}, 'maxLead', maxLead, 'pol', pol, ...
        'assignKey', assignKey, 'force', force, 'validate', doValidate, 'anchorToggle', ANCHOR_TOGGLE, ...
        'infoToggle', INFO_TOGGLE, 'policyToggle', POLICY_TOGGLE);
    B.transforms = tforms;
    meta = ntype_generate(B, ntypes);
    return
end

% ---- names and collisions --------------------------------------------------
gen = {};
expVars = struct();
shareParams = struct();
beliefParams = struct();
toggles = cell(1, numel(fwd));
reChain = struct();
for i = 1:numel(fwd)
    x = fwd{i};
    agg = arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:maxLead.(x), 'UniformOutput', false);
    expVars.(x) = struct('agg', {agg}, 're', [x '_exp1_RE'], 'br', [x '_exp1_BR']);
    shareParams.(x) = {['n1_' x], ['n2_' x]};
    toggles{i} = ['br_' x];
    gen = [gen, agg, {[x '_exp1_RE'], [x '_exp1_BR']}, shareParams.(x), toggles(i)]; %#ok<AGROW>
    if lagged
        % lagged RE chain (DESIGN 19): x_REt1 = E_t x_{t+1}, x_REt2 = E_t x_{t+2}, x_exp1_RE = x_REt2{-1}
        reChain.(x) = {[x '_REt1'], [x '_REt2']};
        gen = [gen, reChain.(x)]; %#ok<AGROW>
    end
end
for i = 1:numel(sys.eq)
    beliefParams.(sys.eq(i).target) = sys.eq(i).param_names;
    gen = [gen, sys.eq(i).param_names]; %#ok<AGROW>
end
gen = [gen, derNames, {ANCHOR_TOGGLE, INFO_TOGGLE}, pol.gen_names];
clash = intersect(gen, [S.declared, fieldnames(assign)']);
if ~isempty(clash)
    error('hetlearn:extend_model:nameCollision', ...
        'Generated name(s) already used in %s or spec.assign: %s.', srcFile, strjoin(clash, ', '));
end
if numel(unique(gen)) < numel(gen)
    error('hetlearn:extend_model:nameCollision', 'Generated names are not unique; rename model variables.');
end

% ---- file names and cache ------------------------------------------------------
genDir = fullfile(spec.folder, 'generated');
if exist(genDir, 'dir') ~= 7
    mkdir(genDir);
end
fileTag = plmtag;
if lagged
    fileTag = [plmtag '_relag'];      % own file and meta: the default files are never touched (DESIGN 19)
end
extFile = fullfile(genDir, sprintf('%s_ext_%s.model', spec.name, fileTag));
metaFile = fullfile(genDir, sprintf('%s_ext_%s_meta.mat', spec.name, fileTag));
normFile = fullfile(genDir, sprintf('%s_norm.model', spec.name));

if ~force && exist(metaFile, 'file') == 2 && exist(extFile, 'file') == 2
    L = load(metaFile, 'meta');
    old = L.meta;
    usedNorm = isfield(old, 'ref_file') && isfield(old, 'source_file') ...
        && ~strcmp(old.ref_file, old.source_file);
    refNow = srcFile;
    if usedNorm
        refNow = normFile;
    end
    if isfield(old, 'generator_version') && old.generator_version == GENERATOR_VERSION ...
            && strcmp(old.source_hash, srcHash) && strcmp(old.plm_key, plmKey) ...
            && isfield(old, 'assign_key') && strcmp(old.assign_key, assignKey) ...
            && isfield(old, 'policy_key') && strcmp(old.policy_key, pol.key) ...
            && ~(doValidate && isfield(old, 'anchor_error') && ~isempty(old.anchor_error)) ...
            && exist(refNow, 'file') == 2
        meta = old;
        meta.source_file = srcFile;      % paths refreshed in case the folder moved
        meta.ref_file = refNow;
        meta.ext_file = extFile;
        if doValidate && ~meta.validated
            if lagged
                [meta.collapse_maxdiff, meta.collapse_info_maxdiff, meta.collapse_lagged_sets] = ...
                    collapse_test_lagged(spec, assign, meta);
            else
                [meta.collapse_maxdiff, meta.collapse_info_maxdiff] = collapse_test(spec, assign, meta);
            end
            meta.validated = true;
            save(metaFile, 'meta');
        end
        return
    end
end

% ---- rewrite -------------------------------------------------------------------
extBody = code;
normBody = code;
spl = [occ, pol.inserts];     % pol.inserts: the Ramsey wrap of the rule (extended file only)
[~, ord] = sort([spl.s], 'descend');
for q = ord
    o = spl(q);
    extBody = [extBody(1:o.s-1), o.ext, extBody(o.e+1:end)];
    normBody = [normBody(1:o.s-1), o.norm, normBody(o.e+1:end)];
end
if preparsed || ~strcmp(normBody, code)
    write_text(normFile, normBody);
    refFile = normFile;
else
    refFile = srcFile;
end

% anchored-RE states of the ORIGINAL model (DESIGN 11)
anchor = anchor_states(refFile, spec, assign, fwd, ANCHOR_TOGGLE, doValidate);
an = struct2cell(anchor.params);
an = [an{:}];
if isempty(an)
    an = {};
end
[ua, ia] = unique(an, 'stable');
dup = unique(an(setdiff(1:numel(an), ia)));
clash = [intersect(ua, [S.declared, fieldnames(assign)', gen]), dup];
if ~isempty(clash)
    error('hetlearn:extend_model:nameCollision', ...
        'Anchored-RE parameter names collide with model names or with each other: %s.', ...
        strjoin(clash, ', '));
end

if lagged
    block = make_block_lagged(fwd, maxLead, sys, plmtag, spec, S, derived, anchor, INFO_TOGGLE, reChain);
else
    block = make_block(fwd, maxLead, sys, plmtag, spec, S, derived, anchor, INFO_TOGGLE);
end
if isempty(extBody) || extBody(end) ~= newline
    extBody = [extBody, newline];
end
extText = [extBody, block, pol.block];
write_text(extFile, extText);

meta = struct();
meta.name = spec.name;
meta.source_file = srcFile;
meta.source_hash = srcHash;
meta.plm = plmN;
meta.plm_key = plmKey;
meta.plmtag = plmtag;
meta.ext_file = extFile;
meta.ref_file = refFile;
meta.forward_vars = fwd;
meta.max_lead = maxLead;
meta.exp_vars = expVars;
meta.toggles = toggles;
meta.belief_params = beliefParams;
meta.share_params = shareParams;
meta.sys = sys;
meta.derived = derived;
meta.re_states = anchor.states;
meta.anchor_ok = anchor.ok;
meta.anchor_error = anchor.error;     % IRIS load error of the reference model ('validate', false only)
meta.anchor_params = anchor.params;
meta.anchor_toggle = ANCHOR_TOGGLE;
meta.info_toggle = INFO_TOGGLE;      % beliefs.info = 'current' sets it true (DESIGN 4.2)
meta.policy = pol.meta;              % [] without spec.policy (DESIGN 13)
meta.policy_key = pol.key;
meta.policy_toggle = '';
if pol.has && pol.meta.ok
    meta.policy_toggle = POLICY_TOGGLE;
end
meta.preparsed = preparsed;
meta.validated = false;
meta.collapse_maxdiff = [NaN, NaN, NaN];
meta.collapse_info_maxdiff = NaN;
meta.assign_key = assignKey;
meta.generator_version = GENERATOR_VERSION;
meta.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
if lagged
    % fields of the lagged RE information files only (DESIGN 19); a default meta has none of them
    meta.re_info = 'lagged';
    meta.re_chain = reChain;             % struct by forward variable: {x_REt1, x_REt2}
    meta.collapse_lagged_sets = {};
end

if exist(metaFile, 'file') == 2
    delete(metaFile);
end
if doValidate
    if lagged
        [meta.collapse_maxdiff, meta.collapse_info_maxdiff, meta.collapse_lagged_sets] = ...
            collapse_test_lagged(spec, assign, meta);
    else
        [meta.collapse_maxdiff, meta.collapse_info_maxdiff] = collapse_test(spec, assign, meta);
    end
    meta.validated = true;
end
save(metaFile, 'meta');
end


% =========================================================================
function d = derived_defs(plm, S, assign)
% Validated beliefs.plm.derived: struct name -> expression (DESIGN 12).
d = struct();
if ~isstruct(plm) || ~isfield(plm, 'derived') || isempty(plm.derived)
    return
end
if ~isstruct(plm.derived) || ~isscalar(plm.derived)
    error('hetlearn:extend_model:derived', 'beliefs.plm.derived must be a struct of strings.');
end
f = fieldnames(plm.derived);
for i = 1:numel(f)
    name = f{i};
    ex = plm.derived.(name);
    if isstring(ex) && isscalar(ex)
        ex = char(ex);
    end
    if ~ischar(ex) || isempty(strtrim(ex))
        error('hetlearn:extend_model:derived', ...
            'beliefs.plm.derived.%s must be a non-empty string (a linear expression).', name);
    end
    ex = strtrim(reshape(ex, 1, []));
    if any(strcmp(S.declared, name)) || isfield(assign, name)
        error('hetlearn:extend_model:nameCollision', ...
            'Derived regressor name ''%s'' is already used in the model.', name);
    end
    if isempty(regexp(ex, '^[\w\s\.\+\-\*/\(\)]+$', 'once')) || ~isempty(regexp(ex, '[A-Za-z_]\w*\s*\(', 'once'))
        error('hetlearn:extend_model:derived', ...
            ['beliefs.plm.derived.%s = ''%s'': use current-dated model names, numbers, ' ...
            '+ - * / and parentheses only (no time subscripts or functions).'], name, ex);
    end
    toks = regexp(ex, '(?<![\w.])[A-Za-z]\w*', 'match');
    bad = setdiff(toks, S.declared);
    if ~isempty(bad)
        error('hetlearn:extend_model:derived', 'beliefs.plm.derived.%s uses unknown name(s): %s.', ...
            name, strjoin(bad, ', '));
    end
    if ~any(ismember(toks, S.tvars))
        error('hetlearn:extend_model:derived', ...
            'beliefs.plm.derived.%s = ''%s'' references no transition variable.', name, ex);
    end
    d.(name) = ex;
end
end


% =========================================================================
function anchor = anchor_states(refFile, spec, assign, fwd, toggle, strict)
% Predetermined state vector of the original model (IRIS xbVector) and the
% anchored-RE parameter names. A non-plain state name (e.g. log(x)) turns
% the anchored block off (anchor.ok = false). If IRIS cannot load the
% reference model, the error is raised when strict (validation requested),
% else the block is left out and anchor.error keeps the message.
anchor = struct('ok', false, 'states', {{}}, 'params', struct(), 'toggle', toggle, 'error', '');
for i = 1:numel(fwd)
    anchor.params.(fwd{i}) = {};
end
try
    mo = Model.fromFile(refFile, 'linear', logical(spec.linear), 'assign', assign);
catch err
    if strict
        rethrow(err);
    end
    anchor.error = err.message;
    return
end
states = reshape(cellstr(get(mo, 'xbVector')), 1, []);
anchor.ok = true;
anchor.states = states;
try
    for i = 1:numel(fwd)
        anchor.params.(fwd{i}) = hetlearn.plm.anchor_names(fwd{i}, states);
    end
catch err
    if ~strcmp(err.identifier, 'hetlearn:anchor:state')
        rethrow(err);
    end
    anchor.ok = false;
    anchor.states = {};
    for i = 1:numel(fwd)
        anchor.params.(fwd{i}) = {};
    end
end
end


function txt = anchor_expr(pn, states)
% are_x__const + are_x__<v>*v + are_x__<v>_l<k>*v{-k} + ...
[~, sv, sl] = hetlearn.plm.anchor_names('x', states);
terms = cell(1, numel(states) + 1);
terms{1} = pn{1};
for j = 1:numel(states)
    if sl(j) == 0
        terms{j + 1} = [pn{j + 1} '*' sv{j}];
    else
        terms{j + 1} = sprintf('%s*%s{-%d}', pn{j + 1}, sv{j}, sl(j));
    end
end
txt = strjoin(terms, ' + ');
end


% =========================================================================
function [m, conv, labels] = mask_code(c)
% Blank out comments and quoted labels (newlines kept), same length as c.
% labels: one row [first, last] per quoted label (positions of the quotes).
% conv lists comment delimiters IRIS 20230622 does not accept ('//',
% '/*', '*/'), with their IRIS replacements ('%%', '%{', '%}') of the
% same length; comment text itself is never changed.
n = numel(c);
isCode = true(1, n);
conv = struct('name', {}, 'k', {}, 's', {}, 'e', {}, 'sec', {}, 'ext', {}, 'norm', {});
labels = zeros(0, 2);
i = 1;
while i <= n
    j = regexp(c(i:end), '[%/"''.]', 'once');
    if isempty(j)
        break
    end
    i = i + j - 1;
    ch = c(i);
    nx = ' ';
    if i < n
        nx = c(i + 1);
    end
    if ch == '.' && ~(i + 2 <= n && strcmp(c(i:i+2), '...'))
        i = i + 1;
        continue
    end
    if ch == '%' && nx == '{'
        stop = close_at(c, i + 2, '%}');
    elseif ch == '/' && nx == '*'
        stop = close_at(c, i + 2, '*/');
        conv(end+1) = struct('name', '', 'k', NaN, 's', i, 'e', i + 1, 'sec', 0, ...
            'ext', '%{', 'norm', '%{'); %#ok<AGROW>
        if stop - 1 > i + 1 && strcmp(c(stop-1:stop), '*/')
            conv(end+1) = struct('name', '', 'k', NaN, 's', stop - 1, 'e', stop, 'sec', 0, ...
                'ext', '%}', 'norm', '%}'); %#ok<AGROW>
        end
    elseif ch == '/' && nx == '/'
        conv(end+1) = struct('name', '', 'k', NaN, 's', i, 'e', i + 1, 'sec', 0, ...
            'ext', '%%', 'norm', '%%'); %#ok<AGROW>
        k = find(c(i:end) == newline, 1);
        if isempty(k)
            stop = n;
        else
            stop = i + k - 2;
        end
    elseif ch == '%' || ch == '.'      % line comment, or IRIS '...' continuation
        k = find(c(i:end) == newline, 1);
        if isempty(k)
            stop = n;
        else
            stop = i + k - 2;
        end
    elseif ch == '/'
        i = i + 1;
        continue
    elseif ch == '"' || ch == ''''
        k = find(c(i+1:end) == ch | c(i+1:end) == newline, 1);
        if isempty(k) || c(i + k) == newline
            i = i + 1;          % not a label: unmatched quote on this line
            continue
        end
        stop = i + k;
        labels(end+1, :) = [i, stop]; %#ok<AGROW>
    else
        i = i + 1;
        continue
    end
    isCode(i:stop) = false;
    i = stop + 1;
end
m = c;
m(~isCode & c ~= newline) = ' ';
end


function stop = close_at(c, from, tag)
k = strfind(c(from:end), tag);
if isempty(k)
    stop = numel(c);
else
    stop = from + k(1) + numel(tag) - 2;
end
end


% =========================================================================
function code = preparse(srcFile, assign)
if isempty(which('parser.Preparser'))
    error('hetlearn:extend_model:preparse', ...
        ['%s uses !for, !import or !include, which need the IRIS preparser, ' ...
        'but IRIS is not on the path. Run setup_paths first.'], srcFile);
end
old = cd(fileparts(srcFile));
cleanup = onCleanup(@() cd(old));
try
    code = parser.Preparser.parse(srcFile, [], 'Assigned', assign, ...
        'Skip', ["Substitution", "Pseudofunc", "DoubleDot"]);
catch err
    error('hetlearn:extend_model:preparse', ...
        'IRIS preparser failed on %s (needed for !for/!import/!include): %s', srcFile, err.message);
end
code = reshape(char(code), 1, []);
code = strrep(code, sprintf('\r\n'), newline);
clear cleanup
end


function act = active_leads(code, masked, conv, occ, assign, preparsed)
% Lead occurrences (k >= 1 in transition equations or substitutions) in the
% branches of the model's own !if/!switch blocks that spec.assign selects
% (review m6). A file without such blocks, or one the preparser already
% expanded (!for/!import/!include), is used as it is. Otherwise the code,
% with '//' and '/* */' delimiters converted (same length), goes through
% parser.Preparser.parse with 'Assigned', assign (IRIS treats an unassigned
% switch as false, as Model.fromFile does) and the leads are detected on
% the result. Only names and lead orders are used; positions stay those of
% the unresolved code.
act = occ([occ.k] >= 1 & ismember([occ.sec], [2 3]));
if preparsed || isempty(regexp(masked, '(?<!!)!(if|switch)\>', 'once'))
    return
end
if isempty(which('parser.Preparser'))
    error('hetlearn:extend_model:preparse', ...
        'The model file has !if/!switch blocks; resolving them with spec.assign needs IRIS. Run setup_paths first.');
end
c = code;
for q = 1:numel(conv)
    c(conv(q).s:conv(q).e) = conv(q).ext;
end
try
    r = parser.Preparser.parse([], c, 'Assigned', assign, ...
        'Skip', ["Substitution", "Pseudofunc", "DoubleDot"]);
catch err
    error('hetlearn:extend_model:preparse', ...
        'IRIS preparser failed resolving the !if/!switch blocks with spec.assign: %s', err.message);
end
r = strrep(reshape(char(r), 1, []), sprintf('\r\n'), newline);
rm = mask_code(r);
S2 = parse_structure(r, rm);
o2 = find_occurrences(r, rm, S2);
act = o2([o2.k] >= 1 & ismember([o2.sec], [2 3]));
end


% =========================================================================
function S = parse_structure(code, masked)
% Section map, dynamic-part mask and declared names.
% Section codes: 0 other, 1 transition variables, 2 transition equations,
% 3 substitutions, 4 other equations, 5 other declarations, 6 log variables.
n = numel(masked);
CONTROL = {'if', 'elseif', 'else', 'end', 'for', 'do', 'switch', 'case', ...
    'otherwise', 'import', 'include', 'export', 'list', 'all_but', 'ttrend'};
[tok, st, en] = regexp(masked, '(?<!!)!([A-Za-z_]\w*)', 'tokens', 'start', 'end');
kw = cellfun(@(t) lower(t{1}), tok, 'UniformOutput', false);
keep = ~ismember(kw, CONTROL);
kw = kw(keep);
st = st(keep);
en = en(keep);
sec = zeros(1, n);
for k = 1:numel(kw)
    a = en(k) + 1;
    if k < numel(kw)
        b = st(k + 1) - 1;
    else
        b = n;
    end
    switch kw{k}
        case {'transition_variables', 'variables'}
            c = 1;
        case {'transition_equations', 'equations'}
            c = 2;
        case 'substitutions'
            c = 3;
        case {'measurement_equations', 'dtrends', 'links', 'measurement_trends', 'reporting_equations'}
            c = 4;
        case {'measurement_variables', 'transition_shocks', 'shocks', 'measurement_shocks', ...
                'parameters', 'exogenous_variables'}
            c = 5;
        case 'log_variables'
            c = 6;
        otherwise
            c = 0;
    end
    sec(a:b) = c;
end

% dynamic part: everything in equation sections except '!!' ... ';'
dyn = true(1, n);
inEq = ismember(sec, [2 3 4]);
semi = find(masked == ';' & inEq);
bang = strfind(masked, '!!');
for q = bang
    if ~inEq(q)
        continue
    end
    stop = semi(find(semi > q, 1));
    if isempty(stop)
        stop = n;
    end
    dyn(q:stop) = false;
end

S = struct();
S.sec = sec;
S.dyn = dyn;
S.tvars = decl_names(masked, sec == 1);
S.declared = unique([S.tvars, decl_names(masked, sec == 5)]);
S.logvars = decl_names(masked, sec == 6);
S.log_all_but = ~isempty(regexp(masked(sec == 6), '!all_but', 'once'));
S.code = code;
end


function names = decl_names(masked, mask)
names = {};
d = diff([0, mask, 0]);
a = find(d == 1);
b = find(d == -1) - 1;
for r = 1:numel(a)
    t = masked(a(r):b(r));
    t = regexprep(t, '(?<!!)!(if|elseif|switch|case)\>[^\n]*', ' ');
    t = regexprep(t, '(?<!!)!(else|end|otherwise|all_but)\>', ' ');
    t = regexprep(t, '=\s*(\[[^\]]*\]|\([^)]*\)|[^\s,;]+)', ' ');
    names = [names, regexp(t, '(?<![\w.!`$?])[A-Za-z]\w*', 'match')]; %#ok<AGROW>
end
[~, iu] = unique(names, 'first');
names = names(sort(iu));
end


% =========================================================================
function occ = find_occurrences(code, masked, S) %#ok<INUSL>
% Time-subscripted references to transition variables in equation sections.
occ = struct('name', {}, 'k', {}, 's', {}, 'e', {}, 'sec', {}, 'ext', {}, 'norm', {});
if isempty(S.tvars)
    return
end
[~, ix] = sort(cellfun(@numel, S.tvars), 'descend');
nm = S.tvars(ix);
pat = ['(?<![\w.$`?])(' strjoin(nm, '|') ')\s*(\{[^{}\n;]*\}|\[[^\[\]\n;]*\]|\([^()\n;]*\))'];
[tk, s, e] = regexp(masked, pat, 'tokens', 'start', 'end');
for q = 1:numel(tk)
    c = S.sec(s(q));
    if ~ismember(c, [2 3 4]) || ~S.dyn(s(q))
        continue
    end
    name = tk{q}{1};
    sub = tk{q}{2};
    br = sub(1);
    content = regexprep(sub(2:end-1), '\s', '');
    if strcmp(content, 't')
        k = 0;
        canonical = false;
    else
        tt = regexp(content, '^(t?)([+-]?)(\d+)$', 'tokens', 'once');
        if isempty(tt) || (~isempty(tt{1}) && isempty(tt{2}))
            continue        % not a time subscript
        end
        k = str2double([tt{2}, tt{3}]);
        canonical = br == '{' && isempty(tt{1}) && ~isempty(tt{2}) && k ~= 0;
    end
    if k >= 1 && ismember(c, [2 3])
        ext = sprintf('%s_exp%d', name, k);
        nrm = sprintf('%s{+%d}', name, k);
    elseif canonical
        continue
    elseif k == 0
        ext = name;
        nrm = name;
    elseif k >= 1
        ext = sprintf('%s{+%d}', name, k);
        nrm = ext;
    else
        ext = sprintf('%s{%d}', name, k);
        nrm = ext;
    end
    occ(end+1) = struct('name', name, 'k', k, 's', s(q), 'e', e(q), 'sec', c, ...
        'ext', ext, 'norm', nrm); %#ok<AGROW>
end
end


% =========================================================================
function check_pseudofunctions(code, masked, S, occ)
[ps, pe, ptk] = regexp(masked, ...
    '(?<![\w.$])(diff|dot|roc|pct|difflog|movsum|movprod|movavg|movgeom)\s*\(', ...
    'start', 'end', 'tokens');
for q = 1:numel(ps)
    if ~ismember(S.sec(ps(q)), [2 3]) || ~S.dyn(ps(q))
        continue
    end
    open = pe(q);
    depth = 0;
    close = numel(masked);
    for i = open:numel(masked)
        if masked(i) == '('
            depth = depth + 1;
        elseif masked(i) == ')'
            depth = depth - 1;
            if depth == 0
                close = i;
                break
            end
        end
    end
    inner = masked(open+1:close-1);
    leadInside = false;
    if ~isempty(occ)
        leadInside = any([occ.k] >= 1 & [occ.s] > open & [occ.e] < close);
    end
    % top-level comma split
    depth = 0;
    cuts = [];
    for i = 1:numel(inner)
        if any(inner(i) == '([{')
            depth = depth + 1;
        elseif any(inner(i) == ')]}')
            depth = depth - 1;
        elseif inner(i) == ',' && depth == 0
            cuts(end+1) = i; %#ok<AGROW>
        end
    end
    fwdWindow = false;
    if ~isempty(cuts)
        arg2 = strtrim(inner(cuts(1)+1:end));
        v = str2double(regexprep(arg2, '\s', ''));
        fwdWindow = ~isnan(v) && v > 0;
    end
    if leadInside || fwdWindow
        error('hetlearn:extend_model:pseudoLead', ...
            ['Equation "%s" uses %s(...) with a lead or a forward window. ' ...
            'Rewrite it with explicit leads (e.g. diff(x{+1}) -> x{+1} - x) ' ...
            'so that every lead can be replaced by an expectation variable.'], ...
            eq_text(code, masked, ps(q)), ptk{q}{1});
    end
end
end


function t = eq_text(code, masked, pos)
a = find(masked(1:pos) == ';', 1, 'last');
if isempty(a)
    a = 0;
end
b = pos - 1 + find(masked(pos:end) == ';', 1);
if isempty(b)
    b = numel(code);
end
t = strtrim(regexprep(code(a+1:b), '\s+', ' '));
t = regexprep(t, '^.*!\w+\s', '');
end


% =========================================================================
function [plmN, key, tag] = normalise_plm(plm, sys)
def = 'ar1';
if ischar(plm) || isstring(plm)
    def = char(plm);
elseif isstruct(plm) && isfield(plm, 'default') && ~isempty(plm.default)
    def = char(plm.default);
end
if strcmp(def, 'var1')
    def = 'ar1';                 % the VAR equations are listed in by_var below
end
derived = struct();
if isfield(sys, 'derived')
    derived = sys.derived;
end
plmN = struct('default', def, 'by_var', struct(), 'derived', derived);
parts = cell(1, numel(sys.eq));
simple = true;
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    regs = arrayfun(@(j) sprintf('%s{-%d}', e.reg_names{j}, e.reg_lags(j)), ...
        1:numel(e.reg_names), 'UniformOutput', false);
    plmN.by_var.(e.target) = struct('regressors', {regs}, 'constant', e.constant);
    parts{i} = sprintf('%s:c%d:a%d:%s', e.target, e.constant, e.isAux, strjoin(regs, ','));
    simple = simple && ~e.isAux && isequal(e.param_names, {['alpha_' e.target], ['beta_' e.target]});
end
dn = sort(fieldnames(derived))';
dparts = cellfun(@(n) sprintf('derived:%s=%s', n, regexprep(derived.(n), '\s', '')), dn, ...
    'UniformOutput', false);
simple = simple && isempty(dn);
key = strjoin([sort(parts), dparts], ';');
if simple
    tag = 'ar1';
else
    h = md5hex(unicode2native(key, 'UTF-8'));
    tag = ['p' h(1:8)];
end
end


% =========================================================================
function txt = make_block(fwd, maxLead, sys, plmtag, spec, S, derived, anchor, infoToggle)
L = {};
L{end+1} = '';
L{end+1} = '% =====================================================================';
L{end+1} = ['% hetlearn expectation block (hetlearn.extend_model), PLM tag ' plmtag];
L{end+1} = ['% Source: ' strrep(spec.model_file, '\', '/') '. Do not edit; regenerate instead.'];
L{end+1} = '% =====================================================================';
dn = fieldnames(derived);
L{end+1} = '!transition_variables';
for i = 1:numel(dn)
    L{end+1} = sprintf('    "Derived PLM regressor, %s = %s" %s', dn{i}, derived.(dn{i}), dn{i}); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    for k = 1:maxLead.(x)
        L{end+1} = sprintf('    "Aggregate expectation of %s{+%d}" %s_exp%d', x, k, x, k); %#ok<AGROW>
    end
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    L{end+1} = sprintf('        "RE expectation of %s{+1}" %s_exp1_RE', x, x); %#ok<AGROW>
    L{end+1} = sprintf('        "BR (adaptive learning) expectation of %s{+1}" %s_exp1_BR', x, x); %#ok<AGROW>
    L{end+1} = '    !end'; %#ok<AGROW>
end
L{end+1} = '!parameters';
for i = 1:numel(fwd)
    x = fwd{i};
    L{end+1} = sprintf('    "Share of RE agents, %s" n1_%s', x, x); %#ok<AGROW>
    L{end+1} = sprintf('    "Share of BR agents, %s" n2_%s', x, x); %#ok<AGROW>
end
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    kind = 'PLM';
    if e.isAux
        kind = 'Auxiliary PLM';
    end
    p = 0;
    if e.constant
        p = 1;
        L{end+1} = sprintf('    "%s constant, %s" %s', kind, e.target, e.param_names{1}); %#ok<AGROW>
    end
    for j = 1:numel(e.reg_names)
        L{end+1} = sprintf('    "%s coefficient, %s on %s{-%d}" %s', kind, e.target, ...
            e.reg_names{j}, e.reg_lags(j), e.param_names{p + j}); %#ok<AGROW>
    end
end
if anchor.ok
    for i = 1:numel(fwd)
        x = fwd{i};
        pn = anchor.params.(x);
        L{end+1} = sprintf('    "Anchored RE forecast of %s{+1}, constant" %s', x, pn{1}); %#ok<AGROW>
        for j = 1:numel(anchor.states)
            L{end+1} = sprintf('    "Anchored RE forecast of %s{+1}, coefficient on %s" %s', ...
                x, anchor.states{j}, pn{1 + j}); %#ok<AGROW>
        end
    end
end
L{end+1} = '!transition_equations';
for i = 1:numel(dn)
    L{end+1} = sprintf('    %s = %s;', dn{i}, derived.(dn{i})); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    L{end+1} = sprintf('        %s_exp1 = n1_%s*%s_exp1_RE + n2_%s*%s_exp1_BR;', x, x, x, x, x); %#ok<AGROW>
    if anchor.ok
        L{end+1} = sprintf('        !if %s', anchor.toggle); %#ok<AGROW>
        L{end+1} = sprintf('            %s_exp1_RE = %s;', x, anchor_expr(anchor.params.(x), anchor.states)); %#ok<AGROW>
        L{end+1} = '        !else'; %#ok<AGROW>
        L{end+1} = sprintf('            %s_exp1_RE = %s{+1};', x, x); %#ok<AGROW>
        L{end+1} = '        !end'; %#ok<AGROW>
    else
        L{end+1} = sprintf('        %s_exp1_RE = %s{+1};', x, x); %#ok<AGROW>
    end
    % BR information set (beliefs.info, DESIGN 4.2): period-t data with
    % infoToggle = true (IJCB eq. 12), data up to t-1 otherwise
    L{end+1} = sprintf('        !if %s', infoToggle); %#ok<AGROW>
    L{end+1} = sprintf('            %s_exp1_BR = %s;', x, hetlearn.plm.forecast_expr(sys, x, 'current')); %#ok<AGROW>
    L{end+1} = '        !else'; %#ok<AGROW>
    L{end+1} = sprintf('            %s_exp1_BR = %s;', x, hetlearn.plm.forecast_expr(sys, x, 'lagged')); %#ok<AGROW>
    L{end+1} = '        !end'; %#ok<AGROW>
    L{end+1} = '    !else'; %#ok<AGROW>
    L{end+1} = sprintf('        %s_exp1 = %s{+1};', x, x); %#ok<AGROW>
    L{end+1} = '    !end'; %#ok<AGROW>
    for k = 2:maxLead.(x)
        L{end+1} = sprintf('    %s_exp%d = %s_exp%d{+1};', x, k, x, k - 1); %#ok<AGROW>
    end
end
% log variables: generated expectations inherit the log status of x
logged = {};
for i = 1:numel(fwd)
    x = fwd{i};
    inList = any(strcmp(S.logvars, x));
    if S.log_all_but
        if inList
            warning('hetlearn:extend_model:logAllBut', ...
                ['%s is excluded with !all_but in !log_variables; the generated ' ...
                'expectation variables of %s will be treated as log variables.'], x, x);
        end
    elseif inList
        logged = [logged, arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:maxLead.(x), ...
            'UniformOutput', false)]; %#ok<AGROW>
    end
end
if ~isempty(logged)
    L{end+1} = '!log_variables';
    L{end+1} = ['    ' strjoin(logged, ', ')];
end
txt = [strjoin(L, newline), newline];
end


% =========================================================================
function txt = make_block_lagged(fwd, maxLead, sys, plmtag, spec, S, derived, anchor, infoToggle, reChain)
% The expectation block of a lagged RE information file (re_info = 'lagged',
% DESIGN 19). Same as make_block, except the RE expectation inside each
% br_<x> block, which uses information up to t-1:
%   model-consistent (re_anchored = false): the chain
%       x_exp1_RE = x_REt2{-1};  x_REt2 = x_REt1{+1};  x_REt1 = x{+1};
%     so x_REt1_t = E_t x_{t+1}, x_REt2_t = E_t x_{t+2} and x_exp1_RE_t =
%     E_{t-1} x_{t+1} (every lead stays at +1);
%   anchored (re_anchored = true): x_exp1_RE = are_x__const + sum_j
%     are_x__<s_j>*s_j{-1}, the anchored expression with every state dated one
%     period earlier (coefficients from hetlearn.re_anchor_coefficients with
%     're_info', 'lagged').
% Variables outside the learning set (br_<x> = false) keep x_exp1 = x{+1}.
L = {};
L{end+1} = '';
L{end+1} = '% =====================================================================';
L{end+1} = ['% hetlearn expectation block (hetlearn.extend_model), PLM tag ' plmtag ...
    ', RE information up to t-1 (expectations.re_info = ''lagged'')'];
L{end+1} = ['% Source: ' strrep(spec.model_file, '\', '/') '. Do not edit; regenerate instead.'];
L{end+1} = '% =====================================================================';
dn = fieldnames(derived);
L{end+1} = '!transition_variables';
for i = 1:numel(dn)
    L{end+1} = sprintf('    "Derived PLM regressor, %s = %s" %s', dn{i}, derived.(dn{i}), dn{i}); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    ch = reChain.(x);
    for k = 1:maxLead.(x)
        L{end+1} = sprintf('    "Aggregate expectation of %s{+%d}" %s_exp%d', x, k, x, k); %#ok<AGROW>
    end
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    L{end+1} = sprintf('        "RE expectation of %s{+1}, information up to t-1" %s_exp1_RE', x, x); %#ok<AGROW>
    L{end+1} = sprintf('        "BR (adaptive learning) expectation of %s{+1}" %s_exp1_BR', x, x); %#ok<AGROW>
    if anchor.ok
        L{end+1} = sprintf('        !if ~%s', anchor.toggle); %#ok<AGROW>
    end
    L{end+1} = sprintf('        "Lagged RE chain: E_t %s{+1}" %s', x, ch{1}); %#ok<AGROW>
    L{end+1} = sprintf('        "Lagged RE chain: E_t %s{+2}" %s', x, ch{2}); %#ok<AGROW>
    if anchor.ok
        L{end+1} = '        !end'; %#ok<AGROW>
    end
    L{end+1} = '    !end'; %#ok<AGROW>
end
L{end+1} = '!parameters';
for i = 1:numel(fwd)
    x = fwd{i};
    L{end+1} = sprintf('    "Share of RE agents, %s" n1_%s', x, x); %#ok<AGROW>
    L{end+1} = sprintf('    "Share of BR agents, %s" n2_%s', x, x); %#ok<AGROW>
end
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    kind = 'PLM';
    if e.isAux
        kind = 'Auxiliary PLM';
    end
    p = 0;
    if e.constant
        p = 1;
        L{end+1} = sprintf('    "%s constant, %s" %s', kind, e.target, e.param_names{1}); %#ok<AGROW>
    end
    for j = 1:numel(e.reg_names)
        L{end+1} = sprintf('    "%s coefficient, %s on %s{-%d}" %s', kind, e.target, ...
            e.reg_names{j}, e.reg_lags(j), e.param_names{p + j}); %#ok<AGROW>
    end
end
if anchor.ok
    for i = 1:numel(fwd)
        x = fwd{i};
        pn = anchor.params.(x);
        L{end+1} = sprintf('    "Anchored RE forecast of %s{+1} with information up to t-1, constant" %s', x, pn{1}); %#ok<AGROW>
        for j = 1:numel(anchor.states)
            L{end+1} = sprintf('    "Anchored RE forecast of %s{+1} with information up to t-1, coefficient on %s dated t-1" %s', ...
                x, anchor.states{j}, pn{1 + j}); %#ok<AGROW>
        end
    end
end
L{end+1} = '!transition_equations';
for i = 1:numel(dn)
    L{end+1} = sprintf('    %s = %s;', dn{i}, derived.(dn{i})); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    ch = reChain.(x);
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    L{end+1} = sprintf('        %s_exp1 = n1_%s*%s_exp1_RE + n2_%s*%s_exp1_BR;', x, x, x, x, x); %#ok<AGROW>
    L{end+1} = '        % RE agents with information up to t-1: x_exp1_RE_t = E_{t-1} x_{t+1} (DESIGN 19)'; %#ok<AGROW>
    chain = {sprintf('%s_exp1_RE = %s{-1};', x, ch{2}), sprintf('%s = %s{+1};', ch{2}, ch{1}), ...
        sprintf('%s = %s{+1};', ch{1}, x)};
    if anchor.ok
        L{end+1} = sprintf('        !if %s', anchor.toggle); %#ok<AGROW>
        L{end+1} = sprintf('            %s_exp1_RE = %s;', x, anchor_expr_lagged(anchor.params.(x), anchor.states)); %#ok<AGROW>
        L{end+1} = '        !else'; %#ok<AGROW>
        for q = 1:numel(chain)
            L{end+1} = ['            ' chain{q}]; %#ok<AGROW>
        end
        L{end+1} = '        !end'; %#ok<AGROW>
    else
        for q = 1:numel(chain)
            L{end+1} = ['        ' chain{q}]; %#ok<AGROW>
        end
    end
    L{end+1} = sprintf('        !if %s', infoToggle); %#ok<AGROW>
    L{end+1} = sprintf('            %s_exp1_BR = %s;', x, hetlearn.plm.forecast_expr(sys, x, 'current')); %#ok<AGROW>
    L{end+1} = '        !else'; %#ok<AGROW>
    L{end+1} = sprintf('            %s_exp1_BR = %s;', x, hetlearn.plm.forecast_expr(sys, x, 'lagged')); %#ok<AGROW>
    L{end+1} = '        !end'; %#ok<AGROW>
    L{end+1} = '    !else'; %#ok<AGROW>
    L{end+1} = sprintf('        %s_exp1 = %s{+1};', x, x); %#ok<AGROW>
    L{end+1} = '    !end'; %#ok<AGROW>
    for k = 2:maxLead.(x)
        L{end+1} = sprintf('    %s_exp%d = %s_exp%d{+1};', x, k, x, k - 1); %#ok<AGROW>
    end
end
logged = {};
for i = 1:numel(fwd)
    x = fwd{i};
    inList = any(strcmp(S.logvars, x));
    if S.log_all_but
        if inList
            warning('hetlearn:extend_model:logAllBut', ...
                ['%s is excluded with !all_but in !log_variables; the generated ' ...
                'expectation variables of %s will be treated as log variables.'], x, x);
        end
    elseif inList
        logged = [logged, arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:maxLead.(x), ...
            'UniformOutput', false)]; %#ok<AGROW>
    end
end
if ~isempty(logged)
    L{end+1} = '!log_variables';
    L{end+1} = ['    ' strjoin(logged, ', ')];
end
txt = [strjoin(L, newline), newline];
end


function txt = anchor_expr_lagged(pn, states)
% are_x__const + are_x__<v>*v{-1} + are_x__<v>_l<k>*v{-k-1} + ...: the anchored
% expression with every state of the original model dated one period earlier
[~, sv, sl] = hetlearn.plm.anchor_names('x', states);
terms = cell(1, numel(states) + 1);
terms{1} = pn{1};
for j = 1:numel(states)
    terms{j + 1} = sprintf('%s*%s{-%d}', pn{j + 1}, sv{j}, sl(j) + 1);
end
txt = strjoin(terms, ' + ');
end


% =========================================================================
function [maxdiff, infoDiff, sets] = collapse_test_lagged(spec, assign, meta)
% Collapse test of a lagged RE information file (DESIGN 19; T4 of
% tests/test_re_info.m). With n1 = 1, n2 = 0 and zero beliefs:
%   (1) every br = false reproduces the reference (original) model: maxdiff(2);
%   (2) every forward-looking variable with max lead 1 learning (br = true),
%       re_anchored = false: the model-consistent lagged RE model, the RE(t-1)
%       model of that set (no external reference; it must solve);
%   (3) the same with re_anchored = true and the coefficients of
%       hetlearn.re_anchor_coefficients(..., 're_info', 'lagged') reproduces
%       (2): maxdiff(3);
%   (4) (2) with br_info_current = true reproduces (2): infoDiff.
% maxdiff(1) is NaN: with lagged RE information the extended model differs
% from the original by construction. If (2) has no unique stable solution for
% the whole set, (2)-(4) run for each variable on its own; sets lists the
% learning sets used. Every comparison: IRFs to every shock, every variable
% of the reference model, 40 periods, < 1e-10.
TOL = 1e-10;
params = call_params(spec);
mo = Model.fromFile(meta.ref_file, 'linear', logical(spec.linear), 'assign', assign);
mo = put_params(mo, params);
mo = prepare(mo, spec, 'reference model');
so = srf(mo, 1:40);
xl = get(mo, 'xList');
el = get(mo, 'eList');
anchOK = isfield(meta, 'anchor_ok') && meta.anchor_ok && logical(spec.linear);
hasInfo = isfield(meta, 'info_toggle') && ~isempty(meta.info_toggle);
maxdiff = [NaN, NaN, NaN];
infoDiff = NaN;
% (1) every br = false: the original model
[me, ~] = load_ext(spec, assign, meta, {}, false, false, params, struct());
if ~isequal(get(me, 'eList'), el)
    error('hetlearn:extend_model:collapseFailed', 'Shock lists differ between reference and extended model.');
end
[maxdiff(2), worst] = irf_diff(so, srf(me, 1:40), xl);
if ~(maxdiff(2) < TOL)
    error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (lagged RE file, br = false): ' ...
        'max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], maxdiff(2), worst, TOL, meta.ext_file);
end
lead1 = meta.forward_vars(cellfun(@(x) meta.max_lead.(x) == 1, meta.forward_vars));
sets = {};
if isempty(lead1)
    return
end
% (2)-(4) for the whole set, else one variable at a time
try
    [dA, dI] = lagged_passes(spec, assign, meta, lead1, params, xl, anchOK, hasInfo, TOL);
    sets = {lead1};
catch err
    if ~strcmp(err.identifier, 'hetlearn:extend_model:solveFailed')
        rethrow(err);
    end
    dA = NaN;
    dI = NaN;
    for i = 1:numel(lead1)
        [a, b] = lagged_passes(spec, assign, meta, lead1(i), params, xl, anchOK, hasInfo, TOL);
        dA = max([dA, a], [], 'omitnan');
        dI = max([dI, b], [], 'omitnan');
        sets{end+1} = lead1(i); %#ok<AGROW>
    end
end
maxdiff(3) = dA;
infoDiff = dI;
end


function [dA, dI] = lagged_passes(spec, assign, meta, set, params, xl, anchOK, hasInfo, TOL)
% Passes (2)-(4) of collapse_test_lagged for one learning set.
dA = NaN;
dI = NaN;
mL = load_ext(spec, assign, meta, set, false, false, params, struct());
sL = srf(mL, 1:40);
lab = strjoin(set, ',');
if anchOK
    Aa = hetlearn.re_anchor_coefficients(spec, params, 're_info', 'lagged', 'model', mL, ...
        'vars', set, 'states', meta.re_states, 'chain', meta.re_chain);
    mA = load_ext(spec, assign, meta, set, true, false, params, Aa);
    [dA, worst] = irf_diff(sL, srf(mA, 1:40), xl);
    if ~(dA < TOL)
        error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (lagged RE file, learning {%s}, ' ...
            're_anchored = 1 vs 0): max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], ...
            lab, dA, worst, TOL, meta.ext_file);
    end
end
if hasInfo
    mI = load_ext(spec, assign, meta, set, false, true, params, struct());
    [dI, worst] = irf_diff(sL, srf(mI, 1:40), xl);
    if ~(dI < TOL)
        error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (lagged RE file, learning {%s}, ' ...
            'br_info_current = 1 vs 0): max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], ...
            lab, dI, worst, TOL, meta.ext_file);
    end
end
end


function [me, a] = load_ext(spec, assign, meta, set, anch, cur, params, Aa)
% Extended model with br = true for the variables in set, n1 = 1, n2 = 0,
% zero beliefs and anchored coefficients (Aa for anch = true), solved.
a = assign;
for i = 1:numel(meta.toggles)
    a.(meta.toggles{i}) = any(strcmp(meta.forward_vars{i}, set));
end
a.(meta.anchor_toggle) = anch;
if isfield(meta, 'info_toggle') && ~isempty(meta.info_toggle)
    a.(meta.info_toggle) = cur;
end
if isfield(meta, 'policy_toggle') && ~isempty(meta.policy_toggle)
    a.(meta.policy_toggle) = false;
end
me = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', a);
me = put_params(me, params);
for i = 1:numel(meta.forward_vars)
    x = meta.forward_vars{i};
    me.(['n1_' x]) = 1;
    me.(['n2_' x]) = 0;
end
f = fieldnames(meta.belief_params);
for i = 1:numel(f)
    pn = meta.belief_params.(f{i});
    for j = 1:numel(pn)
        me.(pn{j}) = 0;
    end
end
f = fieldnames(meta.anchor_params);
for i = 1:numel(f)
    pn = meta.anchor_params.(f{i});
    for j = 1:numel(pn)
        me.(pn{j}) = 0;
    end
end
if anch
    me = put_params(me, Aa);
end
me = prepare(me, spec, sprintf('lagged RE file (learning {%s}, re_anchored = %d, br_info_current = %d)', ...
    strjoin(set, ','), anch, cur));
end


function [d, worst] = irf_diff(so, se, xl)
% Max abs IRF difference over the variables xl, periods 1..40.
d = 0;
worst = '';
for i = 1:numel(xl)
    v = xl{i};
    A = so.(v)(1:40, :);
    B = se.(v)(1:40, :);
    if ~isequal(size(A), size(B))
        error('hetlearn:extend_model:collapseFailed', 'IRF sizes differ for %s.', v);
    end
    dd = abs(A(:) - B(:));
    dd(isnan(dd)) = Inf;
    if ~isempty(dd) && max(dd) > d
        d = max(dd);
        worst = v;
    end
end
end


% =========================================================================
function [maxdiff, infoDiff] = collapse_test(spec, assign, meta)
% Extended model with n1=1, n2=0, beliefs 0 must reproduce the reference
% model's IRFs (40 periods, all shocks): (1) every br=true, (2) every
% br=false, (3) every br=true with re_anchored=true and the anchored
% coefficients of hetlearn.re_anchor_coefficients (DESIGN 3.4, 11); runs
% 1-3 with br_info_current = false. infoDiff: (4) every br=true with
% br_info_current = true (the period-t BR equations parse and solve).
TOL = 1e-10;
params = call_params(spec);
mo = Model.fromFile(meta.ref_file, 'linear', logical(spec.linear), 'assign', assign);
mo = put_params(mo, params);
mo = prepare(mo, spec, 'reference model');
so = srf(mo, 1:40);
xl = get(mo, 'xList');
el = get(mo, 'eList');
anchOK = isfield(meta, 'anchor_ok') && meta.anchor_ok && logical(spec.linear);
Aa = struct();
if anchOK
    Aa = hetlearn.re_anchor_coefficients(spec, params, 'vars', meta.forward_vars, ...
        'states', meta.re_states, 'model', mo);
end
maxdiff = [NaN, NaN, NaN];
infoDiff = NaN;
hasInfo = isfield(meta, 'info_toggle') && ~isempty(meta.info_toggle);
tog = [true, false, true, true];
anch = [false, false, true, false];
cur = [false, false, false, true];
for it = 1:4
    if (anch(it) && ~anchOK) || (cur(it) && ~hasInfo)
        continue
    end
    a = assign;
    for i = 1:numel(meta.toggles)
        a.(meta.toggles{i}) = tog(it);
    end
    a.(meta.anchor_toggle) = anch(it);
    if hasInfo
        a.(meta.info_toggle) = cur(it);
    end
    if isfield(meta, 'policy_toggle') && ~isempty(meta.policy_toggle)
        a.(meta.policy_toggle) = false;          % the rule model (DESIGN 13)
    end
    me = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', a);
    me = put_params(me, params);
    for i = 1:numel(meta.forward_vars)
        x = meta.forward_vars{i};
        me.(['n1_' x]) = 1;
        me.(['n2_' x]) = 0;
    end
    f = fieldnames(meta.belief_params);
    for i = 1:numel(f)
        pn = meta.belief_params.(f{i});
        for j = 1:numel(pn)
            me.(pn{j}) = 0;
        end
    end
    f = fieldnames(meta.anchor_params);
    for i = 1:numel(f)
        pn = meta.anchor_params.(f{i});
        for j = 1:numel(pn)
            me.(pn{j}) = 0;
        end
    end
    if anch(it)
        me = put_params(me, Aa);
    end
    me = prepare(me, spec, sprintf('extended model (br = %d, re_anchored = %d, br_info_current = %d)', ...
        tog(it), anch(it), cur(it)));
    if ~isequal(get(me, 'eList'), el)
        error('hetlearn:extend_model:collapseFailed', 'Shock lists differ between reference and extended model.');
    end
    se = srf(me, 1:40);
    d = 0;
    worst = '';
    for i = 1:numel(xl)
        v = xl{i};
        A = so.(v)(1:40, :);      % periods 1..40 (presample rows depend on max lag)
        B = se.(v)(1:40, :);
        if ~isequal(size(A), size(B))
            error('hetlearn:extend_model:collapseFailed', 'IRF sizes differ for %s.', v);
        end
        dd = abs(A(:) - B(:));
        dd(isnan(dd)) = Inf;
        if ~isempty(dd) && max(dd) > d
            d = max(dd);
            worst = v;
        end
    end
    if it <= 3
        maxdiff(it) = d;
    else
        infoDiff = d;
    end
    if d >= TOL
        error('hetlearn:extend_model:collapseFailed', ...
            ['Collapse test failed (br = %d, re_anchored = %d, br_info_current = %d): max abs IRF ' ...
            'difference %.3g (variable %s) >= %g. Extended file: %s'], tog(it), anch(it), cur(it), ...
            d, worst, TOL, meta.ext_file);
    end
end
end


function P = call_params(spec)
added = false;
if ~any(strcmpi(strsplit(path, pathsep), spec.folder))
    addpath(spec.folder);
    added = true;
end
try
    P = feval(spec.params);
catch err
    if added
        rmpath(spec.folder);
    end
    rethrow(err);
end
if added
    rmpath(spec.folder);
end
end


function m = put_params(m, P)
names = fieldnames(get(m, 'parameters'));
f = fieldnames(P);
for i = 1:numel(f)
    if any(strcmp(names, f{i}))
        m.(f{i}) = P.(f{i});
    end
end
end


function m = prepare(m, spec, what)
if isfield(spec, 'sstate') && ~isempty(spec.sstate)
    if ischar(spec.sstate) || isstring(spec.sstate)
        m = feval(char(spec.sstate), m);
    else
        m = spec.sstate(m);
    end
elseif ~logical(spec.linear)
    m = sstate(m);
end
[m, flag] = solve(m);
if ~hasSucceeded(flag)
    try
        msg = char(string(flag));
    catch
        msg = class(flag);
    end
    error('hetlearn:extend_model:solveFailed', 'solve failed for the %s: %s', what, msg);
end
end


% =========================================================================
function write_text(file, txt)
fid = fopen(file, 'w', 'n', 'UTF-8');
if fid < 0
    error('hetlearn:extend_model:write', 'Cannot write %s', file);
end
fprintf(fid, '%s', txt);
fclose(fid);
end


function h = md5hex(bytes)
md = java.security.MessageDigest.getInstance('MD5');
md.update(typecast(uint8(bytes(:)), 'int8'));
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2)', 1, []));
end


function s = struct_key(a)
f = sort(fieldnames(a));
s = '';
for i = 1:numel(f)
    v = a.(f{i});
    if isnumeric(v) || islogical(v)
        v = mat2str(double(v));
    elseif ischar(v) || isstring(v)
        v = char(v);
    else
        v = class(v);
    end
    s = [s, f{i}, '=', v, ';']; %#ok<AGROW>
end
end


% =========================================================================
% Policy section (spec.policy, DESIGN 13)
% =========================================================================
function pol = policy_setup(spec, code, masked, S, toggle)
% Parse spec.policy: find the rule equation by its exact label, build the
% splices that wrap it as  !if <toggle> <loss>; !else <rule> !end  (applied
% to the extended file only, never to the reference file), the parameter
% block (w_<k>, ramsey_disc_on, ramsey_disc; declared unconditionally),
% the rule-only names and the discount with substitutions expanded. A
% missing label is not an error here (meta.policy.ok = false, .error);
% hetlearn.policy.setup raises it when policy.mode = 'ramsey'.
tmpl = struct('name', {}, 'k', {}, 's', {}, 'e', {}, 'sec', {}, 'ext', {}, 'norm', {});
pol = struct('has', false, 'key', '', 'gen_names', {{}}, 'inserts', tmpl, 'block', '', 'meta', []);
if ~isfield(spec, 'policy') || isempty(spec.policy)
    return
end
p = spec.policy;
need = {'instrument', 'rule_label', 'targets', 'discount'};
miss = need(~isfield(p, need));
if ~isempty(miss)
    error('hetlearn:extend_model:policy', 'spec.policy lacks field(s): %s.', strjoin(miss, ', '));
end
instrument = char(p.instrument);
if ~any(strcmp(S.tvars, instrument))
    error('hetlearn:extend_model:policy', 'spec.policy.instrument %s is not a transition variable of %s.', ...
        instrument, spec.model_file);
end
label = char(p.rule_label);
if ~isstruct(p.targets) || ~isscalar(p.targets) || isempty(fieldnames(p.targets))
    error('hetlearn:extend_model:policy', 'spec.policy.targets must be a struct of expressions.');
end
tn = reshape(fieldnames(p.targets), 1, []);
texpr = struct();
for i = 1:numel(tn)
    ex = p.targets.(tn{i});
    if ~(ischar(ex) || (isstring(ex) && isscalar(ex)))
        error('hetlearn:extend_model:policy', 'spec.policy.targets.%s must be a string.', tn{i});
    end
    texpr.(tn{i}) = strtrim(char(ex));
    check_target(texpr.(tn{i}), tn{i}, S);
end
disc = p.discount;
if isnumeric(disc) && isscalar(disc)
    disc = sprintf('%.17g', disc);
elseif ischar(disc) || (isstring(disc) && isscalar(disc))
    disc = strtrim(char(disc));
else
    disc = '';
end
if isempty(disc)
    error('hetlearn:extend_model:policy', 'spec.policy.discount must be a number or an expression.');
end
wp = struct();
for i = 1:numel(tn)
    wp.(tn{i}) = ['w_' tn{i}];
end
discParams = {'ramsey_disc_on', 'ramsey_disc'};
w = struct2cell(wp)';
pol.has = true;
pol.gen_names = [w, discParams, {toggle}];
pol.key = sprintf('instrument=%s|label=%s|discount=%s|%s', instrument, label, disc, ...
    strjoin(cellfun(@(n) [n '=' texpr.(n)], tn, 'UniformOutput', false), '|'));

[ls, semi, err] = find_rule(code, masked, S, label, spec.model_file);
ok = isempty(err);
ruleVars = {};
ruleShocks = {};
ruleText = '';
if ok
    ruleText = code(ls:semi);
    nl = find(code(1:ls-1) == newline, 1, 'last');
    if isempty(nl)
        nl = 0;
    end
    lead = code(nl+1:ls-1);
    if all(isspace(lead))
        pre = '';
        ind = lead;
    else
        ind = '    ';
        pre = [newline, ind];
    end
    terms = cellfun(@(n) sprintf('%s*(%s)^2', wp.(n), texpr.(n)), tn, 'UniformOutput', false);
    lossTxt = sprintf('min((1 - %s)*(%s) + %s*%s) %s;', discParams{1}, disc, discParams{1}, ...
        discParams{2}, strjoin(terms, ' + '));
    prefix = [pre, '!if ', toggle, newline, ...
        ind, '% hetlearn Ramsey loss (DESIGN 13): with ', toggle, ' = true it replaces the policy rule below', newline, ...
        ind, lossTxt, newline, ind, '!else', newline, ind];
    pol.inserts(1) = struct('name', '', 'k', NaN, 's', ls, 'e', ls, 'sec', 2, ...
        'ext', [prefix, code(ls)], 'norm', code(ls));
    pol.inserts(2) = struct('name', '', 'k', NaN, 's', semi, 'e', semi, 'sec', 2, ...
        'ext', [';', newline, ind, '!end'], 'norm', ';');
    shocks = decl_names(masked, section_mask(masked, {'transition_shocks', 'shocks'}));
    [ruleVars, ruleShocks] = rule_only_names(masked, S, semi, shocks);
end
[discX, derr] = expand_subs(disc, masked, S);
if ~isempty(derr)
    error('hetlearn:extend_model:policy', 'spec.policy.discount: %s', derr);
end

B = {};
B{end+1} = '';
B{end+1} = '% =====================================================================';
B{end+1} = '% hetlearn policy block (DESIGN 13): Ramsey loss weights and discount';
B{end+1} = ['% override; declared unconditionally, used only when ' toggle ' = true'];
B{end+1} = '% =====================================================================';
B{end+1} = '!parameters';
for i = 1:numel(tn)
    B{end+1} = sprintf('    "Ramsey loss weight on %s = %s" %s', tn{i}, texpr.(tn{i}), wp.(tn{i})); %#ok<AGROW>
end
B{end+1} = sprintf('    "Ramsey discount: 0 = spec.policy.discount, 1 = %s" %s', discParams{2}, discParams{1});
B{end+1} = sprintf('    "Ramsey discount override (policy.discount)" %s', discParams{2});
pol.block = [strjoin(B, newline), newline];

pm = struct();
pm.has = true;
pm.ok = ok;
pm.error = err;
pm.toggle = toggle;
pm.instrument = instrument;
pm.rule_label = label;
pm.rule_text = ruleText;
pm.targets = texpr;
pm.target_names = tn;
pm.weight_params = wp;
pm.disc_params = discParams;
pm.discount = disc;
pm.discount_expanded = discX;
pm.rule_vars = ruleVars;
pm.rule_shocks = ruleShocks;
pol.meta = pm;
end


function check_target(ex, name, S)
if ~isvarname(name)
    error('hetlearn:extend_model:policy', 'spec.policy.targets: %s is not a valid name.', name);
end
if isempty(regexp(ex, '^[\w\s\.\+\-\*/\^\(\)\{\}]+$', 'once'))
    error('hetlearn:extend_model:policy', ...
        'spec.policy.targets.%s = "%s": use names, numbers, + - * / ^, parentheses and lags x{-k} only.', name, ex);
end
subs = regexp(ex, '\{[^{}]*\}', 'match');
bad = subs(cellfun(@isempty, regexp(subs, '^\{\s*-\s*\d+\s*\}$', 'once')));
if ~isempty(bad)
    error('hetlearn:extend_model:policy', 'spec.policy.targets.%s = "%s": only lags x{-k} (no leads).', name, ex);
end
[tok, e] = regexp(ex, '(?<![\w.])([A-Za-z]\w*)\>', 'tokens', 'end');
ids = {};
for i = 1:numel(tok)
    if isempty(regexp(ex(e(i)+1:end), '^\s*\(', 'once'))
        ids{end+1} = tok{i}{1}; %#ok<AGROW>
    end
end
unknown = setdiff(ids, S.declared);
if ~isempty(unknown)
    error('hetlearn:extend_model:policy', 'spec.policy.targets.%s = "%s": undeclared name(s) %s.', ...
        name, ex, strjoin(unknown, ', '));
end
if ~any(ismember(ids, S.tvars))
    error('hetlearn:extend_model:policy', 'spec.policy.targets.%s = "%s" has no transition variable.', name, ex);
end
end


function [ls, semi, err] = find_rule(code, masked, S, label, file)
% Start of the label (opening quote) and the closing ';' of the transition
% equation labelled exactly `label`; err = '' or the reason it was not found.
ls = 0;
semi = 0;
err = '';
[~, ~, labs] = mask_code(code);
hit = [];
for i = 1:size(labs, 1)
    a = labs(i, 1);
    b = labs(i, 2);
    if S.sec(a) == 2 && strcmp(code(a+1:b-1), label)
        hit(end+1) = i; %#ok<AGROW>
    end
end
if isempty(hit)
    err = sprintf(['no transition equation labelled "%s" in %s; spec.policy.rule_label must ' ...
        'match the label exactly'], label, file);
    return
elseif numel(hit) > 1
    err = sprintf('%d transition equations are labelled "%s" in %s; the rule label must be unique', ...
        numel(hit), label, file);
    return
end
a = labs(hit, 1);
b = labs(hit, 2);
k = find(masked(b+1:end) == ';', 1);
if isempty(k) || isempty(strfind(masked(b+1:b+k), '='))
    err = sprintf('the text labelled "%s" in %s is not an equation', label, file);
    return
end
ls = a;
semi = b + k;
end


function mask = section_mask(masked, kws)
% Characters inside the given declaration/equation sections.
CONTROL = {'if', 'elseif', 'else', 'end', 'for', 'do', 'switch', 'case', ...
    'otherwise', 'import', 'include', 'export', 'list', 'all_but', 'ttrend'};
[tok, st, en] = regexp(masked, '(?<!!)!([A-Za-z_]\w*)', 'tokens', 'start', 'end');
kw = cellfun(@(t) lower(t{1}), tok, 'UniformOutput', false);
keep = ~ismember(kw, CONTROL);
kw = kw(keep);
st = st(keep);
en = en(keep);
mask = false(1, numel(masked));
for k = 1:numel(kw)
    if ~ismember(kw{k}, kws)
        continue
    end
    b = numel(masked);
    if k < numel(kw)
        b = st(k + 1) - 1;
    end
    mask(en(k) + 1:b) = true;
end
end


function [rv, rs] = rule_only_names(masked, S, ruleSemi, shocks)
% Transition variables of the rule equation used nowhere else except in
% their own law of motion (recursively), and shocks that appear only in
% the rule and in those laws of motion (SW07: ms, em). Substitutions and
% measurement equations count as other uses.
q = find(masked == ';' & ismember(S.sec, [2 3 4]));
nE = numel(q);
ids = cell(1, nE);
lhs = repmat({''}, 1, nE);
sec = zeros(1, nE);
ruleEq = 0;
for j = 1:nE
    b = q(j);
    a = b;
    while a > 1 && S.sec(a - 1) == S.sec(b) && masked(a - 1) ~= ';'
        a = a - 1;
    end
    t = masked(a:b);
    t = regexprep(t, '(?<!!)!(if|elseif)\>[^\n]*', ' ');
    bang = strfind(t, '!!');
    if ~isempty(bang)
        t = t(1:bang(1) - 1);
    end
    ids{j} = unique(regexp(t, '(?<![\w.!$`?])[A-Za-z]\w*', 'match'));
    tok = regexp(t, '^\s*(?:!\w+\s+)*([A-Za-z]\w*)\s*:?=(?!=)', 'tokens', 'once');
    if ~isempty(tok)
        lhs{j} = tok{1};
    end
    sec(j) = S.sec(b);
    if b == ruleSemi
        ruleEq = j;
    end
end
rv = {};
rs = {};
if ruleEq == 0
    return
end
inRule = false(1, nE);
inRule(ruleEq) = true;
changed = true;
while changed
    changed = false;
    cand = setdiff(intersect(unique([ids{inRule}]), S.tvars), rv);
    for c = 1:numel(cand)
        v = cand{c};
        uses = find(cellfun(@(x) any(strcmp(x, v)), ids));
        own = uses(strcmp(lhs(uses), v) & sec(uses) == 2 & ~inRule(uses));
        others = setdiff(uses, [find(inRule), own]);
        if isempty(others) && numel(own) <= 1
            rv{end+1} = v; %#ok<AGROW>
            inRule(own) = true;
            changed = true;
        end
    end
end
for i = 1:numel(shocks)
    uses = find(cellfun(@(x) any(strcmp(x, shocks{i})), ids));
    if ~isempty(uses) && all(inRule(uses))
        rs{end+1} = shocks{i}; %#ok<AGROW>
    end
end
end


function [txt, err] = expand_subs(txt, masked, S)
% Paste !substitutions into txt as IRIS does ($name$ -> its text, no
% parentheses added), recursively.
err = '';
subs = struct();
q = find(masked == ';' & S.sec == 3);
for j = 1:numel(q)
    b = q(j);
    a = b;
    while a > 1 && S.sec(a - 1) == 3 && masked(a - 1) ~= ';'
        a = a - 1;
    end
    tok = regexp(masked(a:b-1), '^\s*([A-Za-z]\w*)\s*:?=\s*(.*?)\s*$', 'tokens', 'once');
    if ~isempty(tok)
        subs.(tok{1}) = regexprep(tok{2}, '\s+', ' ');
    end
end
for it = 1:200
    tok = regexp(txt, '\$(\w+)\$', 'tokens', 'once');
    if isempty(tok)
        return
    end
    if ~isfield(subs, tok{1})
        err = sprintf('unknown substitution $%s$', tok{1});
        return
    end
    txt = strrep(txt, ['$' tok{1} '$'], subs.(tok{1}));
end
err = 'substitutions nested too deeply';
end


% =========================================================================
% N agent types (docs/DESIGN_br_extensions.md 1.1, phase P2, 2026-10-20)
% =========================================================================
function meta = ntype_generate(B, types)
% Extended model of an N-type population, generator version 6: for each
% forward-looking variable x, one forecast variable <x>_exp1_<k> per type k
% that forecasts x (the RE type always), the share parameters n_<k>_x, the
% aggregate <x>_exp1 = sum_k n_<k>_x*<x>_exp1_<k>, type-suffixed PLM
% parameters (alpha_x__<k>, beta_x__<k>, ...; hetlearn.plm.build_system with
% a suffix) and rule constants (<p>__<k>). The br_<x>, re_anchored and
% br_info_current switches keep their meaning (every type inherits
% expectations.re_variant / beliefs.info since 2026-10-22). Files
% <name>_ext_n<hash>.model and _meta.mat, hash over the resolved types
% (types is hetlearn.agent_types(...).gen).
GENERATOR_VERSION = 6;
spec = B.spec;
S = B.S;
fwd = B.fwd;
assign = B.assign;
types = reshape(types, 1, []);
if isempty(types) || ~strcmp(types(1).name, 'RE') || ~strcmp(types(1).kind, 're')
    error('hetlearn:extend_model:types', 'The first agent type must be the RE type (name RE, kind ''re'').');
end
reInfo = char(types(1).info);
if ~any(strcmp(reInfo, {'current', 'lagged'}))
    error('hetlearn:extend_model:types', 'The RE type needs a resolved information set (''current'' | ''lagged'').');
end

% ---- derived regressors of every PLM type ------------------------------------------
derived = struct();
for i = 1:numel(types)
    if ~strcmp(types(i).kind, 'plm') || isempty(types(i).plm) || ~isstruct(types(i).plm)
        continue
    end
    d = derived_defs(types(i).plm, S, assign);
    f = fieldnames(d);
    for j = 1:numel(f)
        if isfield(derived, f{j}) && ~strcmp(derived.(f{j}), d.(f{j}))
            error('hetlearn:extend_model:derived', ['Derived regressor %s is defined twice with different ' ...
                'expressions (types of expectations.types).'], f{j});
        end
        derived.(f{j}) = d.(f{j});
    end
end
derNames = fieldnames(derived)';
allVar = [S.tvars, derNames];

% ---- per type: variables, PLM systems, rules ----------------------------------------
G = struct('name', {}, 'kind', {}, 'variant', {}, 'info', {}, 'vars', {}, 'plm', {}, 'rule', {}, ...
    'sys', {}, 'key', {}, 'rules', {});
p4kinds = false;          % re_mean types (phase P4): generator version 8
for i = 1:numel(types)
    t = types(i);
    g = struct('name', t.name, 'kind', t.kind, 'variant', char_or(t.variant), 'info', char_or(t.info), ...
        'vars', {fwd}, 'plm', t.plm, 'rule', t.rule, 'sys', [], 'key', '', 'rules', struct());
    switch t.kind
        case 're'
            if ~any(strcmp(g.variant, {'', 'anchored', 'model_consistent'})) || ~any(strcmp(g.info, {'current', 'lagged'}))
                error('hetlearn:extend_model:types', 'Type %s: variant ''%s'' / info ''%s'' not resolved.', ...
                    t.name, g.variant, g.info);
            end
            g.key = sprintf('%s:re:%s:%s:%s', t.name, g.variant, g.info, strjoin(g.vars, ','));
        case 'plm'
            if ~any(strcmp(g.info, {'', 'current', 'lagged'}))
                error('hetlearn:extend_model:types', 'Type %s: info ''%s''.', t.name, g.info);
            end
            sysU = hetlearn.plm.build_system(t.plm, g.vars, allVar);
            [~, pk] = normalise_plm(t.plm, sysU);
            g.sys = hetlearn.plm.build_system(t.plm, g.vars, allVar, 'lagged', t.name);
            g.key = sprintf('%s:plm:%s:%s:{%s}', t.name, g.info, strjoin(g.vars, ','), pk);
        case 'rule'
            if ~any(strcmp(g.info, {'current', 'lagged'}))
                error('hetlearn:extend_model:types', 'Type %s: info ''%s'' not resolved.', t.name, g.info);
            end
            for j = 1:numel(g.vars)
                x = g.vars{j};
                g.rules.(x) = hetlearn.plm.rule_terms(t.rule, x, t.name, g.info, S.tvars);
            end
            pn = {};
            if isstruct(t.rule) && isfield(t.rule, 'params') && isstruct(t.rule.params)
                pn = sort(fieldnames(t.rule.params))';
            end
            ex = t.rule;
            if isstruct(ex)
                ex = ex.expr;
            end
            g.key = sprintf('%s:rule:%s:%s:%s:%s', t.name, g.info, strjoin(g.vars, ','), ...
                regexprep(char(ex), '\s', ''), strjoin(pn, ','));
        case 're_mean'
            % RE forecast plus a learned mean of its error (mechanism 23, phase P4): x_exp1_<k> = x_exp1_RE +
            % alpha_<x>_feRE__<k>, the mean-only PLM of the generated target x_feRE = x - x_exp1_RE{-1}
            zv = strcat(g.vars, '_feRE');
            bv = struct();
            for j = 1:numel(zv)
                bv.(zv{j}) = struct('regressors', {{}}, 'constant', true);
            end
            g.plm = struct('default', 'ar1', 'by_var', bv, 'derived', struct(), ...
                'var', struct('variables', {{}}, 'lags', 1, 'constant', true));
            g.sys = hetlearn.plm.build_system(g.plm, zv, [allVar, zv], 'lagged', t.name);
            g.key = sprintf('%s:re_mean:%s', t.name, strjoin(g.vars, ','));
            p4kinds = true;
        otherwise
            error('hetlearn:extend_model:types', 'Type %s: kind ''%s'' is not known.', t.name, t.kind);
    end
    G(i) = g;
end
if p4kinds
    GENERATOR_VERSION = 8;
end
byx = struct();
for i = 1:numel(fwd)
    x = fwd{i};
    byx.(x) = find(arrayfun(@(g) any(strcmp(g.vars, x)), G));
end
% forecast transforms (DESIGN_br_extensions 1.3, phase P3): resolved against the model here; the
% factors are parameters set by hetlearn.load_model, so the file depends on their structure only
TF = tf_setup(B, G, byx);
if TF.has
    GENERATOR_VERSION = max(GENERATOR_VERSION, 7);
    B.occ = TF.occ;                % equation copies: x{+1} of their equations -> x_exp1__<tag>
end
% the RE type's anchored expression of each forward variable (phase P4, DESIGN_br_extensions 1.4): the
% original states plus the states that transforms add and that exist in both the anchor economy and
% the anchored one (memory states of diagnostic expectations outside the learning set), each written
% only in the branches where it exists; with a diagnostic transform on the lagged RE type, its
% anchored reference x_DEg_RE (E_{t-1} x_{t+2}) and its lag
AX = anchor_extra(TF, fwd, byx, G);
if TF.has
    TF.deg_vars = AX.deg_vars;        % anchored versions with the reference x_DEg_RE{-1}
    TF.meta.deg_vars = AX.deg_vars;
end

% ---- names and collisions ---------------------------------------------------------
gen = {};
expVars = struct();
shareParams = struct();
typeOrder = struct();
toggles = cell(1, numel(fwd));
reChain = struct();
beliefParams = struct();
ruleParams = struct();
for i = 1:numel(fwd)
    x = fwd{i};
    ix = byx.(x);
    agg = arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:B.maxLead.(x), 'UniformOutput', false);
    tv = struct();
    for j = ix
        tv.(G(j).name) = sprintf('%s_exp1_%s', x, G(j).name);
    end
    expVars.(x) = struct('agg', {agg}, 're', [x '_exp1_RE'], 'br', '', 'types', tv);
    typeOrder.(x) = {G(ix).name};
    shareParams.(x) = cellfun(@(k) sprintf('n_%s_%s', k, x), typeOrder.(x), 'UniformOutput', false);
    toggles{i} = ['br_' x];
    gen = [gen, agg, struct2cell(tv)', shareParams.(x), toggles(i)]; %#ok<AGROW>
    lagRE = ix(arrayfun(@(j) strcmp(G(j).kind, 're') && strcmp(G(j).info, 'lagged'), ix));
    if ~isempty(lagRE)
        reChain.(x) = {[x '_REt1'], [x '_REt2']};
        gen = [gen, reChain.(x)]; %#ok<AGROW>
    end
    if any(arrayfun(@(j) strcmp(G(j).kind, 're_mean'), ix))
        gen{end+1} = [x '_feRE']; %#ok<AGROW>       % error of the RE forecast, target of the re_mean types
    end
    if AX.(x).deg
        gen{end+1} = [x '_DEg_RE']; %#ok<AGROW>     % anchored diagnostic reference of the RE type
    end
end
for j = 1:numel(G)
    if ~isempty(G(j).sys)
        for q = 1:numel(G(j).sys.eq)
            e = G(j).sys.eq(q);
            beliefParams.([e.target '__' G(j).name]) = e.param_names;
            gen = [gen, e.param_names]; %#ok<AGROW>
        end
    end
    if strcmp(G(j).kind, 'rule') && ~isempty(G(j).vars)
        R = G(j).rules.(G(j).vars{1});
        pf = fieldnames(R.param_names);
        for q = 1:numel(pf)
            ruleParams.(R.param_names.(pf{q})) = R.param_values.(pf{q});
            gen{end+1} = R.param_names.(pf{q}); %#ok<AGROW>
        end
    end
end
gen = [gen, derNames, {B.anchorToggle, B.infoToggle}, B.pol.gen_names];
if TF.has
    % the chains x_REt1, x_REt2 of the diagnostic references may be the lagged RE chain already
    own = TF.gen_names(~ismember(TF.gen_names, TF.chain_names));
    gen = [gen, own, setdiff(TF.chain_names, gen, 'stable')];
end
clash = intersect(gen, [S.declared, fieldnames(assign)']);
if ~isempty(clash)
    error('hetlearn:extend_model:nameCollision', ...
        'Generated name(s) already used in %s or spec.assign: %s.', B.srcFile, strjoin(clash, ', '));
end
if numel(unique(gen)) < numel(gen)
    [u, iu] = unique(gen);
    dup = unique(gen(setdiff(1:numel(gen), iu)));
    error('hetlearn:extend_model:nameCollision', 'Generated names are not unique (%s); rename types or model variables.', ...
        strjoin(intersect(u, dup), ', '));
end

% ---- file names and cache -----------------------------------------------------------
dk = cellfun(@(n) sprintf('%s=%s', n, regexprep(derived.(n), '\s', '')), sort(derNames), 'UniformOutput', false);
fileKey = sprintf('v%d|%s|derived:%s', GENERATOR_VERSION, strjoin({G.key}, ';'), strjoin(dk, ','));
if TF.has
    fileKey = [fileKey '|transforms:' TF.key];
end
if ~isempty(AX.key)
    fileKey = [fileKey '|anchor:' AX.key];     % extra anchored terms (phase P4): own text
end
h = md5hex(unicode2native(fileKey, 'UTF-8'));
tag = ['n' h(1:8)];
genDir = fullfile(spec.folder, 'generated');
if exist(genDir, 'dir') ~= 7
    mkdir(genDir);
end
extFile = fullfile(genDir, sprintf('%s_ext_%s.model', spec.name, tag));
metaFile = fullfile(genDir, sprintf('%s_ext_%s_meta.mat', spec.name, tag));
normFile = fullfile(genDir, sprintf('%s_norm.model', spec.name));
if ~B.force && exist(metaFile, 'file') == 2 && exist(extFile, 'file') == 2
    L = load(metaFile, 'meta');
    old = L.meta;
    usedNorm = isfield(old, 'ref_file') && isfield(old, 'source_file') && ~strcmp(old.ref_file, old.source_file);
    refNow = B.srcFile;
    if usedNorm
        refNow = normFile;
    end
    if isfield(old, 'generator_version') && old.generator_version == GENERATOR_VERSION ...
            && strcmp(old.source_hash, B.srcHash) && strcmp(old.plm_key, fileKey) ...
            && isfield(old, 'assign_key') && strcmp(old.assign_key, B.assignKey) ...
            && isfield(old, 'policy_key') && strcmp(old.policy_key, B.pol.key) ...
            && ~(B.validate && isfield(old, 'anchor_error') && ~isempty(old.anchor_error)) ...
            && exist(refNow, 'file') == 2
        meta = old;
        meta.source_file = B.srcFile;
        meta.ref_file = refNow;
        meta.ext_file = extFile;
        if B.validate && ~meta.validated
            [meta.collapse_maxdiff, meta.collapse_info_maxdiff, meta.collapse_lagged_sets] = ...
                collapse_test_nt(spec, assign, meta);
            meta.validated = true;
            save(metaFile, 'meta');
        end
        return
    end
end

% ---- rewrite (as the two-type writer) -------------------------------------------------
code = B.code;
extBody = code;
normBody = code;
spl = [B.occ, B.pol.inserts];
[~, ord] = sort([spl.s], 'descend');
for q = ord
    o = spl(q);
    extBody = [extBody(1:o.s-1), o.ext, extBody(o.e+1:end)];
    normBody = [normBody(1:o.s-1), o.norm, normBody(o.e+1:end)];
end
if B.preparsed || ~strcmp(normBody, code)
    write_text(normFile, normBody);
    refFile = normFile;
else
    refFile = B.srcFile;
end
anchor = anchor_states(refFile, spec, assign, fwd, B.anchorToggle, B.validate);
% phase P4 (DESIGN_br_extensions 1.4): the RE type's anchored expression over the original states and
% the extra terms of anchor_extra, and the anchored diagnostic reference. All are parameters that
% hetlearn.load_model sets; the RE limit has them at 0 (extra).
anchor.xstates = struct();
anchor.xconds = struct();
anchor.deg = struct();
extra = struct();
if anchor.ok
    for i = 1:numel(fwd)
        x = fwd{i};
        st = [anchor.states, AX.(x).states];
        anchor.xstates.(x) = st;
        anchor.xconds.(x) = [repmat({''}, 1, numel(anchor.states)), AX.(x).conds];
        anchor.params.(x) = hetlearn.plm.anchor_names(x, st);
        if AX.(x).deg
            anchor.deg.(x) = hetlearn.plm.anchor_names([x '_DEg'], st);
            extra.([x '_DEg']) = anchor.deg.(x);
        end
    end
end
an = [struct2cell(anchor.params); struct2cell(extra)];
an = [an{:}];
if isempty(an)
    an = {};
end
[ua, ia] = unique(an, 'stable');
dup = unique(an(setdiff(1:numel(an), ia)));
clash = [intersect(ua, [S.declared, fieldnames(assign)', gen]), dup];
if ~isempty(clash)
    error('hetlearn:extend_model:nameCollision', ...
        'Anchored-RE parameter names collide with model names or with each other: %s.', strjoin(clash, ', '));
end
chainMode = struct();
for i = 1:numel(fwd)
    x = fwd{i};
    chainMode.(x) = '';
    if ~isfield(reChain, x)
        continue
    end
    ix = byx.(x);
    lagRE = ix(arrayfun(@(j) strcmp(G(j).kind, 're') && strcmp(G(j).info, 'lagged'), ix));
    vs = {G(lagRE).variant};
    if any(strcmp(vs, 'model_consistent')) || (any(strcmp(vs, '')) && ~anchor.ok)
        chainMode.(x) = 'always';
    elseif any(strcmp(vs, ''))
        chainMode.(x) = 'toggle';
    else
        chainMode.(x) = 'none';     % only anchored lagged types: no chain in the text
        reChain = rmfield(reChain, x);
    end
end
if TF.has
    [TF, chainMode] = tf_chains(TF, reChain, chainMode, anchor);
end
block = make_block_ntype(G, byx, fwd, B.maxLead, tag, spec, S, derived, anchor, B.infoToggle, reChain, chainMode, ...
    reInfo, TF);
if isempty(extBody) || extBody(end) ~= newline
    extBody = [extBody, newline];
end
write_text(extFile, [extBody, block, B.pol.block]);

meta = struct();
meta.name = spec.name;
meta.source_file = B.srcFile;
meta.source_hash = B.srcHash;
meta.plm = [];
meta.plm_key = fileKey;
meta.plmtag = tag;
meta.ext_file = extFile;
meta.ref_file = refFile;
meta.forward_vars = fwd;
meta.max_lead = B.maxLead;
meta.exp_vars = expVars;
meta.toggles = toggles;
meta.belief_params = beliefParams;   % by '<target>__<type>'
meta.share_params = shareParams;     % by variable, in meta.type_order order
meta.sys = [];                       % the two-type PLM system: none (see type_sys)
meta.derived = derived;
meta.re_states = anchor.states;
meta.anchor_ok = anchor.ok;
meta.anchor_error = anchor.error;
meta.anchor_params = anchor.params;
meta.anchor_toggle = B.anchorToggle;
meta.info_toggle = B.infoToggle;
meta.policy = B.pol.meta;
meta.policy_key = B.pol.key;
meta.policy_toggle = '';
if B.pol.has && B.pol.meta.ok
    meta.policy_toggle = B.policyToggle;
end
meta.preparsed = B.preparsed;
meta.validated = false;
meta.collapse_maxdiff = [NaN, NaN, NaN];
meta.collapse_info_maxdiff = NaN;
meta.assign_key = B.assignKey;
meta.generator_version = GENERATOR_VERSION;
meta.created = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
meta.ntype = true;
meta.types = rmfield(G, {'sys', 'rules', 'key'});
meta.type_order = typeOrder;          % by variable: the types that forecast it, RE first
meta.type_sys = struct();             % by type: the type-suffixed PLM system over its variables
meta.rules = struct();                % by type, then variable: hetlearn.plm.rule_terms output
for j = 1:numel(G)
    if ~isempty(G(j).sys)
        meta.type_sys.(G(j).name) = G(j).sys;
    end
    if strcmp(G(j).kind, 'rule')
        meta.rules.(G(j).name) = G(j).rules;
    end
end
meta.rule_params = ruleParams;        % model parameter name -> value
meta.re_info = reInfo;                % information set of the RE type
meta.re_chain = reChain;              % by variable with a lagged RE chain: {x_REt1, x_REt2}
meta.chain_mode = chainMode;
% phase P4 (DESIGN_br_extensions 1.4)
meta.anchor_xstates = anchor.xstates; % by variable: states of the RE type's anchored expression (original + extra)
meta.anchor_xconds = anchor.xconds;   % their !if conditions ('' = always written)
meta.anchor_deg = anchor.deg;         % by variable: parameters of the anchored diagnostic reference x_DEg_RE
meta.anchor_extra = extra;            % parameter lists beyond anchor_params (0 at the RE limit)
if TF.has
    meta.transforms = TF.meta;        % forecast transforms (phase P3): structure, parameter roles, identity values
end
meta.collapse_lagged_sets = {};
if exist(metaFile, 'file') == 2
    delete(metaFile);
end
if B.validate
    [meta.collapse_maxdiff, meta.collapse_info_maxdiff, meta.collapse_lagged_sets] = collapse_test_nt(spec, assign, meta);
    meta.validated = true;
end
save(metaFile, 'meta');
end


function s = char_or(v)
if isempty(v)
    s = '';
else
    s = char(v);
end
end


% =========================================================================
function txt = make_block_ntype(G, byx, fwd, maxLead, tag, spec, S, derived, anchor, infoToggle, reChain, chainMode, reInfo, TF)
% Expectation block of an N-type file. With the two types RE and BR it has
% the lines of make_block / make_block_lagged in the same order, with the
% shares n_RE_x, n_BR_x and the parameters alpha_x__BR, beta_x__BR.
% Forecast transforms (TF.has, phase P3): x_exp1 = sum_k n_k_x*T_k(x_exp1_k)
% in the learning branch and x_exp1 = T(x{+1}) outside it, equation copies
% x_exp1__<tag> beside x_exp1, diagnostic reference chains, and the factors
% as parameters (tf_* helpers below). Without transforms the text is that of
% phase P2.
if nargin < 14 || isempty(TF)
    TF = struct('has', false);
end
lagged = strcmp(reInfo, 'lagged');
desc = arrayfun(@type_desc, G, 'UniformOutput', false);
L = {};
L{end+1} = '';
L{end+1} = '% =====================================================================';
L{end+1} = ['% hetlearn expectation block (hetlearn.extend_model), N agent types, tag ' tag];
L{end+1} = ['% Types: ' strjoin(desc, '; ')];
if TF.has
    L{end+1} = ['% Forecast transforms (DESIGN_br_extensions 1.3): ' strjoin(TF.desc, '; ')];
end
L{end+1} = ['% Source: ' strrep(spec.model_file, '\', '/') '. Do not edit; regenerate instead.'];
L{end+1} = '% =====================================================================';
dn = fieldnames(derived);
L{end+1} = '!transition_variables';
for i = 1:numel(dn)
    L{end+1} = sprintf('    "Derived PLM regressor, %s = %s" %s', dn{i}, derived.(dn{i}), dn{i}); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    for k = 1:maxLead.(x)
        L{end+1} = sprintf('    "Aggregate expectation of %s{+%d}" %s_exp%d', x, k, x, k); %#ok<AGROW>
    end
    if TF.has
        L = [L, tf_decl_copies(TF, x)]; %#ok<AGROW>
    end
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    for j = byx.(x)
        L{end+1} = sprintf('        "%s" %s_exp1_%s', var_label(G(j), x, lagged), x, G(j).name); %#ok<AGROW>
    end
    if isfield(reChain, x)
        ch = reChain.(x);
        wrap = strcmp(chainMode.(x), 'toggle') && anchor.ok;
        if wrap
            L{end+1} = sprintf('        !if ~%s', anchor.toggle); %#ok<AGROW>
        end
        L{end+1} = sprintf('        "Lagged RE chain: E_t %s{+1}" %s', x, ch{1}); %#ok<AGROW>
        L{end+1} = sprintf('        "Lagged RE chain: E_t %s{+2}" %s', x, ch{2}); %#ok<AGROW>
        if wrap
            L{end+1} = '        !end'; %#ok<AGROW>
        end
    end
    if any(arrayfun(@(j) strcmp(G(j).kind, 're_mean'), byx.(x)))
        L{end+1} = sprintf('        "Error of the RE forecast of %s, %s - %s_exp1_RE{-1} (target of the re_mean types)" %s_feRE', ...
            x, x, x, x); %#ok<AGROW>
    end
    if anchor.ok && isfield(anchor.deg, x)
        L{end+1} = sprintf('        !if %s', anchor.toggle); %#ok<AGROW>
        L{end+1} = sprintf(['            "Anchored RE forecast of %s{+2} with information up to t-1 (reference of the ' ...
            'diagnostic transform)" %s_DEg_RE'], x, x); %#ok<AGROW>
        L{end+1} = '        !end'; %#ok<AGROW>
    end
    if TF.has
        L = [L, tf_decl_branches(TF, x, anchor)]; %#ok<AGROW>
    end
    L{end+1} = '    !end'; %#ok<AGROW>
end
L{end+1} = '!parameters';
for i = 1:numel(fwd)
    x = fwd{i};
    for j = byx.(x)
        L{end+1} = sprintf('    "Share of type %s, %s" n_%s_%s', G(j).name, x, G(j).name, x); %#ok<AGROW>
    end
end
for j = 1:numel(G)
    if isempty(G(j).sys)
        continue
    end
    for q = 1:numel(G(j).sys.eq)
        e = G(j).sys.eq(q);
        if strcmp(G(j).kind, 're_mean')
            L{end+1} = sprintf('    "Mean belief of type %s about the error of the RE forecast, %s" %s', G(j).name, ...
                e.target, e.param_names{1}); %#ok<AGROW>
            continue
        end
        kind = 'PLM';
        if e.isAux
            kind = 'Auxiliary PLM';
        end
        p = 0;
        if e.constant
            p = 1;
            L{end+1} = sprintf('    "%s constant, %s (type %s)" %s', kind, e.target, G(j).name, e.param_names{1}); %#ok<AGROW>
        end
        for r = 1:numel(e.reg_names)
            L{end+1} = sprintf('    "%s coefficient, %s on %s{-%d} (type %s)" %s', kind, e.target, ...
                e.reg_names{r}, e.reg_lags(r), G(j).name, e.param_names{p + r}); %#ok<AGROW>
        end
    end
end
for j = 1:numel(G)
    if ~strcmp(G(j).kind, 'rule') || isempty(G(j).vars)
        continue
    end
    R = G(j).rules.(G(j).vars{1});
    pf = fieldnames(R.param_names);
    for q = 1:numel(pf)
        L{end+1} = sprintf('    "Constant %s of the rule of type %s" %s', pf{q}, G(j).name, R.param_names.(pf{q})); %#ok<AGROW>
    end
end
if anchor.ok
    for i = 1:numel(fwd)
        x = fwd{i};
        pn = anchor.params.(x);
        xs = anchor.xstates.(x);         % original states, then the extra terms of phase P4
        if lagged
            L{end+1} = sprintf('    "Anchored RE forecast of %s{+1} with information up to t-1, constant" %s', x, pn{1}); %#ok<AGROW>
            for j = 1:numel(xs)
                L{end+1} = sprintf('    "Anchored RE forecast of %s{+1} with information up to t-1, coefficient on %s dated t-1" %s', ...
                    x, xs{j}, pn{1 + j}); %#ok<AGROW>
            end
        else
            L{end+1} = sprintf('    "Anchored RE forecast of %s{+1}, constant" %s', x, pn{1}); %#ok<AGROW>
            for j = 1:numel(xs)
                L{end+1} = sprintf('    "Anchored RE forecast of %s{+1}, coefficient on %s" %s', ...
                    x, xs{j}, pn{1 + j}); %#ok<AGROW>
            end
        end
        if isfield(anchor.deg, x)
            pd = anchor.deg.(x);
            L{end+1} = sprintf('    "Anchored RE forecast of %s{+2} with information up to t-1 (diagnostic reference), constant" %s', ...
                x, pd{1}); %#ok<AGROW>
            for j = 1:numel(xs)
                L{end+1} = sprintf(['    "Anchored RE forecast of %s{+2} with information up to t-1 (diagnostic reference), ' ...
                    'coefficient on %s dated t-1" %s'], x, xs{j}, pd{1 + j}); %#ok<AGROW>
            end
        end
    end
end
if TF.has
    L = [L, tf_decl_params(TF)];
end
L{end+1} = '!transition_equations';
for i = 1:numel(dn)
    L{end+1} = sprintf('    %s = %s;', dn{i}, derived.(dn{i})); %#ok<AGROW>
end
for i = 1:numel(fwd)
    x = fwd{i};
    ix = byx.(x);
    L{end+1} = sprintf('    !if br_%s', x); %#ok<AGROW>
    if TF.has
        L = [L, tf_learn_lines(TF, G, x, ix, anchor.toggle)]; %#ok<AGROW>
    else
        terms = arrayfun(@(j) sprintf('n_%s_%s*%s_exp1_%s', G(j).name, x, x, G(j).name), ix, 'UniformOutput', false);
        L{end+1} = sprintf('        %s_exp1 = %s;', x, strjoin(terms, ' + ')); %#ok<AGROW>
    end
    ch = {};
    if isfield(reChain, x)
        ch = reChain.(x);
    end
    % the chain equations sit in the RE type's !else branch when that is the only place
    % they are needed (the two-type layout); else in their own block below
    inline = strcmp(chainMode.(x), 'toggle') && anchor.ok && lagged;
    if lagged
        L{end+1} = '        % RE agents with information up to t-1: x_exp1_RE_t = E_{t-1} x_{t+1} (DESIGN 19)'; %#ok<AGROW>
    end
    for j = ix
        g = G(j);
        nm = sprintf('%s_exp1_%s', x, g.name);
        switch g.kind
            case 're'
                L = [L, re_type_lines(nm, x, g, anchor, ch, inline && j == 1)]; %#ok<AGROW>
            case 'plm'
                % the br_info_current switch (beliefs.info; every type inherits it)
                L{end+1} = sprintf('        !if %s', infoToggle); %#ok<AGROW>
                L{end+1} = sprintf('            %s = %s;', nm, hetlearn.plm.forecast_expr(g.sys, x, 'current')); %#ok<AGROW>
                L{end+1} = '        !else'; %#ok<AGROW>
                L{end+1} = sprintf('            %s = %s;', nm, hetlearn.plm.forecast_expr(g.sys, x, 'lagged')); %#ok<AGROW>
                L{end+1} = '        !end'; %#ok<AGROW>
            case 'rule'
                L{end+1} = sprintf('        %s = %s;', nm, g.rules.(x).text); %#ok<AGROW>
            case 're_mean'
                e = g.sys.eq(strcmp(g.sys.targets, [x '_feRE']));
                L{end+1} = sprintf('        %s = %s_exp1_RE + %s;', nm, x, e.param_names{1}); %#ok<AGROW>
        end
    end
    if any(arrayfun(@(j) strcmp(G(j).kind, 're_mean'), ix))
        L{end+1} = sprintf('        %s_feRE = %s - %s_exp1_RE{-1};', x, x, x); %#ok<AGROW>
    end
    if ~isempty(ch) && ~inline
        chainEq = {sprintf('%s = %s{+1};', ch{2}, ch{1}), sprintf('%s = %s{+1};', ch{1}, x)};
        wrap = strcmp(chainMode.(x), 'toggle') && anchor.ok;
        if wrap
            L{end+1} = sprintf('        !if ~%s', anchor.toggle); %#ok<AGROW>
            L = [L, strcat({'            '}, chainEq)]; %#ok<AGROW>
            L{end+1} = '        !end'; %#ok<AGROW>
        else
            L = [L, strcat({'        '}, chainEq)]; %#ok<AGROW>
        end
    end
    if TF.has
        L = [L, tf_learn_chain_lines(TF, x, anchor)]; %#ok<AGROW>
    end
    L{end+1} = '    !else'; %#ok<AGROW>
    if TF.has
        L = [L, tf_mc_lines(TF, x)]; %#ok<AGROW>
    else
        L{end+1} = sprintf('        %s_exp1 = %s{+1};', x, x); %#ok<AGROW>
    end
    L{end+1} = '    !end'; %#ok<AGROW>
    for k = 2:maxLead.(x)
        L{end+1} = sprintf('    %s_exp%d = %s_exp%d{+1};', x, k, x, k - 1); %#ok<AGROW>
    end
end
logged = {};
for i = 1:numel(fwd)
    x = fwd{i};
    inList = any(strcmp(S.logvars, x));
    if S.log_all_but
        if inList
            warning('hetlearn:extend_model:logAllBut', ...
                ['%s is excluded with !all_but in !log_variables; the generated ' ...
                'expectation variables of %s will be treated as log variables.'], x, x);
        end
    elseif inList
        logged = [logged, arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:maxLead.(x), ...
            'UniformOutput', false)]; %#ok<AGROW>
        if TF.has
            logged = [logged, {TF.meta.copies(strcmp({TF.meta.copies.var}, x)).name}]; %#ok<AGROW>
        end
    end
end
if ~isempty(logged)
    L{end+1} = '!log_variables';
    L{end+1} = ['    ' strjoin(logged, ', ')];
end
txt = [strjoin(L, newline), newline];
end


function L = re_type_lines(nm, x, g, anchor, ch, inlineChain)
% x_exp1_RE of the RE type: anchored (re_anchored = true) or model-consistent, with period-t or t-1
% information (the lagged chain x_REt2{-1}). The anchored expression runs over the original states and
% the extra terms of phase P4 (anchor.xstates, conditional ones in !if blocks); the RE type of a
% variable with an anchored diagnostic reference also writes x_DEg_RE (anchor.deg).
L = {};
lagged = ~strcmp(g.info, 'current');
anL = {};
if anchor.ok
    anL = anchor_lines(nm, anchor.params.(x), anchor.xstates.(x), anchor.xconds.(x), lagged, '');
    if lagged && strcmp(g.name, 'RE') && isfield(anchor.deg, x)
        anL = [anL, anchor_lines([x '_DEg_RE'], anchor.deg.(x), anchor.xstates.(x), anchor.xconds.(x), true, '')];
    end
end
an = strjoin(anL, [newline '            ']);   % one line unless phase P4 terms are present
if ~lagged
    mc = sprintf('%s = %s{+1};', nm, x);
    extra = {};
else
    mc = sprintf('%s = %s{-1};', nm, ch{2});
    extra = {};
    if inlineChain
        extra = {sprintf('%s = %s{+1};', ch{2}, ch{1}), sprintf('%s = %s{+1};', ch{1}, x)};
    end
end
if anchor.ok
    L{end+1} = sprintf('        !if %s', anchor.toggle);
    L{end+1} = ['            ' an];
    L{end+1} = '        !else';
    L{end+1} = ['            ' mc];
    for q = 1:numel(extra)
        L{end+1} = ['            ' extra{q}]; %#ok<AGROW>
    end
    L{end+1} = '        !end';
else
    L{end+1} = ['        ' mc];
    for q = 1:numel(extra)
        L{end+1} = ['        ' extra{q}]; %#ok<AGROW>
    end
end
end


function s = var_label(g, x, lagged)
switch g.kind
    case 're_mean'
        s = sprintf('Type %s (RE forecast plus a learned mean) expectation of %s{+1}', g.name, x);
    case 're'
        s = sprintf('RE expectation of %s{+1}', x);
        if lagged
            s = [s, ', information up to t-1'];
        end
    case 'plm'
        s = sprintf('Type %s (learned PLM) expectation of %s{+1}', g.name, x);
    case 'rule'
        s = sprintf('Type %s (rule) expectation of %s{+1}', g.name, x);
end
end


function s = type_desc(g)
switch g.kind
    case 're_mean'
        s = sprintf('%s (re_mean on the RE forecast)', g.name);
    case 're'
        v = g.variant;
        if isempty(v)
            v = 're_anchored switch';
        end
        s = sprintf('%s (re, %s, %s)', g.name, v, g.info);
    case 'plm'
        i = g.info;
        if isempty(i)
            i = 'br_info_current switch';
        end
        s = sprintf('%s (plm, %s)', g.name, i);
    case 'rule'
        e = g.rule;
        if isstruct(e)
            e = e.expr;
        end
        s = sprintf('%s (rule %s, %s)', g.name, regexprep(char(e), '\s+', ' '), g.info);
end
end


% =========================================================================
function [maxdiff, infoDiff, sets] = collapse_test_nt(spec, assign, meta)
% Collapse test of an N-type file (DESIGN_br_extensions 1.7). Every share on
% the RE type (n_RE_x = 1, the other shares 0), beliefs 0, rule constants at
% their values, forecast transforms at their identity values: the tests of
% collapse_test (RE information 'current') or collapse_test_lagged ('lagged')
% with the same tolerance, 1e-10 on the IRFs of every variable of the
% reference model to its shocks, 40 periods.
TOL = 1e-10;
params = call_params(spec);
mo = Model.fromFile(meta.ref_file, 'linear', logical(spec.linear), 'assign', assign);
mo = put_params(mo, params);
mo = prepare(mo, spec, 'reference model');
so = srf(mo, 1:40);
xl = get(mo, 'xList');
el = get(mo, 'eList');
anchOK = meta.anchor_ok && logical(spec.linear);
maxdiff = [NaN, NaN, NaN];
infoDiff = NaN;
sets = {};
fwd = meta.forward_vars;
if strcmp(meta.re_info, 'current')
    Aa = struct();
    if anchOK
        Aa = hetlearn.re_anchor_coefficients(spec, params, 'vars', fwd, 'states', meta.re_states, 'model', mo);
    end
    cfg = {fwd, false, false; {}, false, false; fwd, true, false; fwd, false, true};
    for it = 1:4
        if it == 3 && ~anchOK
            continue
        end
        me = load_ext_nt(spec, assign, meta, cfg{it, 1}, cfg{it, 2}, cfg{it, 3}, params, Aa);
        [d, worst] = irf_diff(so, nt_srf(me, el, meta), xl);
        if it <= 3
            maxdiff(it) = d;
        else
            infoDiff = d;
        end
        if ~(d < TOL)
            error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (N types, learning %d of %d ' ...
                'variables, re_anchored = %d, br_info_current = %d): max abs IRF difference %.3g (variable %s) ' ...
                '>= %g. Extended file: %s'], numel(cfg{it, 1}), numel(fwd), cfg{it, 2}, cfg{it, 3}, d, worst, ...
                TOL, meta.ext_file);
        end
    end
    return
end
me = load_ext_nt(spec, assign, meta, {}, false, false, params, struct());
[maxdiff(2), worst] = irf_diff(so, nt_srf(me, el, meta), xl);
if ~(maxdiff(2) < TOL)
    error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (N types, lagged RE, br = false): ' ...
        'max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], maxdiff(2), worst, TOL, meta.ext_file);
end
lead1 = fwd(cellfun(@(x) meta.max_lead.(x) == 1 && isfield(meta.re_chain, x), fwd));
if isempty(lead1)
    return
end
try
    [dA, dI] = lagged_passes_nt(spec, assign, meta, lead1, params, xl, anchOK, TOL);
    sets = {lead1};
catch err
    if ~strcmp(err.identifier, 'hetlearn:extend_model:solveFailed')
        rethrow(err);
    end
    dA = NaN;
    dI = NaN;
    for i = 1:numel(lead1)
        [a, b] = lagged_passes_nt(spec, assign, meta, lead1(i), params, xl, anchOK, TOL);
        dA = max([dA, a], [], 'omitnan');
        dI = max([dI, b], [], 'omitnan');
        sets{end+1} = lead1(i); %#ok<AGROW>
    end
end
maxdiff(3) = dA;
infoDiff = dI;
end


function [dA, dI] = lagged_passes_nt(spec, assign, meta, set, params, xl, anchOK, TOL)
% Passes (2)-(4) of collapse_test_lagged for an N-type file.
dA = NaN;
mL = load_ext_nt(spec, assign, meta, set, false, false, params, struct());
sL = srf(mL, 1:40);
lab = strjoin(set, ',');
if anchOK
    Aa = hetlearn.re_anchor_coefficients(spec, params, 're_info', 'lagged', 'model', mL, ...
        'vars', set, 'states', meta.re_states, 'chain', meta.re_chain);
    mA = load_ext_nt(spec, assign, meta, set, true, false, params, Aa);
    [dA, worst] = irf_diff(sL, srf(mA, 1:40), xl);
    if ~(dA < TOL)
        error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (N types, lagged RE, learning {%s}, ' ...
            're_anchored = 1 vs 0): max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], ...
            lab, dA, worst, TOL, meta.ext_file);
    end
end
mI = load_ext_nt(spec, assign, meta, set, false, true, params, struct());
[dI, worst] = irf_diff(sL, srf(mI, 1:40), xl);
if ~(dI < TOL)
    error('hetlearn:extend_model:collapseFailed', ['Collapse test failed (N types, lagged RE, learning {%s}, ' ...
        'br_info_current = 1 vs 0): max abs IRF difference %.3g (variable %s) >= %g. Extended file: %s'], ...
        lab, dI, worst, TOL, meta.ext_file);
end
end


function me = load_ext_nt(spec, assign, meta, set, anch, cur, params, Aa)
% N-type file with br = true for the variables in set, every share on the RE type, beliefs 0,
% rule constants at their values and the anchored coefficients Aa (when given), solved.
a = assign;
for i = 1:numel(meta.toggles)
    a.(meta.toggles{i}) = any(strcmp(meta.forward_vars{i}, set));
end
a.(meta.anchor_toggle) = anch;
a.(meta.info_toggle) = cur;
if isfield(meta, 'policy_toggle') && ~isempty(meta.policy_toggle)
    a.(meta.policy_toggle) = false;
end
me = Model.fromFile(meta.ext_file, 'linear', logical(spec.linear), 'assign', a);
me = put_params(me, params);
me = put_params(me, ntype_re_limit(meta));
if ~isempty(fieldnames(Aa))
    me = put_params(me, Aa);
end
me = prepare(me, spec, sprintf('N-type file (learning {%s}, re_anchored = %d, br_info_current = %d)', ...
    strjoin(set, ','), anch, cur));
end


function se = nt_srf(me, el, meta) %#ok<INUSD>
% IRFs of an N-type model to the shocks el of the reference model (40 periods); the generated file
% declares no shocks of its own (the wedge shocks were removed on 2026-10-22)
if ~isequal(get(me, 'eList'), el)
    error('hetlearn:extend_model:collapseFailed', 'Shock lists differ between reference and extended model.');
end
se = srf(me, 1:40);
end


function Z = ntype_re_limit(meta)
% Parameters of the RE limit of an N-type file: n_RE_x = 1 and every other share 0, belief and
% anchored parameters 0, rule constants at their values; forecast transforms (phase P3) at their
% identity values (the collapse test).
Z = struct();
if isfield(meta, 'transforms') && ~isempty(meta.transforms)
    f = fieldnames(meta.transforms.identity);
    for i = 1:numel(f)
        Z.(f{i}) = meta.transforms.identity.(f{i});
    end
end
fwd = meta.forward_vars;
for i = 1:numel(fwd)
    x = fwd{i};
    sp = meta.share_params.(x);
    for j = 1:numel(sp)
        Z.(sp{j}) = double(strcmp(meta.type_order.(x){j}, 'RE'));
    end
end
f = fieldnames(meta.belief_params);
for i = 1:numel(f)
    pn = meta.belief_params.(f{i});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
f = fieldnames(meta.anchor_params);
for i = 1:numel(f)
    pn = meta.anchor_params.(f{i});
    for j = 1:numel(pn)
        Z.(pn{j}) = 0;
    end
end
if isfield(meta, 'anchor_extra')          % phase P4: the anchored diagnostic reference
    f = fieldnames(meta.anchor_extra);
    for i = 1:numel(f)
        pn = meta.anchor_extra.(f{i});
        for j = 1:numel(pn)
            Z.(pn{j}) = 0;
        end
    end
end
f = fieldnames(meta.rule_params);
for i = 1:numel(f)
    Z.(f{i}) = meta.rule_params.(f{i});
end
end


% =========================================================================
% Generalised anchor in the generated text (docs/DESIGN_br_extensions.md 1.4, phase P4, 2026-10-21)
% =========================================================================
function AX = anchor_extra(TF, fwd, byx, G)
% Extra terms of the RE type's anchored expression of each forward variable x: the states that the
% forecast transforms add and that exist both in the anchor economy (the RE limit, model-consistent)
% and in the anchored economy: the memory state z_REt2 of a diagnostic expectation outside the
% learning set (condition ~br_z). With a diagnostic
% transform on an RE type of x that follows re_variant and has information up to t-1, the anchored
% version uses the reference x_DEg_RE{-1}, x_DEg_RE = anchored E_{t-1} x_{t+2} (deg), and both anchored
% expressions get the term on x_DEg_RE{-1} (the chain state x_REt3{-1} of the anchor economy).
% AX.(x).states / .conds (cellstr, aligned), AX.(x).deg; AX.deg_vars; AX.key ('' when nothing extra).
AX = struct('deg_vars', {{}}, 'key', '');
parts = {};
for i = 1:numel(fwd)
    AX.(fwd{i}) = struct('states', {{}}, 'conds', {{}}, 'deg', false);
end
if ~TF.has
    return
end
for i = 1:numel(fwd)
    x = fwd{i};
    st = {};
    cd = {};
    for q = 1:numel(TF.need.mc)
        z = TF.need.mc{q};
        if ~strcmp(z, x)
            st{end+1} = [z '_REt2']; %#ok<AGROW>
            cd{end+1} = ['~br_' z]; %#ok<AGROW>
        end
    end
    deg = false;
    for q = 1:numel(TF.deferred)
        d = TF.deferred(q);
        j = find(strcmp({G.name}, d.type), 1);
        if strcmp(d.var, x) && ~isempty(j) && any(byx.(x) == j) && strcmp(G(j).info, 'lagged')
            deg = true;
        end
    end
    if deg
        st{end+1} = [x '_DEg_RE']; %#ok<AGROW>
        cd{end+1} = ''; %#ok<AGROW>
        AX.deg_vars{end+1} = x;
    end
    AX.(x) = struct('states', {st}, 'conds', {cd}, 'deg', deg);
    if ~isempty(st)
        parts{end+1} = sprintf('%s[%s]', x, strjoin(strcat(st, '@', cd), ',')); %#ok<AGROW>
    end
end
AX.key = strjoin(parts, ';');
end


function L = anchor_lines(lhs, pn, states, conds, lagged, ind)
% Lines of the anchored equation lhs = pn{1} + sum_j pn{1+j}*states{j} (each state dated one period
% earlier when lagged). Terms with a condition (conds{j}, e.g. '~br_c') sit in their own !if block
% inside the equation; without conditions the line is the one of anchor_expr / anchor_expr_lagged.
if nargin < 4 || isempty(conds)
    conds = repmat({''}, 1, numel(states));
end
u = cellfun(@isempty, conds);
pu = [pn(1), pn(1 + find(u))];
if lagged
    base = anchor_expr_lagged(pu, states(u));
else
    base = anchor_expr(pu, states(u));
end
if all(u)
    L = {sprintf('%s%s = %s;', ind, lhs, base)};
    return
end
L = {sprintf('%s%s = %s', ind, lhs, base)};
[~, sv, sl] = hetlearn.plm.anchor_names('x', states);
for j = find(~u)
    if lagged
        s = sprintf('%s{-%d}', sv{j}, sl(j) + 1);
    elseif sl(j) == 0
        s = sv{j};
    else
        s = sprintf('%s{-%d}', sv{j}, sl(j));
    end
    L{end+1} = sprintf('%s!if %s', ind, conds{j}); %#ok<AGROW>
    L{end+1} = sprintf('%s    + %s*%s', ind, pn{1 + j}, s); %#ok<AGROW>
    L{end+1} = sprintf('%s!end', ind); %#ok<AGROW>
end
L{end+1} = sprintf('%s;', ind);
end


% =========================================================================
% Forecast transforms (docs/DESIGN_br_extensions.md 1.3, phase P3, 2026-10-21)
% =========================================================================
function TF = tf_setup(B, G, byx)
% expectations.transforms resolved against the model (TF.has = false without transforms).
% Contexts: 'L' = the learning branch of x (br_x true), one per agent type k that forecasts x;
% 'N' = the model-consistent expectation of x outside the learning set (br_x false). Tag '' = the
% aggregate x_exp1, otherwise an equation copy x_exp1__<tag>, which replaces x{+1} in the equation
% labelled exactly <label> (scope entry 'x@<label>'; tag = initials of the label up to its first
% comma, 'Phillips curve, price setting' -> 'pc'). A transform acts on (x, L, k, tag) when its
% types are 'all' or name k and x is in its global scope ('learning', 'all', named variables;
% minus exclude) or (x, tag) is one of its equation entries; on (x, N, tag) when its types are
% 'all' or name RE and x is in its global scope other than 'learning', or (x, tag) is one of its
% equation entries. The transforms acting on a context apply in the order of the list. Factors
% are parameters tf<i>_* that hetlearn.load_model sets (identity values TF.meta.identity, used by
% the collapse test), so the file depends on the structure only (TF.key). Left out of a type's
% forecast and listed in TF.blocked (hetlearn.load_model refuses a run in which the variable
% learns): a diagnostic transform on a learned or rule type (its reference forecast is not built). A
% diagnostic on the RE type is written in both branches of the re_anchored switch: the
% model-consistent one with the chain reference, the anchored one with x_DEg_RE{-1} under t-1
% information (TF.deferred; refused by hetlearn.load_model under period-t information). Errors
% (hetlearn:extend_model:transforms): a diagnostic transform after another transform, a transform
% that acts on nothing, scope entries that are not forward-looking or whose equation is not found.
% Kinds: 'multiplier', 'diagnostic', 'myopia_anchoring' ('partial_adjustment' and 'wedge' were
% removed on 2026-10-22).
TF = struct('has', false, 'occ', B.occ);
X = B.transforms;
if isempty(X)
    return
end
ID = 'hetlearn:extend_model:transforms';
X = reshape(X, 1, []);
nX = numel(X);
fwd = B.fwd;
S = B.S;
code = B.code;
occ = B.occ;
file = B.spec.model_file;
tnames = {G.name};

% ---- equation label of every lead occurrence in the transition equations ---------------------
[masked, ~, labs] = mask_code(code);
if isempty(labs)
    labs = zeros(0, 2);
end
in2 = false(1, size(labs, 1));
for r = 1:size(labs, 1)
    in2(r) = S.sec(labs(r, 1)) == 2;
end
lab2 = labs(in2, :);
labText = cell(1, size(lab2, 1));
for r = 1:size(lab2, 1)
    labText{r} = code(lab2(r, 1) + 1:lab2(r, 2) - 1);
end
semis = find(masked == ';');
occLabel = repmat({''}, 1, numel(occ));
for q = 1:numel(occ)
    if isempty(occ(q).name) || occ(q).sec ~= 2
        continue
    end
    prev = semis(semis < occ(q).s);
    if isempty(prev)
        prev = 0;
    else
        prev = prev(end);
    end
    r = find(lab2(:, 1) > prev & lab2(:, 2) < occ(q).s, 1, 'last');
    if ~isempty(r)
        occLabel{q} = labText{r};
    end
end

% ---- per transform: types, global scope, equation copies ----------------------------------------
copies = struct('var', {}, 'label', {}, 'tag', {}, 'name', {});
T = struct('kind', {}, 'prefix', {}, 'typesAll', {}, 'types', {}, 'globL', {}, 'globN', {}, 'copy', {}, ...
    'desc', {});
parts = cell(1, nX);
for i = 1:nX
    x = X(i);
    t = struct('kind', char(x.kind), 'prefix', sprintf('tf%d', i), 'typesAll', true, 'types', {{}}, ...
        'globL', {{}}, 'globN', {{}}, 'copy', [], 'desc', '');
    if iscell(x.types)
        t.typesAll = false;
        t.types = reshape(cellstr(x.types), 1, []);
        bad = setdiff(t.types, tnames);
        if ~isempty(bad)
            error(ID, 'expectations.transforms(%d).types: %s not agent types of the run (%s).', i, ...
                strjoin(bad, ', '), strjoin(tnames, ', '));
        end
    end
    excl = {};
    if iscell(x.exclude)
        excl = reshape(cellstr(x.exclude), 1, []);
    end
    bad = setdiff(excl, fwd);
    if ~isempty(bad)
        error(ID, 'expectations.transforms(%d).exclude: %s not forward-looking in %s.', i, strjoin(bad, ', '), file);
    end
    sc = x.scope;
    if ischar(sc) && strcmp(sc, 'learning')
        t.globL = fwd(~ismember(fwd, excl));
        scTxt = 'learning';
    elseif ischar(sc) && strcmp(sc, 'all')
        t.globL = fwd(~ismember(fwd, excl));
        t.globN = t.globL;
        scTxt = 'all';
    else
        sc = reshape(cellstr(sc), 1, []);
        isEq = contains(sc, '@');
        plain = sc(~isEq);
        bad = setdiff(plain, fwd);
        if ~isempty(bad)
            error(ID, 'expectations.transforms(%d).scope: %s not forward-looking in %s (forward-looking: %s).', ...
                i, strjoin(bad, ', '), file, strjoin(fwd, ', '));
        end
        t.globL = fwd(ismember(fwd, plain) & ~ismember(fwd, excl));
        t.globN = t.globL;
        for e = sc(isEq)
            a = strfind(e{1}, '@');
            [copies, occ, c] = tf_copy(copies, occ, occLabel, labText, e{1}(1:a(1) - 1), e{1}(a(1) + 1:end), ...
                fwd, i, file);
            t.copy(end+1) = c;
        end
        scTxt = strjoin(sc, ',');
    end
    ty = 'all';
    if ~t.typesAll
        ty = strjoin(t.types, ',');
    end
    ex = '';
    if ~isempty(excl)
        ex = [' minus ' strjoin(excl, ',')];
    end
    t.desc = sprintf('tf%d %s (types %s, scope %s%s)', i, t.kind, ty, scTxt, ex);
    % the key keeps its 2026-10-21 form (an empty 'shock=' entry, a field of the removed wedges), so the
    % generated files of the kept variants keep their names
    parts{i} = sprintf('%d:%s[types=%s;scope=%s;exclude=%s;shock=]', i, t.kind, ty, scTxt, strjoin(excl, ','));
    T(i) = t;
end

% ---- contexts: validation, parameters, generated variables -------------------------------------
P = struct('name', {}, 'i', {}, 'role', {}, 'type', {}, 'var', {}, 'identity', {}, 'label', {});
need = struct('cur', {{}}, 'lag3', {{}}, 'mc', {{}});
deferred = struct('var', {}, 'type', {}, 'i', {});
blocked = struct('var', {}, 'type', {}, 'i', {}, 'kind', {}, 'reason', {});
used = false(1, nX);
for ix = 1:numel(fwd)
    x = fwd{ix};
    tags = [{''}, {copies(strcmp({copies.var}, x)).tag}];
    for c = 1:numel(tags)
        for j = byx.(x)
            ch = tf_chain(T, copies, x, 'L', G(j).name, tags{c});
            [P, need, deferred, used, blocked] = tf_context(T, ch, x, 'L', G(j), tags{c}, P, need, ...
                deferred, used, blocked);
        end
        ch = tf_chain(T, copies, x, 'N', '', tags{c});
        [P, need, deferred, used, blocked] = tf_context(T, ch, x, 'N', [], tags{c}, P, need, deferred, ...
            used, blocked);
    end
end
if ~all(used)
    i = find(~used, 1);
    error(ID, 'expectations.transforms(%d) (%s) acts on no expectation of %s: check its types and scope.', i, ...
        T(i).kind, file);
end

% ---- outputs ------------------------------------------------------------------------------------
chainNames = {};
xc = reshape(unique([need.mc, need.cur], 'stable'), 1, []);
for q = 1:numel(xc)
    chainNames = [chainNames, {[xc{q} '_REt1'], [xc{q} '_REt2']}]; %#ok<AGROW>
end
for q = 1:numel(need.lag3)
    chainNames{end+1} = [need.lag3{q} '_REt3']; %#ok<AGROW>
end
chainNames = unique(chainNames, 'stable');
identity = struct();
for q = 1:numel(P)
    identity.(P(q).name) = P(q).identity;
end
TF.has = true;
TF.occ = occ;
TF.list = T;
TF.copies = copies;
TF.params = P;
TF.need = need;
TF.deferred = deferred;
TF.blocked = blocked;
TF.chain_names = chainNames;
TF.learn_chain = {};
TF.lag3_wrap = struct();
TF.gen_names = [{copies.name}, {P.name}, chainNames];
TF.key = strjoin(parts, '|');
TF.desc = {T.desc};
TF.meta = struct('n', nX, 'kinds', {{T.kind}}, 'list', T, 'copies', copies, 'params', P, 'identity', identity, ...
    'need', need, 'deferred', deferred, 'blocked', blocked, 'chain_names', {chainNames}, 'learn_chain', {{}}, ...
    'key', TF.key);
end


function ch = tf_unblocked(TF, ch, x, k)
% the transforms of a learning-branch context without those left out for the type (TF.blocked)
if isempty(TF.blocked) || isempty(ch)
    return
end
b = TF.blocked(strcmp({TF.blocked.var}, x) & strcmp({TF.blocked.type}, k));
ch = ch(~ismember(ch, [b.i]));
end


function [copies, occ, c] = tf_copy(copies, occ, occLabel, labText, x, lab, fwd, i, file)
% the equation copy of x for the transition equation labelled lab (created once)
ID = 'hetlearn:extend_model:transforms';
if ~any(strcmp(fwd, x))
    error(ID, 'expectations.transforms(%d).scope ''%s@%s'': %s is not forward-looking in %s.', i, x, lab, x, file);
end
c = [];
if ~isempty(copies)
    c = find(strcmp({copies.var}, x) & strcmp({copies.label}, lab), 1);
end
if ~isempty(c)
    return
end
nl = sum(strcmp(labText, lab));
if nl == 0
    error(ID, ['expectations.transforms(%d).scope ''%s@%s'': no transition equation is labelled ''%s'' in %s ' ...
        '(the label must match exactly).'], i, x, lab, lab, file);
elseif nl > 1
    error(ID, 'expectations.transforms(%d).scope ''%s@%s'': %d transition equations carry this label in %s.', ...
        i, x, lab, nl, file);
end
hit = find(strcmp({occ.name}, x) & strcmp(occLabel, lab));
k = [occ(hit).k];
if any(k >= 2)
    error(ID, ['expectations.transforms(%d).scope ''%s@%s'': the equation has a lead of %s longer than 1 ' ...
        '(equation copies transform x{+1} only).'], i, x, lab, x);
end
hit = hit(k == 1);
if isempty(hit)
    error(ID, ['expectations.transforms(%d).scope ''%s@%s'': the equation ''%s'' has no %s{+1} of its own (leads ' ...
        'inside !substitutions are not copied).'], i, x, lab, lab, x);
end
usedTags = {};
if ~isempty(copies)
    usedTags = {copies(strcmp({copies.var}, x)).tag};
end
tag = label_tag(lab, usedTags);
name = [x '_exp1__' tag];
for q = hit
    occ(q).ext = name;
end
copies(end+1) = struct('var', x, 'label', lab, 'tag', tag, 'name', name);
c = numel(copies);
end


function t = label_tag(label, used)
% initials of the words of the label up to its first comma, lower case ('Phillips curve, price setting' -> 'pc')
head = strtok(label, ',');
w = regexp(lower(head), '[a-z0-9]+', 'match');
t = strjoin(cellfun(@(s) s(1), w, 'UniformOutput', false), '');
if isempty(t)
    t = 'eq';
end
if ~isletter(t(1))
    t = ['e' t];
end
base = t;
n = 1;
while any(strcmp(used, t))
    n = n + 1;
    t = sprintf('%s%d', base, n);
end
end


function ch = tf_chain(T, copies, x, br, k, tag)
% indices of the transforms acting on the context (x, br, type k, tag), in list order
ch = [];
isL = strcmp(br, 'L');
for i = 1:numel(T)
    t = T(i);
    if isL
        okT = t.typesAll || any(strcmp(t.types, k));
        okG = any(strcmp(t.globL, x));
    else
        okT = t.typesAll || any(strcmp(t.types, 'RE'));
        okG = any(strcmp(t.globN, x));
    end
    okC = false;
    if ~isempty(tag) && ~isempty(t.copy)
        okC = any(strcmp({copies(t.copy).var}, x) & strcmp({copies(t.copy).tag}, tag));
    end
    if okT && (okG || okC)
        ch(end+1) = i; %#ok<AGROW>
    end
end
end


function [P, need, deferred, used, blocked] = tf_context(T, ch, x, br, g, tag, P, need, deferred, used, blocked)
% checks of one context; its parameters and reference chains. A diagnostic transform on a learned
% or rule type (its reference forecast is not built) is left out of that type's forecast and listed
% in blocked: hetlearn.load_model refuses the run when the variable learns
ID = 'hetlearn:extend_model:transforms';
isL = strcmp(br, 'L');
where = sprintf('the model-consistent expectation of %s{+1}', x);
if isL
    where = sprintf('the forecast of %s{+1} of type %s', x, g.name);
end
if ~isempty(tag)
    where = sprintf('%s (equation copy %s_exp1__%s)', where, x, tag);
end
keep = true(1, numel(ch));
for q = 1:numel(ch)
    i = ch(q);
    used(i) = true;
    if ~isL
        continue
    end
    why = '';
    if strcmp(T(i).kind, 'diagnostic') && ~strcmp(g.kind, 're')
        why = ['the reference forecast of learned and rule types is not built (phase P3 builds the ' ...
            'model-consistent references)'];
    end
    if ~isempty(why)
        keep(q) = false;
        if isempty(blocked) || ~any(strcmp({blocked.var}, x) & strcmp({blocked.type}, g.name) & [blocked.i] == i)
            blocked(end+1) = struct('var', x, 'type', g.name, 'i', i, 'kind', T(i).kind, 'reason', why); %#ok<AGROW>
        end
    end
end
ch = ch(keep);
for q = 1:numel(ch)
    i = ch(q);
    t = T(i);
    p = t.prefix;
    switch t.kind
        case 'multiplier'
            if isL
                P = tf_param(P, [p '_D__' g.name], i, 'D', g.name, '', 1, ...
                    sprintf('Forecast transform %d (multiplier): factor D(h) on the forecasts of type %s', i, g.name));
            else
                P = tf_param(P, [p '_d1'], i, 'D', '', '', 1, ...
                    sprintf('Forecast transform %d (multiplier): factor D(1) on the model-consistent expectations', i));
            end
        case 'diagnostic'
            if q > 1
                error(ID, ['expectations.transforms(%d) (diagnostic) acts on %s after transform %d: a diagnostic ' ...
                    'transform must come first for each expectation (move it up the list).'], i, where, ch(1));
            end
            if isL
                if strcmp(g.info, 'current')
                    need.cur = reshape(union(need.cur, {x}, 'stable'), 1, []);
                else
                    need.lag3 = reshape(union(need.lag3, {x}, 'stable'), 1, []);
                end
                if isempty(g.variant) && ~any(strcmp({deferred.var}, x) & strcmp({deferred.type}, g.name) & [deferred.i] == i)
                    deferred(end+1) = struct('var', x, 'type', g.name, 'i', i); %#ok<AGROW>
                end
            else
                need.mc = reshape(union(need.mc, {x}, 'stable'), 1, []);
            end
            P = tf_param(P, [p '_theta'], i, 'theta', '', '', 0, sprintf('Forecast transform %d (diagnostic): theta', i));
        case 'myopia_anchoring'
            P = tf_param(P, [p '_omega'], i, 'omega', '', '', 1, ...
                sprintf('Forecast transform %d (myopia and anchoring): weight omega_f on the forecast', i));
            P = tf_param(P, [p '_b'], i, 'b', '', '', 0, ...
                sprintf('Forecast transform %d (myopia and anchoring): weight b on the variable at t-1', i));
    end
end
end


function P = tf_param(P, name, i, role, type, var, identity, label)
if ~isempty(P) && any(strcmp({P.name}, name))
    return
end
P(end+1) = struct('name', name, 'i', i, 'role', role, 'type', type, 'var', var, 'identity', identity, 'label', label);
end


function r = tf_de_ref(x, br, g)
% the reference of a diagnostic transform: the same forecast made one period earlier, model-consistent
if strcmp(br, 'L') && strcmp(g.info, 'lagged')
    r = [x '_REt3{-2}'];          % E_{t-2} x_{t+1}: one more chain element than the t-1 dated forecast x_REt2{-1}
else
    r = [x '_REt2{-1}'];          % E_{t-1} x_{t+1} (the LSY chain)
end
end


function s = tf_wrap(e)
if isempty(regexp(e, '^[A-Za-z]\w*(\{[+-]?\d+\})?$', 'once'))
    s = ['(' e ')'];
else
    s = e;
end
end


function e = tf_expr(TF, ch, base, x, br, g, ref)
% the transformed expectation: base through the transforms ch; ref (optional) replaces the diagnostic
% reference (the anchored x_DEg_RE{-1}, phase P4)
if nargin < 7
    ref = '';
end
e = base;
for q = 1:numel(ch)
    i = ch(q);
    t = TF.list(i);
    p = t.prefix;
    switch t.kind
        case 'multiplier'
            if strcmp(br, 'L')
                e = sprintf('%s_D__%s*%s', p, g.name, tf_wrap(e));
            else
                e = sprintf('%s_d1*%s', p, tf_wrap(e));
            end
        case 'myopia_anchoring'
            e = sprintf('%s_omega*%s + %s_b*%s{-1}', p, tf_wrap(e), p, x);
        case 'diagnostic'
            r = ref;
            if isempty(r)
                r = tf_de_ref(x, br, g);
            end
            e = sprintf('(1 + %s_theta)*%s - %s_theta*%s', p, tf_wrap(e), p, r);
    end
end
end


function [TF, chainMode] = tf_chains(TF, reChain, chainMode, anchor)
% chains of the diagnostic references in the learning branch, given the lagged RE chains: a
% model-consistent type with period-t information needs x_REt1, x_REt2 whatever re_anchored is (the
% lagged RE chain then stays in the text in both branches, or the learning branch gets its own);
% a lagged model-consistent type needs x_REt3, written beside the lagged RE chain
for q = 1:numel(TF.need.cur)
    x = TF.need.cur{q};
    if isfield(reChain, x)
        if strcmp(chainMode.(x), 'toggle')
            chainMode.(x) = 'always';
        end
    else
        TF.learn_chain{end+1} = x;
    end
end
for q = 1:numel(TF.need.lag3)
    x = TF.need.lag3{q};
    if ~isfield(reChain, x)
        error('hetlearn:extend_model:transforms', 'Internal: no lagged RE chain for the diagnostic reference of %s.', x);
    end
    TF.lag3_wrap.(x) = strcmp(chainMode.(x), 'toggle') && anchor.ok;
end
TF.meta.learn_chain = TF.learn_chain;
end


function L = tf_decl_copies(TF, x)
L = {};
if isempty(TF.copies)
    return
end
c = TF.copies(strcmp({TF.copies.var}, x));
for q = 1:numel(c)
    L{end+1} = sprintf('    "Expectation of %s{+1} in the equation: %s" %s', x, strrep(c(q).label, '"', ''''), ...
        c(q).name); %#ok<AGROW>
end
end


function L = tf_decl_branches(TF, x, anchor)
% declarations of the learning branch (inside !if br_x) and of the model-consistent branch (!else)
L = {};
if any(strcmp(TF.learn_chain, x))
    L{end+1} = sprintf('        "Model-consistent chain of the diagnostic reference: E_t %s{+1}" %s_REt1', x, x);
    L{end+1} = sprintf('        "Model-consistent chain of the diagnostic reference: E_t %s{+2}" %s_REt2', x, x);
end
if any(strcmp(TF.need.lag3, x))
    wrap = TF.lag3_wrap.(x);
    if wrap
        L{end+1} = sprintf('        !if ~%s', anchor.toggle);
    end
    L{end+1} = sprintf('        "Lagged RE chain: E_t %s{+3}, diagnostic reference" %s_REt3', x, x);
    if wrap
        L{end+1} = '        !end';
    end
end
M = {};
if any(strcmp(TF.need.mc, x))
    M{end+1} = sprintf('        "Model-consistent chain of the diagnostic reference: E_t %s{+1}" %s_REt1', x, x);
    M{end+1} = sprintf('        "Model-consistent chain of the diagnostic reference: E_t %s{+2}" %s_REt2', x, x);
end
if ~isempty(M)
    L{end+1} = '    !else';
    L = [L, M];
end
end


function L = tf_decl_params(TF)
L = arrayfun(@(p) sprintf('    "%s" %s', p.label, p.name), TF.params, 'UniformOutput', false);
L = reshape(L, 1, []);
end


function L = tf_learn_lines(TF, G, x, ix, toggle)
% x_exp1 and its equation copies in the learning branch. When a diagnostic transform acts on the RE
% type (which follows the re_anchored switch), the lines are written twice: the anchored version uses
% the anchored reference x_DEg_RE{-1} under t-1 information (period-t information: the transform is
% left out there and hetlearn.load_model refuses to load it), the model-consistent version the chain
% reference.
split = ~isempty(TF.deferred) && any(strcmp({TF.deferred.var}, x));
if ~split
    L = tf_learn_set(TF, G, x, ix, false, '        ');
    return
end
L = {sprintf('        !if %s', toggle)};
L = [L, tf_learn_set(TF, G, x, ix, true, '            ')];
L{end+1} = '        !else';
L = [L, tf_learn_set(TF, G, x, ix, false, '            ')];
L{end+1} = '        !end';
end


function L = tf_learn_set(TF, G, x, ix, anchoredVersion, ind)
L = {};
cp = TF.copies;
if ~isempty(cp)
    cp = cp(strcmp({cp.var}, x));
end
tags = [{''}, {cp.tag}];
for c = 1:numel(tags)
    terms = cell(1, numel(ix));
    for jj = 1:numel(ix)
        g = G(ix(jj));
        ch = tf_unblocked(TF, tf_chain(TF.list, TF.copies, x, 'L', g.name, tags{c}), x, g.name);
        ref = '';
        if anchoredVersion && strcmp(g.kind, 're') && isempty(g.variant) && ~isempty(ch)
            if strcmp(g.info, 'lagged') && isfield(TF, 'deg_vars') && any(strcmp(TF.deg_vars, x))
                ref = [x '_DEg_RE{-1}'];      % the anchored reference E_{t-2} x_{t+1} (phase P4)
            else
                ch = ch(~strcmp({TF.list(ch).kind}, 'diagnostic'));     % period-t information: refused by load_model
            end
        end
        e = tf_expr(TF, ch, sprintf('%s_exp1_%s', x, g.name), x, 'L', g, ref);
        terms{jj} = sprintf('n_%s_%s*%s', g.name, x, tf_wrap(e));
    end
    lhs = [x '_exp1'];
    if c > 1
        lhs = cp(c - 1).name;
    end
    L{end+1} = sprintf('%s%s = %s;', ind, lhs, strjoin(terms, ' + ')); %#ok<AGROW>
end
end


function L = tf_learn_chain_lines(TF, x, anchor)
% equations of the reference chains of the learning branch (after the lagged RE chain)
L = {};
if any(strcmp(TF.learn_chain, x))
    L{end+1} = sprintf('        %s_REt2 = %s_REt1{+1};', x, x);
    L{end+1} = sprintf('        %s_REt1 = %s{+1};', x, x);
end
if any(strcmp(TF.need.lag3, x))
    if TF.lag3_wrap.(x)
        L{end+1} = sprintf('        !if ~%s', anchor.toggle);
        L{end+1} = sprintf('            %s_REt3 = %s_REt2{+1};', x, x);
        L{end+1} = '        !end';
    else
        L{end+1} = sprintf('        %s_REt3 = %s_REt2{+1};', x, x);
    end
end
end


function L = tf_mc_lines(TF, x)
% the model-consistent branch (br_x false): x_exp1 = T(x{+1}), its equation copies and the reference
% chain of a diagnostic transform
L = {};
cp = TF.copies;
if ~isempty(cp)
    cp = cp(strcmp({cp.var}, x));
end
tags = [{''}, {cp.tag}];
for c = 1:numel(tags)
    ch = tf_chain(TF.list, TF.copies, x, 'N', '', tags{c});
    e = tf_expr(TF, ch, [x '{+1}'], x, 'N', []);
    lhs = [x '_exp1'];
    if c > 1
        lhs = cp(c - 1).name;
    end
    L{end+1} = sprintf('        %s = %s;', lhs, e); %#ok<AGROW>
end
if any(strcmp(TF.need.mc, x))
    L{end+1} = sprintf('        %s_REt2 = %s_REt1{+1};', x, x);
    L{end+1} = sprintf('        %s_REt1 = %s{+1};', x, x);
end
end

