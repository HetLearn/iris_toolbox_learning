function R = test_generator()
%TEST_GENERATOR  Extended-model generator (hetlearn.extend_model) on the toy NK model.
%
%   R = test_generator()   returns a struct array of checks (name, pass, msg).

R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
toyDir = fullfile(here, 'toy_nk');
spec = load_spec(toyDir);
P = feval_in(toyDir, spec.params);
srcFile = fullfile(toyDir, spec.model_file);

% ---- generate (forced) with the collapse test ------------------------------
name = 'gen: extend_model(ar1) generates and passes the collapse test';
try
    meta = hetlearn.extend_model(spec, 'ar1', 'force', true);
    ok = meta.validated && all(meta.collapse_maxdiff < 1e-10);
    R = add(R, name, ok, sprintf('max IRF diff br=true %.1e, br=false %.1e', meta.collapse_maxdiff));
catch err
    R = add(R, name, false, err.message);
    return
end
gen = fileread(meta.ext_file);
src = fileread(srcFile);
lines = strtrim(strsplit(gen, newline));
cut = strfind(gen, '% hetlearn expectation block');
body = gen(1:cut(1) - 1);
stripped = regexprep(body, '%\{.*?%\}', '');           % body without comments/labels
stripped = regexprep(stripped, '%[^\n]*', '');
stripped = regexprep(stripped, '"[^"\n]*"|''[^''\n]*''', '');

R = add(R, 'gen: collapse test passes with every br_x = true (n1=1, n2=0, beliefs 0)', ...
    meta.collapse_maxdiff(1) < 1e-10, sprintf('%.2e', meta.collapse_maxdiff(1)));
R = add(R, 'gen: collapse test passes with every br_x = false', ...
    meta.collapse_maxdiff(2) < 1e-10, sprintf('%.2e', meta.collapse_maxdiff(2)));

ok = isequal(meta.forward_vars, {'y', 'pie', 'r'}) && meta.max_lead.y == 1 ...
    && meta.max_lead.pie == 2 && meta.max_lead.r == 1;
R = add(R, 'gen: forward variables y, pie, r with max leads 1, 2, 1', ok, strjoin(meta.forward_vars, ', '));

ok = strcmp(meta.plmtag, 'ar1') && endsWith(meta.ext_file, fullfile('generated', 'nk3_ext_ar1.model')) ...
    && exist(fullfile(toyDir, 'generated', 'nk3_ext_ar1_meta.mat'), 'file') == 2 ...
    && isequal(meta.toggles, {'br_y', 'br_pie', 'br_r'});
R = add(R, 'gen: file names, plmtag ar1, toggles br_<x>', ok, meta.ext_file);

% ---- generated file parses in IRIS -----------------------------------------
for tog = [true false]
    nm = sprintf('gen: generated file parses and solves in IRIS (all br = %d)', tog);
    try
        a = struct('br_y', tog, 'br_pie', tog, 'br_r', tog);
        m = Model.fromFile(meta.ext_file, 'linear', true, 'assign', a);
        m = put_params(m, P);
        m = put_neutral(m, meta);
        [~, flag] = solve(m);
        xl = get(m, 'xList');
        ok = hasSucceeded(flag) && any(strcmp(xl, 'pie_exp2')) ...
            && tog == any(strcmp(xl, 'pie_exp1_BR'));
        R = add(R, nm, ok, sprintf('%d transition variables', numel(xl)));
    catch err
        R = add(R, nm, false, err.message);
    end
end

% ---- exact BR lines ------------------------------------------------------------
want = {'y_exp1_BR = alpha_y + beta_y*(alpha_y + beta_y*y{-1});', ...
    'pie_exp1_BR = alpha_pie + beta_pie*(alpha_pie + beta_pie*pie{-1});', ...
    'r_exp1_BR = alpha_r + beta_r*(alpha_r + beta_r*r{-1});'};
ok = all(ismember(want, lines));
R = add(R, 'gen: AR(1) BR lines read exactly x_exp1_BR = alpha_x + beta_x*(alpha_x + beta_x*x{-1});', ok, want{2});

ok = any(strcmp(lines, 'pie_exp2 = pie_exp1{+1};')) && contains(body, 'c2*pie_exp2') ...
    && contains(body, '(bet/(1+bet*iota) - c2)*pie_exp1 +') && ~contains(gen, 'y_exp2') ...
    && ~contains(stripped, 'pie{+2}') && contains(body, 'NKPC with pie[+1] and pie{+2}') ...
    && any(strcmp(lines, 'pie_exp1_RE = pie{+1};')) ...
    && any(strcmp(lines, 'pie_exp1 = n1_pie*pie_exp1_RE + n2_pie*pie_exp1_BR;')) ...
    && any(strcmp(lines, 'pie_exp1 = pie{+1};'));
R = add(R, 'gen: pie{+2} became pie_exp2 with pie_exp2 = pie_exp1{+1} chain', ok, '');

% ---- every notation rewritten ----------------------------------------------------
need = {'1/(1+h)*y_exp1 + h/(1+h)*y{-1}', 'rr := (r - pie_exp1);', 'dy_e = y_exp1 - y;', ...
    'r_e = r_exp1;', 'r = rho_r*r{-1} +', 'phi_dy*(y - y{-1})', 'iota/(1+bet*iota)*pie{-1}'};
miss = need(~cellfun(@(s) contains(body, s), need));
R = add(R, 'gen: notations y{+1}, pie{1}, pie[+1], y(+1), r{t+1} and lags normalised', ...
    isempty(miss), strjoin(miss, ' | '));

left = regexp(stripped, '\{\s*\+|\[|\(\s*[+-]?\s*\d+\s*\)|\{\s*t|\{\s*\d', 'match');
R = add(R, 'gen: no lead or non-IRIS subscript left outside comments/labels', isempty(left), strjoin(left, ' '));

% ---- comments and labels unchanged ---------------------------------------------
pieces = [regexp(src, '%\{.*?%\}', 'match'), regexp(src, '%[^\n]*', 'match'), ...
    regexp(src, '"[^"\n]*"', 'match'), regexp(src, '''[^''\n]*''', 'match')];
blk = regexp(src, '/\*(.*?)\*/', 'tokens');
pieces = [pieces, cellfun(@(t) ['%{' t{1} '%}'], blk, 'UniformOutput', false)];
sl = regexp(src, '//([^\n]*)', 'tokens');
pieces = [pieces, cellfun(@(t) ['%%' t{1}], sl, 'UniformOutput', false)];
missing = pieces(~cellfun(@(s) contains(gen, s), pieces));
R = add(R, sprintf('gen: %d comments/labels unchanged (// and /* */ delimiters -> %%%% and %%{ %%})', numel(pieces)), ...
    isempty(missing), strjoin(missing, ' | '));
ok = contains(gen, sprintf('!measurement_equations\n    obs_y = y;\n    obs_pie = pie;\n    obs_r = r;'));
R = add(R, 'gen: measurement equations untouched', ok, '');

% ---- cache ------------------------------------------------------------------------
try
    t1 = dir(meta.ext_file);
    meta2 = hetlearn.extend_model(spec, 'ar1');
    t2 = dir(meta.ext_file);
    ok = strcmp(meta2.created, meta.created) && t1.datenum == t2.datenum;
    R = add(R, 'gen: unchanged source + PLM is not regenerated', ok, meta2.created);
catch err
    R = add(R, 'gen: unchanged source + PLM is not regenerated', false, err.message);
end

% ---- error cases and preparser on small temporary models ---------------------------
tmp = fullfile(tempdir, 'hetlearn_test_models');
if exist(tmp, 'dir') ~= 7
    mkdir(tmp);
end
write_file(fullfile(tmp, 'hl_tmp_params.m'), sprintf([ ...
    'function p = hl_tmp_params()\n', ...
    'p = struct(''a'', 0.5, ''rho'', 0.5, ''std_e'', 1, ''alpha_x'', 0.1);\n', 'end\n']));
base = sprintf(['!transition_variables\n    x, z\n!transition_shocks\n    e\n', ...
    '!parameters\n    a, rho\n!transition_equations\n']);
cases = {
    'pseudo1', [base '    x = a*x{+1} + 0.1*diff(z{+1}) + z;\n    z = rho*z{-1} + e;\n'], 'pseudoLead', ...
        'gen: diff() containing a lead is rejected, naming the equation'
    'pseudo2', [base '    x = a*x{+1} + 0.1*movavg(z, +2) + z;\n    z = rho*z{-1} + e;\n'], 'pseudoLead', ...
        'gen: movavg() with a forward window is rejected'
    'collide', [strrep(base, 'a, rho', 'a, rho, alpha_x') '    x = a*x{+1} + alpha_x*z;\n    z = rho*z{-1} + e;\n'], ...
        'nameCollision', 'gen: generated name colliding with a declared name is an error'
    };
for i = 1:size(cases, 1)
    write_file(fullfile(tmp, [cases{i, 1} '.model']), sprintf(cases{i, 2}));
    sp = struct('name', cases{i, 1}, 'folder', tmp, 'model_file', [cases{i, 1} '.model'], ...
        'linear', true, 'assign', struct(), 'params', 'hl_tmp_params');
    try
        hetlearn.extend_model(sp, 'ar1', 'force', true);
        R = add(R, cases{i, 4}, false, 'no error raised');
    catch err
        ok = contains(err.identifier, cases{i, 3});
        if i == 1
            ok = ok && contains(err.message, 'diff(z{+1})');
        end
        R = add(R, cases{i, 4}, ok, err.message);
    end
end

declModel = sprintf(['!transition_variables\n', ...
    '    "Label with x{+1}; and w(+1)" x = 0.5 z\n    ''w label'' w, v\n', ...
    '!transition_shocks\n    e\n!parameters\n    a = 0.5, rho\n!transition_equations\n', ...
    '    x = a*x{+1} + z;\n    z = rho*z{-1} + e;\n    w = 0.5*w (+1) + 0.1*x !! w = 0;\n', ...
    '    v = 0.5*v{-1} + w;\n']);
write_file(fullfile(tmp, 'decl.model'), declModel);
sp = struct('name', 'decl', 'folder', tmp, 'model_file', 'decl.model', ...
    'linear', true, 'assign', struct(), 'params', 'hl_tmp_params');
try
    md = hetlearn.extend_model(sp, 'ar1', 'force', true, 'validate', false);
    txt = fileread(md.ext_file);
    ok = isequal(md.forward_vars, {'x', 'w'}) && contains(txt, 'w = 0.5*w_exp1 + 0.1*x !! w = 0;') ...
        && contains(txt, '"Label with x{+1}; and w(+1)" x = 0.5 z');
    R = add(R, 'gen: declarations with spaces, commas, labels and = values; !! part kept', ok, ...
        strjoin(md.forward_vars, ', '));
catch err
    R = add(R, 'gen: declarations with spaces, commas, labels and = values; !! part kept', false, err.message);
end

forModel = sprintf(['%% model written with !for\n!transition_variables\n', ...
    '    !for ?v = x, z !do\n        "Variable ?v" ?v\n    !end\n', ...
    '!transition_shocks\n    e\n!parameters\n    a, rho\n!transition_equations\n', ...
    '    x = a*x{+1} + z;\n    z = rho*z{-1} + e;\n']);
write_file(fullfile(tmp, 'forloop.model'), forModel);
sp = struct('name', 'forloop', 'folder', tmp, 'model_file', 'forloop.model', ...
    'linear', true, 'assign', struct(), 'params', 'hl_tmp_params');
try
    mf = hetlearn.extend_model(sp, 'ar1', 'force', true);
    ok = mf.preparsed && mf.validated && isequal(mf.forward_vars, {'x'});
    R = add(R, 'gen: !for is expanded with the IRIS preparser; collapse test passes', ok, ...
        sprintf('max diff %.1e', max(mf.collapse_maxdiff)));
catch err
    R = add(R, 'gen: !for is expanded with the IRIS preparser; collapse test passes', false, err.message);
end

% ---- review m6: leads are detected on the !if branches that spec.assign selects --------
ifModel = sprintf(['!transition_variables\n    x, z, w\n!transition_shocks\n    e\n', ...
    '!parameters\n    a, rho\n!transition_equations\n    x = a*x{+1} + z;\n', ...
    '    !if flagx\n        w = 0.5*w{+1} + 0.1*x{+2};\n    !else\n        w = 0.5*w{-1} + 0.1*x;\n    !end\n', ...
    '    z = rho*z{-1} + e;\n']);
write_file(fullfile(tmp, 'ifmodel.model'), ifModel);
sp = struct('name', 'ifmodel', 'folder', tmp, 'model_file', 'ifmodel.model', ...
    'linear', true, 'assign', struct('flagx', false), 'params', 'hl_tmp_params');
nm = 'gen m6: lead only inside !if flagx (flagx = false): w not forward, x max lead 1, !if kept, collapse passes';
try
    m0 = hetlearn.extend_model(sp, 'ar1', 'force', true);
    txt = fileread(m0.ext_file);
    ok = isequal(m0.forward_vars, {'x'}) && m0.max_lead.x == 1 && isequal(m0.toggles, {'br_x'}) ...
        && contains(txt, '!if flagx') && contains(txt, 'w = 0.5*w{+1} + 0.1*x_exp2;') ...
        && ~contains(txt, 'w_exp1') && m0.validated && all(m0.collapse_maxdiff(1:2) < 1e-10);
    R = add(R, nm, ok, sprintf('fwd {%s}, max lead x %d, collapse %s', strjoin(m0.forward_vars, ','), ...
        m0.max_lead.x, mat2str(m0.collapse_maxdiff, 2)));
catch err
    R = add(R, nm, false, err.message);
end
nm = 'gen m6: flagx = true without force regenerates (assign in the cache key): w forward, x max lead 2';
try
    sp.assign.flagx = true;
    m1 = hetlearn.extend_model(sp, 'ar1');
    sp.assign.flagx = false;
    m2 = hetlearn.extend_model(sp, 'ar1');
    ok = isequal(m1.forward_vars, {'x', 'w'}) && m1.max_lead.x == 2 && m1.validated ...
        && all(m1.collapse_maxdiff(1:2) < 1e-10) && isequal(m2.forward_vars, {'x'}) ...
        && ~strcmp(m1.assign_key, m2.assign_key);
    R = add(R, nm, ok, sprintf('flagx=1: fwd {%s}, max lead x %d; flagx=0 again: fwd {%s}', ...
        strjoin(m1.forward_vars, ','), m1.max_lead.x, strjoin(m2.forward_vars, ',')));
catch err
    R = add(R, nm, false, err.message);
end
end


% =========================================================================
function m = put_params(m, P)
names = fieldnames(get(m, 'parameters'));
f = fieldnames(P);
for i = 1:numel(f)
    if any(strcmp(names, f{i}))
        m.(f{i}) = P.(f{i});
    end
end
end


function m = put_neutral(m, meta)
for i = 1:numel(meta.forward_vars)
    x = meta.forward_vars{i};
    m.(['n1_' x]) = 1;
    m.(['n2_' x]) = 0;
end
f = fieldnames(meta.belief_params);
for i = 1:numel(f)
    p = meta.belief_params.(f{i});
    for j = 1:numel(p)
        m.(p{j}) = 0;
    end
end
end


function spec = load_spec(folder)
old = cd(folder);
c = onCleanup(@() cd(old));
spec = model_spec();
end


function P = feval_in(folder, fname)
old = cd(folder);
c = onCleanup(@() cd(old));
P = feval(fname);
end


function write_file(f, txt)
fid = fopen(f, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
