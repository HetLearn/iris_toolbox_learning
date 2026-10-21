function R = test_transforms(part)
%TEST_TRANSFORMS  Forecast transforms, phase P3 of docs/DESIGN_br_extensions.md (1.3, D11, 1.7 R4; variants 4-7, 10, 18, 29, 31).
%
%   R = test_transforms()        every part
%   R = test_transforms(part)    'neutral' | 'refs' | 'copies' | 'wedges' | 'values' | 'errors' | 'r4'
%
%   N1-N8  collapse at the neutral value: each kind at its identity value (multiplier
%          m = 1, lambda = 1 with equation copies, alpha = 0; myopia [1 0]; diagnostic
%          theta = 0; partial adjustment g = 1; wedge std 0; constant wedges 0 on the
%          De Grauwe types) loaded on the 2026-10-20 baseline (tsw07_a1_learn) is the
%          baseline's RE limit (IRFs of every common variable to the seven shocks, 40
%          periods, 1e-12; anchored RE(t-1) agents, the anchor economy of D11). Same
%          generated file as the non-neutral variant (the factors are parameters).
%          N9 anchored RE with period-t information: the coefficients from the RE
%          limit's state space (m = 1 equals the source-model anchor, 1e-12; m =
%          0.62 passes the anchored = model-consistent check)
%   H1-H7  generated = hand-written: the RE limit with model-consistent RE (period-t
%          information, learning {pinf}) equals the SW07 source edited by hand as in the
%          design's prototype P3 (scratchpad br_design/br_proto3.m): CD m = 0.62 on the
%          sticky seven (p3_v02), shallow reasoning GHL 0.76/0.86/0.08 with equation
%          copies (p3_v06), hyperbolic alpha = 0.176 (p3_v08), DE theta = 0.44 (p3_v09),
%          myopia and anchoring (0.52, 0.4343) in the price Phillips curve (p3_v12);
%          H6 DE with inflation RE(t-1): one more chain element, E_{t-2} pinf_{t+1};
%          H7 partial adjustment g = 0.6 of the RE type (pinf) and of the
%          model-consistent expectation of w (IRFs, 40 periods, 1e-10)
%   C1-C3  equation copies: equal values in the copies = the global multiplier (1e-12);
%          the copies replace pinf{+1} in their equations only; bad labels rejected
%   W1-W4  wedges: the shock enters the model (pinf_exp1 impact response = sigma at the
%          RE limit; hand-written AR(1) wedge model, 1e-10); in a 2019Q4 forecast run
%          with shocks.add the wedge shock moves pinf_exp1 by sigma on impact and xi
%          decays with rho; ACD loadings = Cov(z, y)/Var(y) and the calibrated std
%          gives a 51% band (6-32 quarters) variance share of y, by independent
%          state-space formulas
%   V1     De Grauwe bias g = sd(y - yf)/2 (independent Lyapunov) and equal OPT/PES
%          shares reproduce the model-consistent c expectation exactly
%   E1     errors at the P4 boundary and for kinds not built: diagnostic on the anchored
%          RE type, anchored agents in an economy with diagnostic memory states,
%          diagnostic or partial adjustment on a learned type, diagnostic after another
%          transform, unknown model rule, a transform acting on nothing
%   R4a-f  R4 of DESIGN_br_extensions 1.7: the full baseline run (tsw07_a1_learn)
%          with a transform at its identity value equals the two-type run. On one
%          RE filter (the transform model's, recomputed in the session): learning
%          and final state <= 1e-12, paths exact when the transform adds no model
%          variable, else <= 1e-10 (IRIS solves a larger system: rounding, as the
%          target believers at share 0 of test_ntypes H1). On their own fresh
%          filters: paths <= 1e-10, learning and state <= 1e-11
%
%   Runs are not saved. About 4 minutes; the first call generates the model files.

if nargin < 1 || isempty(part)
    part = {'neutral', 'refs', 'copies', 'wedges', 'values', 'errors', 'r4'};
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
if any(strcmp(part, 'wedges'))
    R = wedges(R, spec);
end
if any(strcmp(part, 'values'))
    R = values(R, spec);
end
if any(strcmp(part, 'errors'))
    R = errors(R, spec);
end
if any(strcmp(part, 'r4'))
    R = r4(R);
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
X = [tf('multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', a, 'scope', {{'c', 'lab', 'inve', 'pk', 'rk'}}), ...
    tf('multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', b, 'scope', ...
    {{'w', 'pinf@Phillips curve, price setting', 'pinf@Wage Phillips curve, wage setting'}}), ...
    tf('multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', c, 'scope', ...
    {{'pinf@Consumption Euler equation', 'pinf@Arbitrage equation for the value of capital'}})];
end


function c = br18(c)
T = @(varargin) struct(varargin{:});
c.expectations.variables = {'pinf', 'c'};
c.expectations.types = {T('name', 'TAR', 'kind', 'rule', 'rule', '0', 'variables', {{'pinf'}}), ...
    T('name', 'EXT', 'kind', 'rule', 'rule', 'x{-1}', 'variables', {{'pinf'}}), ...
    T('name', 'OPT', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}}), ...
    T('name', 'PES', 'kind', 're', 'variant', 'model_consistent', 'info', 'current', 'variables', {{'c'}})};
end


function cases = identity_cases()
% {name, transforms, adds model variables (equation copies, reference chains, partial-adjustment
% states, wedge factors)}
w0 = tf('wedge', 'types', 'all', 'scope', {{'pinf'}}, 'factor', struct('rho', 0.714, 'std', 0, 'mean', 0, 'shock', 'e_wpinf'));
cases = {
    'multiplier geometric m = 1 (br05a structure)', tf('multiplier', 'profile', 'geometric', 'types', 'all', ...
        'value', 1, 'scope', 'all', 'exclude', {flex()}), false
    'multiplier flat lambda = 1, equation copies (br04 structure)', br04(1, 1, 1), true
    'multiplier hyperbolic alpha = 0 (br06 structure)', tf('multiplier', 'profile', 'hyperbolic', 'types', 'all', ...
        'value', 0, 'scope', 'all', 'exclude', {flex()}), false
    'myopia and anchoring [1 0] in the Phillips curve (br07 structure)', tf('myopia_anchoring', 'types', 'all', ...
        'value', [1 0], 'scope', {{'pinf@Phillips curve, price setting'}}), true
    'diagnostic theta = 0 on the RE type, sticky expectations outside the learning set', tf('diagnostic', ...
        'types', {{'RE'}}, 'value', 0, 'scope', {st6()}), true
    'partial adjustment g = 1 on c and w (all types)', tf('partial_adjustment', 'types', 'all', 'value', 1, ...
        'scope', {{'c', 'w'}}), true
    'wedge with std 0 on pinf, all types (br29 structure)', w0, true};
end


% =========================================================================================
function R = neutral(R, spec)
base = tsw07_a1_learn();
[m0, i0] = hetlearn.load_model(spec, hetlearn.load_options(base));
el = cellstr(get(m0, 'eList'));
cases = identity_cases();
for q = 1:size(cases, 1)
    nm = sprintf('tf N%d: %s at its neutral value = the baseline RE limit (IRFs, 1e-12)', q, cases{q, 1});
    try
        c = base;
        c.expectations.transforms = cases{q, 2};
        [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
        d = irf_max(m0, m, cellstr(get(m0, 'xList')), el);
        ok = d <= 1e-12 && info.meta.generator_version == 7 && all(info.meta.collapse_maxdiff(2:3) < 1e-10);
        R = add(R, nm, ok, sprintf('max IRF diff %.3g; file %s, collapse test %s; anchored vs MC %.3g', d, ...
            short(info.meta.ext_file), mat2str(info.meta.collapse_maxdiff, 2), info.re_info_check.anchored_vs_mc_maxdiff));
    catch err
        R = add(R, nm, false, where(err));
    end
end
nm = 'tf N8: constant wedges 0 on the De Grauwe types OPT and PES (br18 structure) = br18 without transforms (IRFs, 1e-12)';
try
    c = br18(base);
    [m1, i1] = hetlearn.load_model(spec, hetlearn.load_options(c));
    c.expectations.transforms = [tf('wedge', 'types', {{'OPT'}}, 'factor', struct('mean', 0)), ...
        tf('wedge', 'types', {{'PES'}}, 'factor', struct('mean', 0))];
    [m2, i2] = hetlearn.load_model(spec, hetlearn.load_options(c));
    d = irf_max(m1, m2, cellstr(get(m1, 'xList')), el);
    R = add(R, nm, d <= 1e-12 && ~strcmp(i1.meta.ext_file, i2.meta.ext_file), sprintf('max IRF diff %.3g', d));
catch err
    R = add(R, nm, false, where(err));
end
nm = ['tf N9: anchored RE with period-t information (D11 from the RE limit''s state space): CD m = 1 = the RE ' ...
    'limit without transforms (anchored on the source model, 1e-12); m = 0.62: anchored = model-consistent at n_RE = 1'];
try
    c = base;
    c.expectations.re_info = 'current';
    [mc0, ~] = hetlearn.load_model(spec, hetlearn.load_options(c));
    cdm = tf('multiplier', 'profile', 'geometric', 'types', 'all', 'value', 1, 'scope', 'all', 'exclude', {flex()});
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
st7 = [st6(), {'pinf'}];
H = {
    'H1: CD m = 0.62 on the sticky seven (p3_v02)', tf('multiplier', 'profile', 'geometric', 'types', 'all', ...
        'value', 0.62, 'scope', 'all', 'exclude', {flex()}), glob(fwd7, '0.62*x{+1}'), mc
    'H2: shallow reasoning GHL 0.76/0.86/0.08, four inflation equation copies (p3_v06)', br04(0.76, 0.86, 0.08), ...
        [glob(hh, '0.76*x{+1}'), glob({'w'}, '0.86*x{+1}'), pinf_split('0.08*pinf{+1}', '0.86*pinf{+1}', '0.86*pinf{+1}')], mc
    'H3: hyperbolic alpha = 0.176 on the sticky seven (p3_v08)', tf('multiplier', 'profile', 'hyperbolic', ...
        'types', 'all', 'value', 0.176, 'scope', {st7}), glob(fwd7, '(1/(1+0.176))*x{+1}'), mc
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
% (g = 0.6 on the consumption expectation has no stable solution: NO_STABLE)
H(end+1, :) = {'H7: partial adjustment g = 0.6 of the RE forecast of pinf and of the expectation of w', ...
    tf('partial_adjustment', 'types', {{'RE'}}, 'value', 0.6, 'scope', {{'pinf', 'w'}}), ...
    pa_hand({'pinf', 'w'}, '0.6'), mc};
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
nm = 'tf C1: equal values in the four inflation copies and on c, lab, inve, pk, rk, w = one global flat multiplier (1e-12)';
try
    a = base;
    a.expectations.transforms = br04(0.8, 0.8, 0.8);
    [ma, ia] = hetlearn.load_model(spec, hetlearn.load_options(a));
    b = base;
    b.expectations.transforms = tf('multiplier', 'profile', 'flat', 'types', {{'RE'}}, 'value', 0.8, 'scope', ...
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
        c.expectations.transforms = tf('multiplier', 'profile', 'flat', 'value', 0.5, 'scope', bad(q));
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
function R = wedges(R, spec)
base = tsw07_a1_learn();
w29 = tf('wedge', 'types', 'all', 'scope', {{'pinf'}}, 'factor', struct('rho', 0.714, 'std', 0.182, 'mean', 0, ...
    'shock', 'e_wpinf'));
nm = 'tf W1: wedge of variant 29: e_wpinf in the model with std 0.182; impact response of pinf_exp1 = sigma at the RE limit';
try
    c = base;
    c.expectations.transforms = w29;
    [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
    el = cellstr(get(m, 'eList'));
    s = srf(m, 1:3, 'select', {'e_wpinf'});
    sd = m.std_e_wpinf;
    d = abs(s.pinf_exp1(1) - 0.182) + abs(s.xi_e_wpinf(2) - 0.714 * 0.182);
    ok = any(strcmp(el, 'e_wpinf')) && abs(sd - 0.182) < 1e-15 && d < 1e-12 && abs(info.params.std_e_wpinf - 0.182) < 1e-15;
    R = add(R, nm, ok, sprintf('std %.4g; pinf_exp1 impact %.6g, xi at h = 2 %.6g (rho*sigma %.6g); pinf impact %.4g', ...
        sd, s.pinf_exp1(1), s.xi_e_wpinf(2), 0.714 * 0.182, s.pinf(1)));
catch err
    R = add(R, nm, false, where(err));
end

nm = 'tf W2: generated wedge model (model-consistent RE, period-t information) = hand-written AR(1) wedge model (IRFs to 8 shocks, 1e-10)';
try
    c = base;
    c.expectations.re_variant = 'model_consistent';
    c.expectations.re_info = 'current';
    c.expectations.transforms = w29;
    [m, ~] = hetlearn.load_model(spec, hetlearn.load_options(c));
    src = fileread(fullfile(spec.folder, spec.model_file));
    E = glob({'pinf'}, 'x{+1} + wdg');
    E(end+1) = struct('find', '', 'repl', '', 'decl', {{'wdg'}}, 'eq', {{'wdg = 0.714*wdg{-1} + e_wpinf;'}});
    txt = build(src, E);
    txt = [txt, newline, '!transition_shocks', newline, '    e_wpinf', newline];
    tmp = tempname;
    mkdir(tmp);
    cl = onCleanup(@() rmdir(tmp, 's'));
    f = fullfile(tmp, 'hand_wedge.model');
    write_text(f, txt);
    mh = Model.fromFile(f, 'linear', true, 'assign', spec.assign);
    mh = put(mh, call_params(spec, 'sw07_params_original'));
    mh.std_e_wpinf = 0.182;
    [mh, okh] = hetlearn.engine.solve_model(mh, spec);
    xl = cellstr(get(Model.fromFile(fullfile(spec.folder, spec.model_file), 'linear', true), 'xList'));
    d = irf_max(mh, m, xl, cellstr(get(mh, 'eList')));
    R = add(R, nm, okh && d < 1e-10, sprintf('max IRF diff %.3g over %d variables', d, numel(xl)));
    clear cl
catch err
    R = add(R, nm, false, where(err));
end

nm = ['tf W3: 2019Q4 forecast run of the baseline with the variant-29 wedge: shocks.add one sd of e_wpinf in 2020Q1 ' ...
    'moves pinf_exp1 by sigma on impact, xi decays with rho (beliefs, gains, shares updating)'];
try
    a = tsw07_girf2019('learn');
    a.expectations.transforms = w29;
    o = hetlearn.load_options(a);
    [m, info] = hetlearn.load_model(spec, o);
    Hf = fresh_filter(spec, o);
    M = struct('spec', spec, 'm', m, 'info', info);
    r0 = hetlearn.run(a, 'save', false, 'quiet', true, 'model', M, 'filter', Hf);
    b = tsw07_girf2019('learn', 'e_wpinf', 0.182);
    b.expectations.transforms = w29;
    r1 = hetlearn.run(b, 'save', false, 'quiet', true, 'model', M, 'filter', Hf);
    t1 = qq(2020, 1);
    dp = r1.paths.pinf_exp1(t1) - r0.paths.pinf_exp1(t1);
    dx1 = r1.paths.xi_e_wpinf(t1) - r0.paths.xi_e_wpinf(t1);
    dx2 = r1.paths.xi_e_wpinf(t1 + 1) - r0.paths.xi_e_wpinf(t1 + 1);
    dpi = r1.paths.pinf(t1 + 1) - r0.paths.pinf(t1 + 1);
    ok = abs(dp - 0.182) < 1e-10 && abs(dx1 - 0.182) < 1e-12 && abs(dx2 - 0.714 * 0.182) < 1e-12 && abs(dpi) > 1e-4;
    R = add(R, nm, ok, sprintf(['GIRF 2020Q1: pinf_exp1 %.6g, xi %.6g; 2020Q2: xi %.6g (rho*sigma %.6g), pinf %.4g; ' ...
        'shares in 2020Q1 equal in both runs %d'], dp, dx1, dx2, 0.714 * 0.182, dpi, ...
        abs(r1.learning.pinf.n_model_BR(t1) - r0.learning.pinf.n_model_BR(t1)) < 1e-15));
catch err
    R = add(R, nm, false, where(err));
end

nm = ['tf W4: variant 31 (ACD confidence): loadings model:projection = Cov(z, y)/Var(y) and std model:acd51 = a 51% ' ...
    'share of y in the 6-32 quarter band, by independent state-space formulas'];
try
    c = base;
    c.expectations.transforms = tf('wedge', 'types', 'all', 'scope', {{'c', 'inve', 'lab'}}, 'factor', ...
        struct('rho', 0.833, 'std', 'model:acd51', 'loadings', 'model:projection', 'shock', 'e_xi'));
    [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
    mv = info.nt.model_values;
    % loadings: the wedge-free RE limit (loadings 0)
    m0 = m;
    for z = {'c', 'inve', 'lab'}
        m0.(['tf1_lam__' z{1}]) = 0;
    end
    m0 = hetlearn.engine.solve_model(m0, spec);
    [V, xv] = state_cov(m0);
    iy = find(strcmp(xv, 'y'));
    dl = 0;
    lam = struct();
    for z = {'c', 'inve', 'lab'}
        iz = find(strcmp(xv, z{1}));
        lam.(z{1}) = V(iz, iy) / V(iy, iy);
        dl = max(dl, abs(lam.(z{1}) - m.(['tf1_lam__' z{1}])));
    end
    sh = band_shares(m, 'y', 2*pi/32, 2*pi/6);
    k = find(strcmp(cellstr(get(m, 'eList')), 'e_xi'));
    share = sh(k);
    ok = dl < 1e-8 && abs(share - 0.51) < 5e-3 && abs(mv.acd51.std - m.std_e_xi) < 1e-15;
    R = add(R, nm, ok, sprintf(['loadings c %.6f, inve %.6f, lab %.6f (independent diff %.2g); std %.6g; band share of ' ...
        'y from e_xi %.5f (target 0.51, IRIS acf with a band filter vs Simpson on the transfer function)'], ...
        lam.c, lam.inve, lam.lab, dl, m.std_e_xi, share));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = values(R, spec)
nm = ['tf V1: variant 18 (De Grauwe): g = model:sd_ygap_half = sd(y - yf)/2 of the RE limit (independent ' ...
    'Lyapunov), means +g/-g; equal OPT/PES shares give the model-consistent c expectation exactly'];
try
    c = br18(tsw07_a1_learn());
    c.expectations.transforms = [tf('wedge', 'types', {{'OPT'}}, 'factor', struct('mean', 'model:sd_ygap_half')), ...
        tf('wedge', 'types', {{'PES'}}, 'factor', struct('mean', '-model:sd_ygap_half'))];
    [m, info] = hetlearn.load_model(spec, hetlearn.load_options(c));
    [V, xv] = state_cov(m);
    iy = find(strcmp(xv, 'y'));
    iyf = find(strcmp(xv, 'yf'));
    g = sqrt(V(iy, iy) + V(iyf, iyf) - 2 * V(iy, iyf)) / 2;
    dg = abs(g - m.tf1_mu) / g + abs(m.tf2_mu + m.tf1_mu);
    % equal OPT/PES shares: c_exp1 = 0.5*(c{+1} + g) + 0.5*(c{+1} - g) = c{+1}, against OPT alone with mean 0
    a = m;
    a.n_RE_c = 0;
    a.n_OPT_c = 0.5;
    a.n_PES_c = 0.5;
    a = hetlearn.engine.solve_model(a, spec);
    a = sstate(a);
    b = m;
    b.n_RE_c = 0;
    b.n_OPT_c = 1;
    b.n_PES_c = 0;
    b.tf1_mu = 0;
    b = hetlearn.engine.solve_model(b, spec);
    b = sstate(b);
    d = irf_max(a, b, cellstr(get(a, 'xList')), cellstr(get(a, 'eList')));
    ssa = get(a, 'sstateLevel');
    ssb = get(b, 'sstateLevel');
    dss = max(abs(ssa.c_exp1 - ssb.c_exp1), abs(ssa.c - ssb.c));
    ok = dg < 1e-10 && d < 1e-12 && dss < 1e-12 && isfield(info.nt.model_values, 'sd_ygap_half');
    R = add(R, nm, ok, sprintf(['g %.6g (independent %.6g; sd(y - yf) %.4g); equal shares vs OPT alone with no bias: ' ...
        'IRFs %.3g, steady state %.3g'], m.tf1_mu, g, 2 * g, d, dss));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = errors(R, spec)
base = tsw07_a1_learn();
T = @(varargin) struct(varargin{:});
E = {};
% the two P4-boundary cases of phase P3 (variant 10 on the anchored baseline; anchored RE(t-1) agents
% with diagnostic memory states) load since phase P4 (2026-10-21): tests/test_anchor.m checks them
x = base;
x.expectations.re_info = 'current';
x.expectations.transforms = tf('diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', 'exclude', {flex()});
E(end+1, :) = {'variant 10 with anchored RE agents on period-t information (anchored reference not built)', x, ...
    'hetlearn:load_model:transforms'};
x = base;
x.expectations.transforms = tf('diagnostic', 'types', {{'BR'}}, 'value', 0.44, 'scope', 'learning');
E(end+1, :) = {'diagnostic on the learners', x, 'hetlearn:load_model:transforms'};
x = base;
x.expectations.transforms = tf('partial_adjustment', 'types', {{'BR'}}, 'value', 0.5, 'scope', 'learning');
E(end+1, :) = {'partial adjustment of the learners'' forecast', x, 'hetlearn:load_model:transforms'};
x = base;
x.expectations.re_variant = 'model_consistent';
x.expectations.transforms = {tf('multiplier', 'value', 0.9, 'scope', {{'c'}}), ...
    tf('diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', {{'c'}})};
E(end+1, :) = {'diagnostic after another transform', x, 'hetlearn:extend_model:transforms'};
x = base;
x.expectations.transforms = tf('wedge', 'scope', {{'pinf'}}, 'factor', struct('mean', 'model:foo'));
E(end+1, :) = {'unknown model rule', x, 'hetlearn:load_model:modelValue'};
x = br18(base);
x.expectations.transforms = tf('wedge', 'types', {{'OPT'}}, 'scope', {{'pinf'}}, 'factor', struct('mean', 0.1));
E(end+1, :) = {'a transform acting on nothing (OPT does not forecast pinf)', x, 'hetlearn:extend_model:transforms'};
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
R = add(R, sprintf('tf E1: %d settings outside phase P3 or malformed stop with their error', size(E, 1)), ...
    isempty(bad), strjoin(bad, ' | '));
clear T
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
sel = [1 2 4 5 6 7];
for q = 1:numel(sel)
    k = sel(q);
    tolP = 0;
    if cases{k, 3}
        tolP = 1e-10;
    end
    nm = sprintf(['tf R4%s: baseline run with %s = the two-type run (one RE filter: learning, state 1e-12, ' ...
        'paths %s; own filters: paths 1e-10, learning and state 1e-11)'], char('a' + q - 1), cases{k, 1}, ...
        ternary(cases{k, 3}, '1e-10', 'exact'));
    try
        b = a;
        b.expectations.transforms = cases{k, 2};
        [rb, Hb] = fresh_run(b);
        ra2 = hetlearn.run(a, 'save', false, 'quiet', true, 'model', Ma, 'filter', Hb);
        [d1, ~, e1] = compare_runs(ra2, rb, {'pinf'}, 'BR', setdiff(fieldnames(rb.paths), fieldnames(ra2.paths)));
        [d2, ~, e2] = compare_runs(ra, rb, {'pinf'}, 'BR', setdiff(fieldnames(rb.paths), fieldnames(ra.paths)));
        ok = isfinite(d1) && e1.learning <= 1e-12 && e1.state <= 1e-12 && e1.paths <= tolP ...
            && isfinite(d2) && e2.paths <= 1e-10 && e2.learning <= 1e-11 && e2.state <= 1e-11;
        R = add(R, nm, ok, sprintf(['one filter: paths %.3g, learning %.3g, state %.3g; own filters: paths %.3g, ' ...
            'learning %.3g, state %.3g; adds model variables %d; %d events'], e1.paths, e1.learning, e1.state, ...
            e2.paths, e2.learning, e2.state, cases{k, 3}, height(rb.events)));
    catch err
        R = add(R, nm, false, where(err));
    end
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


function E = pa_hand(vars, g)
% x_e = g*x{+1} + (1 - g)*x_e{-1}
E = struct('find', {}, 'repl', {}, 'decl', {}, 'eq', {});
for i = 1:numel(vars)
    x = vars{i};
    E(end+1) = struct('find', ['(?<![\w])' x '\{\+1\}'], 'repl', [x '_e'], 'decl', {{[x '_e']}}, ...
        'eq', {{sprintf('%s_e = %s*%s{+1} + (1 - %s)*%s_e{-1};', x, g, x, g, x)}}); %#ok<AGROW>
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


function [V, xv] = state_cov(m)
% unconditional covariance of the transition vector [xf; xb] of a solved linear model (doubling)
[T, R, ~, ~, ~, ~, ~, Omg] = sspace(m, 'triangular', false);
T = T(:, :, 1);
Omg = Omg(:, :, 1);
ne = size(Omg, 1);
R = R(:, 1:ne, 1);
nb = size(T, 2);
nf = size(T, 1) - nb;
Tb = T(nf+1:end, :);
Rb = R(nf+1:end, :);
Q = Rb * Omg * Rb';
S = Q;
A = Tb;
for it = 1:60
    S = S + A * S * A';
    A = A * A;
    if max(abs(A(:))) < 1e-30
        break
    end
end
V = T * S * T' + R * Omg * R';
xv = cellstr(get(m, 'xVector'));
end


function sh = band_shares(m, y, w1, w2)
% share of each shock in the variance of y at frequencies [w1, w2] (Simpson on the transfer function)
[T, R, ~, ~, ~, ~, ~, Omg] = sspace(m, 'triangular', false);
T = T(:, :, 1);
Omg = Omg(:, :, 1);
ne = size(Omg, 1);
R = R(:, 1:ne, 1);
nb = size(T, 2);
nf = size(T, 1) - nb;
Tb = T(nf+1:end, :);
Rb = R(nf+1:end, :);
iy = find(strcmp(cellstr(get(m, 'xVector')), y), 1);
n = 4000;
w = linspace(w1, w2, n + 1);
sw = [1, repmat([4 2], 1, n/2 - 1), 4, 1] * (w2 - w1) / (3 * n);
v = zeros(1, ne);
I = eye(nb);
for q = 1:numel(w)
    z = exp(-1i * w(q));
    H = T(iy, :) * z * ((I - Tb * z) \ Rb) + R(iy, :);
    v = v + sw(q) * abs(H).^2 .* diag(Omg)';
end
sh = v / sum(v);
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
