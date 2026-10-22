function R = test_transforms(part)
%TEST_TRANSFORMS  Forecast transforms, phase P3 of docs/DESIGN_br_extensions.md (1.3, D11, 1.7 R4; variants 5b, 7, 10).
%
%   R = test_transforms()        every part
%   R = test_transforms(part)    'neutral' | 'refs' | 'copies' | 'errors' | 'r4' | 'fitness'
%
%   19 checks. The checks of the transform kinds and multiplier profiles removed
%   on 2026-10-22 (docs/BR_audit.txt: N3, N6-N8, H3, H7, W1-W4, V1, R4e-f) are
%   gone; the other labels are unchanged.
%   N1-N5  collapse at the neutral value: each kind at its identity value (multiplier
%          m = 1, also with equation copies; myopia [1 0]; diagnostic theta = 0) loaded
%          on the 2026-10-20 baseline (tsw07_a1_learn) is the baseline's RE limit
%          (IRFs of every common variable to the seven shocks, 40 periods, 1e-12;
%          anchored RE(t-1) agents, the anchor economy of D11). Labels N1, N2, N4, N5.
%          Same generated file as the non-neutral variant (the values are parameters).
%          N9 anchored RE with period-t information: the coefficients from the RE
%          limit's state space (m = 1 equals the source-model anchor, 1e-12; m =
%          0.62 passes the anchored = model-consistent check)
%   H1-H6  generated = hand-written: the RE limit with model-consistent RE (period-t
%          information, learning {pinf}) equals the SW07 source edited by hand as in the
%          design's prototype P3 (scratchpad br_design/br_proto3.m): CD m = 0.62 on the
%          sticky seven (p3_v02), multipliers 0.76/0.86/0.08 of the RE type with
%          equation copies (p3_v06, m^h with h = 1), DE theta = 0.44 (p3_v09), myopia
%          and anchoring (0.52, 0.4343) in the price Phillips curve (p3_v12); H6 DE with
%          inflation RE(t-1): one more chain element, E_{t-2} pinf_{t+1} (IRFs, 40
%          periods, 1e-10). Labels H1, H2, H4, H5, H6
%   C1-C3  equation copies: equal values in the copies = the global multiplier (1e-12);
%          the copies replace pinf{+1} in their equations only; bad labels rejected
%   E1     errors: diagnostic on the anchored RE type with period-t information (the
%          anchored reference is not built), diagnostic on a learned type, diagnostic
%          after another transform, a transform acting on nothing
%   R4a-d  R4 of DESIGN_br_extensions 1.7: the full baseline run (tsw07_a1_learn)
%          with a transform at its identity value (the N1, N2, N4, N5 cases) equals the
%          two-type run. On one RE filter (the transform model's, recomputed in the
%          session): learning and final state <= 1e-12, paths exact when the transform
%          adds no model variable, else <= 1e-10 (IRIS solves a larger system: rounding,
%          as the target believers at share 0 of test_ntypes H1). On their own fresh
%          filters: paths <= 1e-10, learning and state <= 1e-11
%   F1     fitness on transformed forecasts (P4; added 2026-10-22, when the De Grauwe check A8 of
%          test_anchor went with variant 18): the baseline with the 5b multiplier m = 0.94 on the
%          learning set; every type's recorded forecast f_<k> (the one fitness and the errors use)
%          equals m^2 times its untransformed forecast fb_<k> (t-1 information, h = 2), 1e-12
%
%   Runs are not saved. About 3 minutes; the first call generates the model files.

if nargin < 1 || isempty(part)
    part = {'neutral', 'refs', 'copies', 'errors', 'r4', 'fitness'};
end
part = cellstr(part);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));
R = struct('name', {}, 'pass', {}, 'msg', {});
spec = hetlearn.load_spec('sw07');
if any(strcmp(part, 'neutral'))
    R = neutral(R, spec);
end
if any(strcmp(part, 'refs'))
    R = refs(R, spec);
end
if any(strcmp(part, 'copies'))
    R = copies_checks(R, spec);
end
if any(strcmp(part, 'errors'))
    R = errors(R, spec);
end
if any(strcmp(part, 'r4'))
    R = r4(R);
end
if any(strcmp(part, 'fitness'))
    R = fitness_check(R);
end
end


% =========================================================================================
function X = tf(kind, varargin)
% one expectations.transforms entry
X = struct('kind', kind, varargin{:});
end


function F = flex()
F = {'invef', 'pkf', 'rkf', 'cf', 'labf'};
end


function S = st6()
S = {'c', 'inve', 'lab', 'pk', 'rk', 'w'};
end


function X = br04(a, b, c)
% three multipliers of the RE type with equation copies of the inflation expectation (the structure of
% the shallow-reasoning prototype p3_v06; m^h, h = 1 with period-t information)
X = [tf('multiplier', 'types', {{'RE'}}, 'value', a, 'scope', {{'c', 'lab', 'inve', 'pk', 'rk'}}), ...
    tf('multiplier', 'types', {{'RE'}}, 'value', b, 'scope', ...
    {{'w', 'pinf@Phillips curve, price setting', 'pinf@Wage Phillips curve, wage setting'}}), ...
    tf('multiplier', 'types', {{'RE'}}, 'value', c, 'scope', ...
    {{'pinf@Consumption Euler equation', 'pinf@Arbitrage equation for the value of capital'}})];
end


function cases = identity_cases()
% {N label, R4 label, name, transforms, adds model variables (equation copies, reference chains)}; the
% labels are those of 2026-10-21 (N3, N6-N8 and R4e-f went with their kinds on 2026-10-22)
cases = {
    'N1', 'a', 'multiplier m = 1, every forward expectation but the flex block', tf('multiplier', 'types', 'all', ...
        'value', 1, 'scope', 'all', 'exclude', {flex()}), false
    'N2', 'b', 'multiplier m = 1 with equation copies (br04 structure)', br04(1, 1, 1), true
    'N4', 'c', 'myopia and anchoring [1 0] in the Phillips curve (br07 structure)', tf('myopia_anchoring', ...
        'types', 'all', 'value', [1 0], 'scope', {{'pinf@Phillips curve, price setting'}}), true
    'N5', 'd', 'diagnostic theta = 0 on the RE type, sticky expectations outside the learning set', tf('diagnostic', ...
        'types', {{'RE'}}, 'value', 0, 'scope', {st6()}), true};
end


% =========================================================================================
function R = neutral(R, spec)
base = tsw07_a1_learn();
[m0, i0] = hetlearn.load_model(spec, hetlearn.load_options(base));
el = cellstr(get(m0, 'eList'));
cases = identity_cases();
for q = 1:size(cases, 1)
    nm = sprintf('tf %s: %s at its neutral value = the baseline RE limit (IRFs, 1e-12)', cases{q, 1}, cases{q, 3});
    try
        c = base;
        c.expectations.transforms = cases{q, 4};
        [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
        d = irf_max(m0, m, cellstr(get(m0, 'xList')), el);
        ok = d <= 1e-12 && info.meta.generator_version == 7 && all(info.meta.collapse_maxdiff(2:3) < 1e-10);
        R = add(R, nm, ok, sprintf('max IRF diff %.3g; file %s, collapse test %s; anchored vs MC %.3g', d, ...
            short(info.meta.ext_file), mat2str(info.meta.collapse_maxdiff, 2), info.re_info_check.anchored_vs_mc_maxdiff));
    catch err
        R = add(R, nm, false, where(err));
    end
end
nm = ['tf N9: anchored RE with period-t information (D11 from the RE limit''s state space): CD m = 1 = the RE ' ...
    'limit without transforms (anchored on the source model, 1e-12); m = 0.62: anchored = model-consistent at n_RE = 1'];
try
    c = base;
    c.expectations.re_info = 'current';
    [mc0, ~] = hetlearn.load_model(spec, hetlearn.load_options(c));
    cdm = tf('multiplier', 'types', 'all', 'value', 1, 'scope', 'all', 'exclude', {flex()});
    c.expectations.transforms = cdm;
    [mc1, ic1] = hetlearn.load_model(spec, hetlearn.load_options(c));
    d1 = irf_max(mc0, mc1, cellstr(get(mc0, 'xList')), el);
    c.expectations.transforms.value = 0.62;
    [~, ic2] = hetlearn.load_model(spec, hetlearn.load_options(c));
    k1 = ic1.re_transform_check.anchored_vs_mc_maxdiff;
    k2 = ic2.re_transform_check.anchored_vs_mc_maxdiff;
    R = add(R, nm, d1 <= 1e-12 && k1 < 1e-10 && k2 < 1e-10 && strcmp(ic2.anchor.re_info, 'current'), sprintf(['m = 1 ' ...
        'vs no transforms %.3g; anchored vs model-consistent: m = 1 %.3g, m = 0.62 %.3g'], d1, k1, k2));
catch err
    R = add(R, nm, false, where(err));
end
clear i0
end


% =========================================================================================
function R = refs(R, spec)
src = fileread(fullfile(spec.folder, spec.model_file));
P = call_params(spec, 'sw07_params_original');
fwd7 = {'inve', 'pk', 'rk', 'c', 'lab', 'pinf', 'w'};
hh = {'inve', 'pk', 'rk', 'c', 'lab'};
mc = tsw07_a1_learn();
mc.expectations.re_variant = 'model_consistent';
mc.expectations.re_info = 'current';
H = {
    'H1: CD m = 0.62 on the sticky seven (p3_v02)', tf('multiplier', 'types', 'all', ...
        'value', 0.62, 'scope', 'all', 'exclude', {flex()}), glob(fwd7, '0.62*x{+1}'), mc
    'H2: multipliers 0.76/0.86/0.08 of the RE type, four inflation equation copies (p3_v06)', br04(0.76, 0.86, 0.08), ...
        [glob(hh, '0.76*x{+1}'), glob({'w'}, '0.86*x{+1}'), pinf_split('0.08*pinf{+1}', '0.86*pinf{+1}', '0.86*pinf{+1}')], mc
    'H4: diagnostic theta = 0.44 on the sticky seven, RE type (p3_v09)', tf('diagnostic', 'types', {{'RE'}}, ...
        'value', 0.44, 'scope', 'all', 'exclude', {flex()}), de(fwd7, '0.44'), mc
    'H5: myopia and anchoring (0.52, 0.4343) in the price Phillips curve (p3_v12)', tf('myopia_anchoring', ...
        'types', 'all', 'value', [0.52 0.4343], 'scope', {{'pinf@Phillips curve, price setting'}}), ...
        pinf_split('pinf{+1}', '0.52*pinf{+1} + 0.4343*pinf{-1}', 'pinf{+1}'), mc};
lg = tsw07_a1_learn();
lg.expectations.re_variant = 'model_consistent';
H(end+1, :) = {'H6: diagnostic theta = 0.44 with inflation RE(t-1): reference E_{t-2} pinf_{t+1} = pinf_REt3{-2}', ...
    tf('diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', 'exclude', {flex()}), ...
    [de(st6(), '0.44'), de_lagged('pinf', '0.44')], lg};
tmp = tempname;
mkdir(tmp);
cl = onCleanup(@() rmdir(tmp, 's'));
for q = 1:size(H, 1)
    nm = sprintf('tf %s: generated RE limit = hand-written model (IRFs, 40 periods, 1e-10)', H{q, 1});
    try
        c = H{q, 4};
        c.expectations.transforms = H{q, 2};
        [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
        f = fullfile(tmp, sprintf('hand%d.model', q));
        write_text(f, build(src, H{q, 3}));
        mh = Model.fromFile(f, 'linear', true, 'assign', spec.assign);
        mh = put(mh, P);
        [mh, okh] = hetlearn.engine.solve_model(mh, spec);
        xl = cellstr(get(Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true), 'xList'));
        el = cellstr(get(mh, 'eList'));
        d = irf_max(mh, m, xl, el);
        s = srf(mh, 1:4, 'select', {'em'});
        R = add(R, nm, okh && d < 1e-10, sprintf(['max IRF diff %.3g over %d variables, %d shocks; hand model: ' ...
            'pinf|em %.4f on impact, %.4f at h = 4, y|em %.4f; file %s'], d, numel(xl), numel(el), s.pinf(1), ...
            s.pinf(4), s.y(1), short(info.meta.ext_file)));
    catch err
        R = add(R, nm, false, where(err));
    end
end
clear cl
end


% =========================================================================================
function R = copies_checks(R, spec)
base = tsw07_a1_learn();
nm = 'tf C1: equal values in the four inflation copies and on c, lab, inve, pk, rk, w = one global multiplier (1e-12)';
try
    a = base;
    a.expectations.transforms = br04(0.8, 0.8, 0.8);
    [ma, ia] = hetlearn.load_model(spec, hetlearn.load_options(a));
    b = base;
    b.expectations.transforms = tf('multiplier', 'types', {{'RE'}}, 'value', 0.8, 'scope', ...
        {{'c', 'lab', 'inve', 'pk', 'rk', 'w', 'pinf'}});
    [mb, ib] = hetlearn.load_model(spec, hetlearn.load_options(b));
    % variables of the source model (pinf_exp1 differs by construction: unused, untransformed with copies)
    xl = cellstr(get(Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true), 'xList'));
    d = irf_max(ma, mb, xl, cellstr(get(mb, 'eList')));
    R = add(R, nm, d <= 1e-12 && ~strcmp(ia.meta.ext_file, ib.meta.ext_file), sprintf('max IRF diff %.3g over %d variables', ...
        d, numel(xl)));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'tf C2: the copies replace pinf{+1} in their four equations only; tags pc, wpc, cee, aeftvoc';
try
    a = base;
    a.expectations.transforms = br04(0.76, 0.86, 0.08);
    [~, ia] = hetlearn.load_model(spec, hetlearn.load_options(a));
    txt = fileread(ia.meta.ext_file);
    labs = {'Phillips curve, price setting', 'pc'; 'Wage Phillips curve, wage setting', 'wpc'; ...
        'Consumption Euler equation', 'cee'; 'Arbitrage equation for the value of capital', 'aeftvoc'};
    ok = true;
    msg = {};
    for q = 1:size(labs, 1)
        e = equation_text(txt, labs{q, 1});
        hit = ~isempty(strfind(e, ['pinf_exp1__' labs{q, 2}])) && isempty(regexp(e, 'pinf_exp1(?!_)', 'once')) ...
            && isempty(strfind(e, 'pinf{+1}')); %#ok<STREMP>
        ok = ok && hit;
        msg{end+1} = sprintf('%s %d', labs{q, 2}, hit); %#ok<AGROW>
    end
    tags = sort({ia.meta.transforms.copies.tag});
    ok = ok && isequal(tags, sort(labs(:, 2)'));
    kb = strfind(txt, 'hetlearn expectation block');
    body = txt(1:kb(1) - 1);
    nLeft = numel(regexp(body, 'pinf_exp1(?!_)', 'match'));
    ok = ok && nLeft == 0;
    R = add(R, nm, ok, sprintf('%s; bare pinf_exp1 left in the model equations: %d', strjoin(msg, ', '), nLeft));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'tf C3: equation scopes with an unknown label, an equation without the lead, a variable that is not forward-looking are rejected';
try
    bad = {'pinf@No such equation', 'pinf@Monetary policy rule, Taylor rule on the output gap y-yf', ...
        'y@Aggregate resource constraint'};
    n = 0;
    for q = 1:numel(bad)
        c = base;
        c.expectations.transforms = tf('multiplier', 'value', 0.5, 'scope', bad(q));
        try
            hetlearn.load_model(spec, hetlearn.load_options(c));
        catch err
            n = n + strcmp(err.identifier, 'hetlearn:extend_model:transforms');
        end
    end
    R = add(R, nm, n == numel(bad), sprintf('%d of %d rejected', n, numel(bad)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = errors(R, spec)
base = tsw07_a1_learn();
E = {};
% variant 10 on the anchored baseline and anchored RE(t-1) agents with diagnostic memory states load
% since phase P4 (2026-10-21): tests/test_anchor.m checks them
x = base;
x.expectations.re_info = 'current';
x.expectations.transforms = tf('diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', 'exclude', {flex()});
E(end+1, :) = {'variant 10 with anchored RE agents on period-t information (anchored reference not built)', x, ...
    'hetlearn:load_model:transforms'};
x = base;
x.expectations.transforms = tf('diagnostic', 'types', {{'BR'}}, 'value', 0.44, 'scope', 'learning');
E(end+1, :) = {'diagnostic on the learners', x, 'hetlearn:load_model:transforms'};
x = base;
x.expectations.re_variant = 'model_consistent';
x.expectations.transforms = {tf('multiplier', 'value', 0.9, 'scope', {{'c'}}), ...
    tf('diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', {{'c'}})};
E(end+1, :) = {'diagnostic after another transform', x, 'hetlearn:extend_model:transforms'};
x = base;
% scope 'learning' acts in the learning branch of every forward variable (the generator does not know
% the run's learning set), so only excluding all twelve forward variables leaves it nothing to act on
x.expectations.transforms = tf('multiplier', 'types', 'all', 'value', 0.9, 'scope', 'learning', 'exclude', ...
    {[{'c', 'inve', 'lab', 'pk', 'rk', 'w', 'pinf'}, flex()]});
E(end+1, :) = {'a transform acting on nothing (scope learning, every forward variable excluded)', x, ...
    'hetlearn:extend_model:transforms'};
bad = {};
for q = 1:size(E, 1)
    try
        hetlearn.load_model(spec, hetlearn.load_options(E{q, 2}));
        bad{end+1} = [E{q, 1} ': no error']; %#ok<AGROW>
    catch err
        if ~strcmp(err.identifier, E{q, 3})
            bad{end+1} = sprintf('%s: %s %s', E{q, 1}, err.identifier, err.message); %#ok<AGROW>
        end
    end
end
R = add(R, sprintf('tf E1: %d settings the transforms do not cover or malformed stop with their error', size(E, 1)), ...
    isempty(bad), strjoin(bad, ' | '));
end


% =========================================================================================
function R = r4(R)
% (1) both runs on the transform model's own RE filter: the transform at its identity value changes
% nothing: learning and final state <= 1e-12; paths 0 when the transform adds no model variable,
% else <= 1e-10 (IRIS solves a larger system: rounding, as test_ntypes H1); (2) each run on its own
% fresh RE filter (the filter of the larger model differs at rounding level): paths <= 1e-10,
% learning and state <= 1e-11
a = tsw07_a1_learn();
oa = hetlearn.load_options(a);
spec = hetlearn.load_spec(oa.model);
[ma, ia] = hetlearn.load_model(spec, oa);
Ma = struct('spec', spec, 'm', ma, 'info', ia);
ra = hetlearn.run(a, 'save', false, 'quiet', true, 'model', Ma, 'filter', fresh_filter(spec, oa));
cases = identity_cases();
for k = 1:size(cases, 1)
    tolP = 0;
    if cases{k, 5}
        tolP = 1e-10;
    end
    nm = sprintf(['tf R4%s: baseline run with %s = the two-type run (one RE filter: learning, state 1e-12, ' ...
        'paths %s; own filters: paths 1e-10, learning and state 1e-11)'], cases{k, 2}, cases{k, 3}, ...
        ternary(cases{k, 5}, '1e-10', 'exact'));
    try
        b = a;
        b.expectations.transforms = cases{k, 4};
        [rb, Hb] = fresh_run(b);
        ra2 = hetlearn.run(a, 'save', false, 'quiet', true, 'model', Ma, 'filter', Hb);
        [d1, ~, e1] = compare_runs(ra2, rb, {'pinf'}, 'BR', setdiff(fieldnames(rb.paths), fieldnames(ra2.paths)));
        [d2, ~, e2] = compare_runs(ra, rb, {'pinf'}, 'BR', setdiff(fieldnames(rb.paths), fieldnames(ra.paths)));
        ok = isfinite(d1) && e1.learning <= 1e-12 && e1.state <= 1e-12 && e1.paths <= tolP ...
            && isfinite(d2) && e2.paths <= 1e-10 && e2.learning <= 1e-11 && e2.state <= 1e-11;
        R = add(R, nm, ok, sprintf(['one filter: paths %.3g, learning %.3g, state %.3g; own filters: paths %.3g, ' ...
            'learning %.3g, state %.3g; adds model variables %d; %d events'], e1.paths, e1.learning, e1.state, ...
            e2.paths, e2.learning, e2.state, cases{k, 5}, height(rb.events)));
    catch err
        R = add(R, nm, false, where(err));
    end
end
end


function R = fitness_check(R)
% F1: the forecasts that fitness and the forecast errors use are the transformed ones
nm = 'tf F1: fitness on transformed forecasts: f_<k> = m^2*fb_<k> for RE and BR (multiplier 0.94, 1e-12)';
try
    b = tsw07_a1_learn();
    b.expectations.transforms = tf('multiplier', 'types', 'all', 'value', 0.94, 'scope', 'learning', ...
        'exclude', {flex()});
    rb = hetlearn.run(b, 'save', false, 'quiet', true);
    L = rb.learning.pinf;
    D = 0.94^2;
    d = 0;
    nOk = 0;
    gap = 0;
    for k = {'RE', 'BR'}
        f = double(L.(['f_' k{1}]));
        fb = double(L.(['fb_' k{1}]));
        u = isfinite(f) & isfinite(fb);
        nOk = nOk + sum(u);
        d = max([d; abs(f(u) - D * fb(u))]);
        gap = max([gap; abs(f(u) - fb(u))]);
    end
    R = add(R, nm, nOk > 400 && d <= 1e-12 && gap > 1e-3, sprintf(['max |f - m^2 fb| %.3g over %d quarter-type ' ...
        'pairs; max |f - fb| %.3g (the transform acts)'], d, nOk, gap));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
% hand-written models (the text edits of the design's prototype P3)
function E = glob(vars, form)
% every x{+1} of each variable -> x_e = form
E = struct('find', {}, 'repl', {}, 'decl', {}, 'eq', {});
for i = 1:numel(vars)
    x = vars{i};
    E(end+1) = struct('find', ['(?<![\w])' x '\{\+1\}'], 'repl', [x '_e'], 'decl', {{[x '_e']}}, ...
        'eq', {{sprintf('%s_e = %s;', x, strrep(form, 'x', x))}}); %#ok<AGROW>
end
end


function E = de(vars, th)
E = struct('find', {}, 'repl', {}, 'decl', {}, 'eq', {});
for i = 1:numel(vars)
    x = vars{i};
    E(end+1) = struct('find', ['(?<![\w])' x '\{\+1\}'], 'repl', [x '_e'], 'decl', {{[x '_e'], [x '_t1'], [x '_t2']}}, ...
        'eq', {{sprintf('%s_e = (1+%s)*%s_t1 - %s*%s_t2{-1};', x, th, x, th, x), sprintf('%s_t1 = %s{+1};', x, x), ...
        sprintf('%s_t2 = %s_t1{+1};', x, x)}}); %#ok<AGROW>
end
end


function E = de_lagged(x, th)
% RE(t-1) expectation E_{t-1} x_{t+1} with the DE reference E_{t-2} x_{t+1}
E = struct('find', ['(?<![\w])' x '\{\+1\}'], 'repl', [x '_e'], 'decl', {{[x '_e'], [x '_t1'], [x '_t2'], [x '_t3']}}, ...
    'eq', {{sprintf('%s_e = (1+%s)*%s_t2{-1} - %s*%s_t3{-2};', x, th, x, th, x), sprintf('%s_t1 = %s{+1};', x, x), ...
    sprintf('%s_t2 = %s_t1{+1};', x, x), sprintf('%s_t3 = %s_t2{+1};', x, x)}});
end


function E = pinf_split(rr, pc, wc)
% equation-specific copies of the inflation expectation: real rate (Q and Euler), price and wage curves
E = struct('find', {}, 'repl', {}, 'decl', {}, 'eq', {});
E(end+1) = struct('find', 'pk = -r \+ pinf\{\+1\}', 'repl', 'pk = -r + pinf_rr', 'decl', {{'pinf_rr'}}, 'eq', {{['pinf_rr = ' rr ';']}});
E(end+1) = struct('find', '\(r-pinf\{\+1\}\+0\*b\)', 'repl', '(r-pinf_rr+0*b)', 'decl', {{}}, 'eq', {{}});
E(end+1) = struct('find', '\$cbetabar\$\*\$cgamma\$\*pinf\{\+1\} \+ cindp', 'repl', '$cbetabar$*$cgamma$*pinf_pc + cindp', ...
    'decl', {{'pinf_pc'}}, 'eq', {{['pinf_pc = ' pc ';']}});
E(end+1) = struct('find', '\(1\+\$cbetabar\$\*\$cgamma\$\)\*pinf\{\+1\}', 'repl', '(1+$cbetabar$*$cgamma$)*pinf_wc', ...
    'decl', {{'pinf_wc'}}, 'eq', {{['pinf_wc = ' wc ';']}});
end


function txt = build(src, E)
txt = src;
decl = {};
eqs = {};
for i = 1:numel(E)
    if ~isempty(E(i).find)
        n0 = numel(regexp(txt, E(i).find));
        if n0 == 0
            error('test_transforms:hand', 'pattern not found: %s', E(i).find);
        end
        txt = regexprep(txt, E(i).find, E(i).repl);
    end
    decl = [decl, E(i).decl]; %#ok<AGROW>
    eqs = [eqs, E(i).eq]; %#ok<AGROW>
end
txt = [txt, newline, '!transition_variables', newline, '    ', strjoin(decl, ', '), newline, ...
    '!transition_equations', newline, '    ', strjoin(eqs, [newline '    ']), newline];
end


function write_text(f, txt)
fid = fopen(f, 'w');
fprintf(fid, '%s', txt);
fclose(fid);
end


function e = equation_text(txt, label)
% the text of the equation labelled label, up to its semicolon
k = strfind(txt, ['"' label '"']);
e = '';
if isempty(k)
    return
end
s = k(1) + numel(label) + 2;
j = find(txt(s:end) == ';', 1);
e = txt(s:s + j - 1);
end


% =========================================================================================
% numerics
function d = irf_max(ma, mb, xl, el)
% max abs IRF difference of two solved models: variables xl, shocks el, 40 periods
sa = srf(ma, 1:40, 'select', el);
sb = srf(mb, 1:40, 'select', el);
d = 0;
for i = 1:numel(xl)
    e = abs(sa.(xl{i})(1:40, :) - sb.(xl{i})(1:40, :));
    e(isnan(e)) = Inf;
    d = max([d; e(:)]);
end
end


function P = call_params(spec, fn)
addpath(spec.folder);
c = onCleanup(@() rmpath(spec.folder));
P = feval(fn);
end


function m = put(m, P)
pn = fieldnames(get(m, 'parameters'));
el = cellstr(get(m, 'eList'));
q = fieldnames(P);
for i = 1:numel(q)
    if any(strcmp(pn, q{i})) || any(strcmp(strcat('std_', el), q{i}))
        m.(q{i}) = P.(q{i});
    end
end
end


% =========================================================================================
% runs (as test_ntypes)
function [res, H] = fresh_run(cfg)
opts = hetlearn.load_options(cfg);
spec = hetlearn.load_spec(opts.model);
[m, info] = hetlearn.load_model(spec, opts);
H = fresh_filter(spec, opts);
res = hetlearn.run(cfg, 'save', false, 'quiet', true, 'model', struct('spec', spec, 'm', m, 'info', info), ...
    'filter', H);
end


function H = fresh_filter(spec, opts)
% the IRIS filter call of hetlearn.re_filter, without its cache file
lagged = strcmp(opts.expectations.re_info, 'lagged');
o = opts;
if ~lagged
    o.expectations.variables = 'all';
end
o.policy.mode = 'rule';
[m, info] = hetlearn.load_model(spec, o);
d = hetlearn.load_database(spec);
range = hetlearn.util.to_dates(spec.filter_range);
H = struct();
if lagged
    [~, f] = filter(m, d, range, 'output', 'pred,filter,smooth', 'meanOnly', true);
    H.predicted = f.pred;
else
    [~, f] = filter(m, d, range, 'output', 'filter,smooth', 'meanOnly', true);
end
H.smooth = f.smooth;
H.filtered = f.filter;
H.range = range;
H.data = d;
H.fit_error = 0;
H.hash = ['fresh:' info.meta.ext_file];
H.file = '';
H.cached = false;
H.model = m;
H.realtime = false;
H.end_date = range(end);
end


function [dmax, msg, d] = compare_runs(ra, rb, lv, k, extra)
% two-type run ra against an N-type run rb whose types are RE and k (test_ntypes): max abs differences
if nargin < 5
    extra = {};
end
d = struct('paths', 0, 'learning', 0, 'state', 0);
w = struct('paths', '', 'learning', '', 'state', '');
bad = {};
pa = fieldnames(ra.paths);
pb = setdiff(fieldnames(rb.paths), extra);
if ~isempty(setxor(pa, pb))
    bad{end+1} = ['path names differ: ' strjoin(reshape(setxor(pa, pb), 1, []), ', ')];
end
for i = 1:numel(pa)
    if isfield(rb.paths, pa{i})
        [d, w] = upd(d, w, 'paths', sdiff(ra.paths.(pa{i}), rb.paths.(pa{i})), pa{i});
    end
end
map = {'n1', 'n_RE'; 'n2', ['n_' k]; 'n1_model', 'n_model_RE'; 'zetaRE', 'U_RE'; 'zetaBR', ['U_' k]; ...
    'FE_RE', 'FE_RE'; 'FE_BR', ['FE_' k]; 'fRE', 'f_RE'; 'fBR', ['f_' k]};
tg = fieldnames(ra.learning);
for i = 1:numel(tg)
    A = ra.learning.(tg{i});
    if any(strcmp(lv, tg{i}))
        B = rb.learning.(tg{i});
        for j = 1:size(map, 1)
            [d, w] = upd(d, w, 'learning', sdiff(A.(map{j, 1}), B.(map{j, 2})), [tg{i} '.' map{j, 1}]);
        end
    end
    K = rb.learning.([tg{i} '__' k]);
    f = setdiff(fieldnames(A), [map(:, 1)', {'isAux', 'params'}]);
    for j = 1:numel(f)
        g = f{j};
        if ~isfield(K, g)
            g = regexprep(g, '^(R_)?(.*)$', ['$1$2__' k]);
        end
        [d, w] = upd(d, w, 'learning', sdiff(A.(f{j}), K.(g)), [tg{i} '.' f{j}]);
    end
end
Ea = ra.events;
Eb = rb.events;
if height(Ea) ~= height(Eb)
    bad{end+1} = sprintf('%d vs %d events', height(Ea), height(Eb));
else
    s = @(c) regexprep(c, ['__' k '\>'], '');
    if ~isequal(Ea.date, Eb.date) || ~isequal(Ea.type, Eb.type) || ~isequal(Ea.stage, Eb.stage) ...
            || ~isequal(Ea.variable, s(Eb.variable)) || ~isequal(Ea.detail, s(Eb.detail))
        bad{end+1} = 'events differ';
    end
end
Sa = ra.state;
Sb = rb.state;
for i = 1:numel(tg)
    q = [tg{i} '__' k];
    [d, w] = upd(d, w, 'state', maxabs(Sa.phi.(tg{i}) - Sb.phi.(q)), ['phi.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.R.(tg{i}) - Sb.R.(q)), ['R.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.fe_hist.(tg{i}) - Sb.fe_hist.(q)), ['fe_hist.' tg{i}]);
    [d, w] = upd(d, w, 'state', maxabs(Sa.phi_hist.(tg{i}) - Sb.phi_hist.(q)), ['phi_hist.' tg{i}]);
end
for g = 1:numel(Sa.n1)
    [d, w] = upd(d, w, 'state', maxabs([Sa.n1(g), Sa.zetaRE(g), Sa.zetaBR(g)] - [Sb.n{g}(1), Sb.U{g}(1), Sb.U{g}(2)]), 'shares');
end
for i = 1:numel(lv)
    [d, w] = upd(d, w, 'state', maxabs([Sa.fRE.(lv{i}), Sa.fBR.(lv{i})] - [Sb.f.(lv{i}).RE, Sb.f.(lv{i}).(k)]), 'forecasts');
end
[gd, ok] = numdiff(Sa.gain, Sb.gain.(k));
if ~ok
    bad{end+1} = 'gain states differ in structure';
end
[d, w] = upd(d, w, 'state', gd, 'gain');
dmax = max([d.paths, d.learning, d.state]);
if ~isempty(bad)
    dmax = Inf;
end
msg = sprintf('max diff paths %.3g (%s), learning %.3g (%s), final state %.3g (%s); %d events; %d extra paths', ...
    d.paths, w.paths, d.learning, w.learning, d.state, w.state, height(Ea), numel(extra));
if ~isempty(bad)
    msg = [msg '; ' strjoin(bad, '; ')];
end
end


function [d, w] = upd(d, w, f, v, name)
if ~(v <= d.(f))
    d.(f) = v;
    w.(f) = name;
end
end


function v = sdiff(a, b)
v = 0;
for r = {a.Range, b.Range}
    x = a(r{1});
    y = b(r{1});
    e = abs(x(:) - y(:));
    e(isnan(x(:)) & isnan(y(:))) = 0;
    e(isnan(e)) = Inf;
    v = max([v; e]);
end
end


function v = maxabs(x)
x = x(:);
x(isnan(x)) = 0;
v = max([0; abs(x)]);
end


function [d, ok] = numdiff(a, b)
d = 0;
ok = true;
if isstruct(a)
    if ~isstruct(b) || ~isequal(sort(fieldnames(a)), sort(fieldnames(b))) || ~isequal(size(a), size(b))
        ok = false;
        return
    end
    f = fieldnames(a);
    for i = 1:numel(a)
        for j = 1:numel(f)
            [e, o] = numdiff(a(i).(f{j}), b(i).(f{j}));
            d = max(d, e);
            ok = ok && o;
        end
    end
elseif isnumeric(a) || islogical(a)
    if ~isequal(size(a), size(b))
        ok = false;
        return
    end
    d = maxabs(double(a) - double(b));
elseif iscell(a)
    if ~iscell(b) || ~isequal(size(a), size(b))
        ok = false;
        return
    end
    for i = 1:numel(a)
        [e, o] = numdiff(a{i}, b{i});
        d = max(d, e);
        ok = ok && o;
    end
else
    ok = isequal(a, b);
end
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end


function s = short(f)
[~, n, x] = fileparts(f);
s = [n x];
end


function s = where(err)
s = err.message;
if ~isempty(err.stack)
    s = sprintf('%s (%s, line %d)', s, err.stack(1).name, err.stack(1).line);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
