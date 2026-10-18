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
ANCHOR_TOGGLE = 're_anchored';
INFO_TOGGLE = 'br_info_current';   % global !if switch of the BR information set (beliefs.info, DESIGN 4.2)
POLICY_TOGGLE = 'ramsey';  % global !if switch of the Ramsey wrap (DESIGN 13)

ip = inputParser;
ip.addParameter('force', false);
ip.addParameter('validate', true);
ip.parse(varargin{:});
force = logical(ip.Results.force);
doValidate = logical(ip.Results.validate);

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

% ---- names and collisions --------------------------------------------------
gen = {};
expVars = struct();
shareParams = struct();
beliefParams = struct();
toggles = cell(1, numel(fwd));
for i = 1:numel(fwd)
    x = fwd{i};
    agg = arrayfun(@(k) sprintf('%s_exp%d', x, k), 1:maxLead.(x), 'UniformOutput', false);
    expVars.(x) = struct('agg', {agg}, 're', [x '_exp1_RE'], 'br', [x '_exp1_BR']);
    shareParams.(x) = {['n1_' x], ['n2_' x]};
    toggles{i} = ['br_' x];
    gen = [gen, agg, {[x '_exp1_RE'], [x '_exp1_BR']}, shareParams.(x), toggles(i)]; %#ok<AGROW>
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
extFile = fullfile(genDir, sprintf('%s_ext_%s.model', spec.name, plmtag));
metaFile = fullfile(genDir, sprintf('%s_ext_%s_meta.mat', spec.name, plmtag));
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
            [meta.collapse_maxdiff, meta.collapse_info_maxdiff] = collapse_test(spec, assign, meta);
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

block = make_block(fwd, maxLead, sys, plmtag, spec, S, derived, anchor, INFO_TOGGLE);
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

if exist(metaFile, 'file') == 2
    delete(metaFile);
end
if doValidate
    [meta.collapse_maxdiff, meta.collapse_info_maxdiff] = collapse_test(spec, assign, meta);
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
