function R = test_anchor(part)
%TEST_ANCHOR  Generalized anchor (docs/USER_GUIDE.md section 7.5; rules 10 and 23 of the portfolio).
%
%   R = test_anchor()        every part
%   R = test_anchor(part)    'gate' | 'de' | 'io'
%
%   3 checks. A2-A4, A7 and A8 and the level part of A1 were removed with the
%   features they tested; the labels are unchanged.
%   A1  fixed-point gate: hetlearn.anchor_coefficients on the anchored RE(t-1)
%       limit of the SW07 test baseline (tsw07_a1_learn) returns the model's own
%       anchored coefficients (1e-12; its unit check 1e-9)
%   A5  anchored DE = model-consistent DE at n_RE = 1 (variant 10 on the anchored
%       baseline): the load check (IRFs, every shock, 1e-10), an independent IRF
%       comparison with the model-consistent load (1e-10), and nonzero anchored
%       coefficients on the memory states c_REt2, ... and on pinf_DEg_RE{-1}
%   A6  variant 23 with abar fixed at 0 ('user' initial belief, beliefs.update =
%       'fixed', which the re_mean type follows): the IO forecast equals the RE
%       forecast in every quarter (1e-14), shares stay at 0.5 and the run equals the
%       RE(t-1) run tsw07_a1_re (paths 1e-10)
%
%   Runs are not saved. About 1 minute; the first call generates the model files.

if nargin < 1 || isempty(part)
    part = {'gate', 'de', 'io'};
end
part = cellstr(part);
here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'scenarios'));
R = struct('name', {}, 'pass', {}, 'msg', {});
if any(strcmp(part, 'gate'))
    R = gate(R);
end
if any(strcmp(part, 'de'))
    R = de(R);
end
if any(strcmp(part, 'io'))
    R = io(R);
end
end


% =========================================================================================
function T = ty(varargin)
T = struct(varargin{:});
end


function R = gate(R)
nm = ['an A1: fixed-point gate: anchor_coefficients on the anchored RE(t-1) limit = its own anchored ' ...
    'coefficients (1e-12)'];
try
    c = tsw07_a1_learn();
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    [m, info] = hetlearn.load_model(spec, o);
    st = info.meta.re_states;
    pn = hetlearn.plm.anchor_names('pinf', st);
    pv = get(m, 'parameters');
    are = cellfun(@(n) pv.(n), pn)';
    [Rc, ic] = hetlearn.anchor_coefficients(m, {'pinf'}, st, 'lag', 1, 'check', true);
    d1 = max(abs([Rc.k; Rc.C(:)] - are) ./ max(1, abs(are)));
    ok = d1 < 1e-12 && ic.check_maxdiff < 1e-9;
    R = add(R, nm, ok, sprintf(['anchored limit vs its coefficients %.3g (unit check %.3g; max relative ' ...
        'difference over %d coefficients)'], d1, ic.check_maxdiff, numel(are)));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = de(R)
nm = ['an A5: anchored DE = model-consistent DE at n_RE = 1 (variant 10 on the anchored baseline): load check ' ...
    'and independent IRFs (1e-10); the anchored expression loads on the memory states and pinf_DEg_RE{-1}'];
try
    c = tsw07_a1_learn();
    c.expectations.transforms = struct('kind', 'diagnostic', 'types', {{'RE'}}, 'value', 0.44, 'scope', 'all', ...
        'exclude', {{'invef', 'pkf', 'rkf', 'cf', 'labf'}});
    o = hetlearn.load_options(c);
    spec = hetlearn.load_spec(o.model);
    [ma, ia] = hetlearn.load_model(spec, o);
    k1 = ia.re_info_check.anchored_vs_mc_maxdiff;
    c2 = c;
    c2.expectations.re_variant = 'model_consistent';
    [mm, ~] = hetlearn.load_model(spec, hetlearn.load_options(c2));
    el = cellstr(get(mm, 'eList'));
    sa = srf(ma, 1:40, 'select', el);
    sm = srf(mm, 1:40, 'select', el);
    d = 0;
    for v = {'pinf', 'y', 'r', 'c', 'inve', 'w', 'lab', 'pinf_exp1'}
        e = abs(sa.(v{1})(1:40, :) - sm.(v{1})(1:40, :));
        e(isnan(e)) = Inf;
        d = max([d; e(:)]);
    end
    pv = get(ma, 'parameters');
    xs = ia.meta.anchor_xstates.pinf;
    pn = ia.meta.anchor_params.pinf;
    ex = xs(numel(ia.meta.re_states) + 1:end);
    ce = cellfun(@(s) pv.(pn{1 + find(strcmp(xs, s), 1)}), ex);
    cmem = max(abs(ce(~strcmp(ex, 'pinf_DEg_RE'))));
    cdeg = abs(ce(strcmp(ex, 'pinf_DEg_RE')));
    ok = k1 < 1e-10 && d < 1e-10 && cmem > 1e-6 && ~isempty(cdeg) && cdeg > 1e-6 && ia.meta.generator_version >= 7;
    R = add(R, nm, ok, sprintf(['load check %.3g; independent IRFs %.3g; %d extra anchored terms (%s), largest ' ...
        'memory coefficient %.4g, on pinf_DEg_RE{-1} %.4g'], k1, d, numel(ex), strjoin(ex, ', '), cmem, cdeg));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function R = io(R)
nm = ['an A6: variant 23 with abar fixed at 0 (types RE and IO): the IO forecast = the RE forecast in every ' ...
    'quarter, shares stay at 0.5, the run = the RE(t-1) run tsw07_a1_re (paths 1e-10)'];
try
    rr = hetlearn.run(tsw07_a1_re(), 'save', false, 'quiet', true);
    c = tsw07_a1_learn();
    c.expectations.types = {ty('name', 'RE', 'kind', 're'), ty('name', 'IO', 'kind', 're_mean')};
    c.beliefs.update = 'fixed';                % the re_mean type follows beliefs.update (no per-type override)
    c.beliefs.init.method = 'user';
    c.beliefs.init.values = struct('pinf_feRE', struct('alpha', 0));
    rc = hetlearn.run(c, 'save', false, 'quiet', true);
    L = rc.learning.pinf;
    rd = rc.dates.record;
    df = maxabs(L.f_IO(rd) - L.f_RE(rd));
    ab = maxabs(rc.learning.pinf_feRE__IO.alpha_pinf_feRE__IO(rd));
    dn = maxabs(L.n_IO(rd) - 0.5);
    dp = 0;
    for v = {'pinfobs', 'dy', 'robs', 'dc', 'pinf', 'y', 'pinf_exp1'}
        dp = max(dp, sdiff(rr.paths.(v{1}), rc.paths.(v{1})));
    end
    % IRIS solves pinf_exp1_IO on its own row of the forecast-stage model: rounding (about 2e-15)
    ok = df < 1e-14 && ab == 0 && dn < 1e-15 && dp <= 1e-10;
    R = add(R, nm, ok, sprintf('IO vs RE forecasts %.3g, max |abar| %.3g, shares - 0.5 %.3g; paths vs tsw07_a1_re %.3g', ...
        df, ab, dn, dp));
catch err
    R = add(R, nm, false, where(err));
end
end


% =========================================================================================
function v = sdiff(a, b)
% max abs difference of two Series on the dates of either (NaN in one only counts as Inf)
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


function s = where(err)
s = err.message;
if ~isempty(err.stack)
    s = sprintf('%s (%s, line %d)', s, err.stack(1).name, err.stack(1).line);
end
end


function R = add(R, name, pass, msg)
R(end+1) = struct('name', name, 'pass', logical(pass), 'msg', msg);
end
