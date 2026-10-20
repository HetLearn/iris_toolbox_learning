function R = test_br_regression()
%TEST_BR_REGRESSION  Regression gate of the bounded-rationality extensions (docs/DESIGN_br_extensions.md 1.7).
%
%   R = test_br_regression()   returns a struct array of checks (name, pass, msg).
%
%   References: tests/reference/br_freeze.mat, frozen by tests/scenarios/make_br_freeze.m from the
%   code of 2026-10-20 before phase P1 (phase P0). Every later phase reruns this suite, and
%   everything is compared exactly (max diff 0): run it at the default thread count
%   (maxNumCompThreads changes the results at about 1e-12). About 2 minutes.
%
%   R1   the default and _relag generated files of SW07 and of the toy models nk3 and nk3l1, and
%        the normalised toy sources, are byte-identical (MD5) to the frozen ones (br_generate
%        writes them in a temporary copy of each package; the model caches are not touched)
%   R2   the frozen runs, re-run from their stored partial option trees, equal the frozen results
%        exactly: paths (every variable over the full range), learning records (every frozen
%        series and field), events, final learning state, dates, policy loss, history mode,
%        model and RE filter hashes, and every frozen merged option keeps its value. Options and
%        output fields added after the freeze are listed in the message, not failed (new options
%        must default to off, so the runs cannot move). Groups:
%        R2a tsw07_peak_re; R2b tsw07_switch_pinf, engine.step 'fast' (also equal to
%        tests/reference/tsw07_switch_pinf_fast.mat); R2c the same with 'iris' (also equal to
%        tsw07_switch_pinf_iris.mat); R2d the 2026-10-20 baseline a1_re and a1_learn (test
%        copies tsw07_a1_re, tsw07_a1_learn), 'fast' and 'iris'; R2e-R2g the 2019Q4 IRF runs of
%        DESIGN_br_extensions sec. 4: RE(t-1) and baseline without a shock and with +1 sd of
%        each SW07 shock in 2020Q1, and the baseline with -1 sd.
%   R3 (N-type syntax of the baseline) and R4 (transforms at their identity values) are added by
%   phases P2 and P3.

R = struct('name', {}, 'pass', {}, 'msg', {});
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));          % br_generate, ref_maxdiff, the tsw07_* copies
refFile = fullfile(here, 'reference', 'br_freeze.mat');
if exist(refFile, 'file') ~= 2
    R = add(R, 'br R0: reference tests/reference/br_freeze.mat exists', false, ...
        'missing: run tests/scenarios/make_br_freeze.m on the code to freeze');
    return
end
L = load(refFile, 'ref');
ref = L.ref;
if maxNumCompThreads() ~= ref.threads
    fprintf('test_br_regression: %d computational threads, the references were made with %d.\n', ...
        maxNumCompThreads(), ref.threads);
end

% ---- R1: generated files ------------------------------------------------------------------
try
    G = br_generate();
    for i = 1:numel(ref.gen)
        g0 = ref.gen(i);
        nm = sprintf('br R1: %s %s generated file %s byte-identical to the freeze (MD5)', g0.package, ...
            g0.re_info, g0.file);
        k = find(strcmp({G.package}, g0.package) & strcmp({G.re_info}, g0.re_info) & strcmp({G.file}, g0.file));
        if numel(k) ~= 1
            R = add(R, nm, false, 'file not generated');
            continue
        end
        ok = strcmp(G(k).md5, g0.md5) && isequal(G(k).bytes, g0.bytes);
        msg = sprintf('md5 %s (frozen %s), %d bytes', G(k).md5, g0.md5, numel(G(k).bytes));
        if ~ok
            msg = [msg, '; first difference at byte ', num2str(first_diff(G(k).bytes, g0.bytes))]; %#ok<AGROW>
        end
        R = add(R, nm, ok, msg);
    end
    new = setdiff(strcat({G.package}, '/', {G.re_info}, '/', {G.file}), ...
        strcat({ref.gen.package}, '/', {ref.gen.re_info}, '/', {ref.gen.file}));
    if ~isempty(new)
        R = add(R, 'br R1: no generated file beyond the frozen set', false, strjoin(new, ', '));
    end
catch err
    R = add(R, 'br R1: generated files byte-identical to the freeze (MD5)', false, err.message);
end

% ---- R2: runs ---------------------------------------------------------------------------------
groups = {
    'br R2a: tsw07_peak_re (fast) equals the freeze exactly', {'tsw07'}, {'tsw07_peak_re'}, 'fast', ''
    'br R2b: tsw07_switch_pinf (fast) equals the freeze and tsw07_switch_pinf_fast.mat exactly', ...
        {'tsw07'}, {'tsw07_switch_pinf'}, 'fast', 'tsw07_switch_pinf_fast.mat'
    'br R2c: tsw07_switch_pinf (iris) equals the freeze and tsw07_switch_pinf_iris.mat exactly', ...
        {'tsw07'}, {'tsw07_switch_pinf'}, 'iris', 'tsw07_switch_pinf_iris.mat'
    'br R2d: baseline a1_re, a1_learn of 2026-10-20 (fast and iris) equal the freeze exactly', ...
        {'baseline'}, {}, '', ''
    'br R2e: 2019Q4 IRF runs, RE(t-1), no shock and +1 sd of 7 shocks, equal the freeze exactly', ...
        {'girf_re'}, {}, '', ''
    'br R2f: 2019Q4 IRF runs, baseline, no shock and +1 sd of 7 shocks, equal the freeze exactly', ...
        {'girf_learn'}, {}, '', ''
    'br R2g: 2019Q4 IRF runs, baseline, -1 sd of 7 shocks, equal the freeze exactly', ...
        {'girf_learn_minus'}, {}, '', ''};
newOpts = {};
for g = 1:size(groups, 1)
    sel = ismember({ref.runs.group}, groups{g, 2});
    if ~isempty(groups{g, 3})
        sel = sel & ismember({ref.runs.id}, groups{g, 3});
    end
    if ~isempty(groups{g, 4})
        sel = sel & strcmp({ref.runs.step}, groups{g, 4});
    end
    idx = find(sel);
    try
        okAll = ~isempty(idx);
        notes = {};
        for k = idx
            r0 = ref.runs(k);
            res = hetlearn.run(r0.cfg, 'save', false, 'quiet', true);
            [bad, extra] = compare_run(res, r0);
            newOpts = union(newOpts, extra.cfg);
            if ~isempty(bad)
                okAll = false;
                notes{end+1} = sprintf('%s (%s): %d differences, e.g. %s', r0.id, r0.step, numel(bad), ...
                    strjoin(bad(1:min(4, end)), '; ')); %#ok<AGROW>
            end
            if ~isempty(extra.out)
                notes{end+1} = sprintf('%s: outputs added since the freeze: %s', r0.id, strjoin(extra.out, ', ')); %#ok<AGROW>
            end
            if ~isempty(groups{g, 5})
                E = load(fullfile(here, 'reference', groups{g, 5}), 'ref');
                [d, worst] = ref_maxdiff(res, E.ref);
                if d ~= 0
                    okAll = false;
                end
                notes{end+1} = sprintf('%s: max diff %.3g %s', groups{g, 5}, d, worst); %#ok<AGROW>
            end
        end
        msg = sprintf('%d runs (%s)', numel(idx), strjoin(unique({ref.runs(idx).id}, 'stable'), ', '));
        if okAll
            msg = [msg, ': max diff 0']; %#ok<AGROW>
        end
        if ~isempty(notes)
            msg = [msg, '; ', strjoin(notes, ' | ')]; %#ok<AGROW>
        end
        R = add(R, groups{g, 1}, okAll, msg);
    catch err
        R = add(R, groups{g, 1}, false, where(err));
    end
end
if ~isempty(newOpts)
    fprintf('test_br_regression: options added since the freeze (%s): %s\n', ref.made, strjoin(newOpts, ', '));
end
end


% =========================================================================================
function [bad, extra] = compare_run(res, r0)
% Exact comparison of a fresh run with a frozen one. bad: differences (cellstr); extra.cfg:
% options of res.cfg the freeze does not have; extra.out: other output fields it does not have.
bad = {};
ex = {};
pn = fieldnames(r0.paths);
rn = fieldnames(res.paths);
miss = setdiff(pn, rn);
plus = setdiff(rn, pn);
if ~isempty(miss)
    bad{end+1} = ['paths missing: ' strjoin(miss', ', ')];
end
if ~isempty(plus)
    bad{end+1} = ['paths added: ' strjoin(plus', ', ')];
end
both = intersect(pn, rn);
for j = 1:numel(both)
    [bad, ex] = cmp(res.paths.(both{j}), r0.paths.(both{j}), ['paths.' both{j}], bad, ex);
end
top = {'learning', 'events', 'state', 'dates', 'loss', 'history_mode'};
for j = 1:numel(top)
    [bad, ex] = cmp(res.(top{j}), r0.(top{j}), top{j}, bad, ex);
end
mf = fieldnames(r0.meta);
for j = 1:numel(mf)
    [bad, ex] = cmp(res.meta.(mf{j}), r0.meta.(mf{j}), ['meta.' mf{j}], bad, ex);
end
[bad, exCfg] = cmp(res.cfg, r0.opts, 'cfg', bad, {});
extra = struct('cfg', {exCfg}, 'out', {ex});
end


function [bad, extra] = cmp(a, b, p, bad, extra)
% Recursive exact comparison of a (fresh) against b (frozen); fields b lacks are listed in extra.
if isa(b, 'Series')
    if ~isa(a, 'Series')
        bad{end+1} = [p ' is not a Series'];
        return
    end
    if ~(isequaln(double(a.Start), double(b.Start)) && isequaln(a.Data, b.Data))
        bad{end+1} = sprintf('%s (max diff %.3g)', p, series_diff(a, b));
    end
elseif istable(b)
    if ~istable(a) || height(a) ~= height(b)
        bad{end+1} = sprintf('%s: %d rows, frozen %d', p, height_of(a), height(b));
        return
    end
    vb = b.Properties.VariableNames;
    va = a.Properties.VariableNames;
    for j = 1:numel(vb)
        if ~ismember(vb{j}, va) || ~isequaln(a.(vb{j}), b.(vb{j}))
            bad{end+1} = sprintf('%s.%s', p, vb{j}); %#ok<AGROW>
        end
    end
    plus = setdiff(va, vb);
    for j = 1:numel(plus)
        extra{end+1} = [p '.' plus{j}]; %#ok<AGROW>
    end
elseif isstruct(b)
    if ~isstruct(a) || ~isequal(size(a), size(b))
        bad{end+1} = sprintf('%s: struct of size %s, frozen %s', p, mat2str(size(a)), mat2str(size(b)));
        return
    end
    fb = fieldnames(b);
    fa = fieldnames(a);
    miss = setdiff(fb, fa);
    for j = 1:numel(miss)
        bad{end+1} = [p '.' miss{j} ' missing']; %#ok<AGROW>
    end
    plus = setdiff(fa, fb);
    for j = 1:numel(plus)
        extra{end+1} = [p '.' plus{j}]; %#ok<AGROW>
    end
    both = intersect(fb, fa);
    for k = 1:numel(b)
        q = p;
        if numel(b) > 1
            q = sprintf('%s(%d)', p, k);
        end
        for j = 1:numel(both)
            [bad, extra] = cmp(a(k).(both{j}), b(k).(both{j}), [q '.' both{j}], bad, extra);
        end
    end
elseif iscell(b)
    if ~iscell(a) || ~isequal(size(a), size(b))
        bad{end+1} = sprintf('%s: cell of size %s, frozen %s', p, mat2str(size(a)), mat2str(size(b)));
        return
    end
    for k = 1:numel(b)
        [bad, extra] = cmp(a{k}, b{k}, sprintf('%s{%d}', p, k), bad, extra);
    end
elseif isnumeric(b) || islogical(b)
    if ~(isnumeric(a) || islogical(a)) || ~isequal(size(a), size(b))
        bad{end+1} = sprintf('%s: size %s, frozen %s', p, mat2str(size(a)), mat2str(size(b)));
    elseif ~isequaln(double(a), double(b))
        d = abs(double(a(:)) - double(b(:)));
        d(isnan(d)) = Inf;
        bad{end+1} = sprintf('%s (max diff %.3g)', p, max(d));
    end
elseif ischar(b) || isstring(b) || isa(b, 'function_handle')
    if ~isequal(class(a), class(b)) || ~isequal(a, b)
        bad{end+1} = p;
    end
else
    % IRIS dates (Dater) and other value objects
    try
        same = isequal(class(a), class(b)) && isequal(size(a), size(b)) && isequaln(double(a), double(b));
    catch
        same = isequaln(a, b);
    end
    if ~same
        bad{end+1} = p;
    end
end
end


function d = series_diff(a, b)
try
    rng = b.Range;
    x = a(rng);
    y = b(rng);
    e = abs(x(:) - y(:));
    e(isnan(x(:)) & isnan(y(:))) = 0;
    e(isnan(e)) = Inf;
    d = max([0; e]);
    if ~isequaln(double(a.Start), double(b.Start)) && d == 0
        d = NaN;        % same values on the frozen range, different range
    end
catch
    d = NaN;
end
end


function h = height_of(a)
h = NaN;
if istable(a)
    h = height(a);
end
end


function s = where(err)
s = err.message;
if ~isempty(err.stack)
    s = sprintf('%s (%s, line %d)', s, err.stack(1).name, err.stack(1).line);
end
end


function k = first_diff(a, b)
n = min(numel(a), numel(b));
k = find(a(1:n) ~= b(1:n), 1);
if isempty(k)
    k = n + 1;
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
