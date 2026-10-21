function varargout = sac(varargin)
%SAC  Sample-autocorrelation (SAC) learning on the AR(1) PLM (DESIGN_br_extensions 1.5, variant 20; phase P5).
%
%   Engine step (hetlearn.engine.update_learning, beliefs.update = 'sac' or a
%   type's update 'sac'; the interface of hetlearn.rls.kf):
%   [phi, R, S, ev] = hetlearn.rls.sac(phi, R, z, y, g, S, eq, bopts, gopts, t, ev)
%
%   Recursion and conversions:
%   [s, flag] = hetlearn.rls.sac('step', s, x, xlag, g)       % the engine's recursion
%   [s, flag] = hetlearn.rls.sac('step', s, x, xlag, g, x0)   % with the finite-sample terms
%   [phi, R]  = hetlearn.rls.sac('to_plm', s)
%   s         = hetlearn.rls.sac('from_plm', phi, R)
%
%   SAC learners (Hommes and Sorger 1998; Hommes, Mavromatis, Ozden and Zhu
%   2023, HMOZ) forecast with x_t = a + b (x_{t-1} - a): the sample mean a,
%   the first-order sample autocorrelation b and the variance R of x
%   (s = struct('a', a, 'b', b, 'R', R)). After x_t is realised, with the gain
%   g of the period (gain.rule; variant 20: 'constant', 0.006):
%       e = x_t - a_{t-1},   u = x_{t-1} - a_{t-1}
%       a_t = a_{t-1} + g e
%       R_t = R_{t-1} + g (e^2 - R_{t-1})
%       b_t = b_{t-1} + g R_t^{-1} (e u - b_{t-1} e^2)
%   (HMOZ eq. 2.8 with 1/(t+1) -> g, finite-sample terms dropped), b_t clipped
%   to [-1, 1]. flag '' or: 'upper'/'lower' (b_t clipped to 1/-1), 'variance'
%   (R_t not > 0, or b_t not finite: b kept at b_{t-1}).
%
%   With x0 (the first observation of the sample) the step keeps the
%   finite-sample terms:
%       R_t = R_{t-1} + g ((1 - g) e^2 - R_{t-1})
%       b_t = b_{t-1} + g R_t^{-1} (e u - b_{t-1} (1 - g) e^2 + g e (x0 - a_t))
%   With g = 1/(t+1) from t = 1 and a_0 = x0, R_0 = 0, b_0 = 0 these are the
%   batch moments of x_0..x_t (HMOZ eq. 2.6): the sample mean, the variance
%   (1/(t+1)) sum (x_i - a_t)^2 and the sample autocorrelation
%   sum_{i<t} (x_i - a_t)(x_{i+1} - a_t) / sum (x_i - a_t)^2 (*derived*; the
%   batch identity of tests/test_learning_rules.m). Without x0 and with
%   g = 1/(t+1), (t+1) R_t = sum e_i^2 and (t+1) b_t R_t = sum e_i u_i: the same
%   moments of the deviations from the running mean, which differ from HMOZ
%   2.6 by terms of order 1/t. The engine uses the form without x0 for every
%   gain rule, as the design specifies.
%
%   Engine form. (a, b, R) live in the AR(1) PLM state: phi = [a (1 - b); b]
%   (alpha and beta of the PLM, so the generated forecast alpha + beta (alpha +
%   beta x_{t-1}) = a + b^2 (x_{t-1} - a) is unchanged) and
%   R = [1, a; a, a^2 + R], the second-moment matrix of z = [1; x_{t-1}] that
%   the mean and the variance imply. The initial beliefs of
%   hetlearn.init.re_moments have this form (a the steady-state mean, b the RE
%   autocorrelation, R the RE variance), the record's Rdiag keeps its meaning,
%   and the projection facility's keep and revert of (phi, R) restore (a, b, R).
%   The PLM must be an AR(1) with a constant on the variable's own first lag
%   (beliefs.plm 'ar1'; error hetlearn:rls:sacPlm otherwise). A clipped or kept
%   b gives event 'sac_bound' (variable = the PLM target). S, bopts and gopts
%   are not used (common interface with hetlearn.rls.kf).
%
%   See also hetlearn.rls.update, hetlearn.rls.kf, hetlearn.engine.update_learning.

if ischar(varargin{1}) || isstring(varargin{1})
    switch char(varargin{1})
        case 'step'
            [varargout{1:2}] = step(varargin{2:end});
        case 'to_plm'
            [varargout{1:2}] = to_plm(varargin{2});
        case 'from_plm'
            varargout{1} = from_plm(varargin{2:3});
        otherwise
            error('hetlearn:rls:call', 'Unknown call hetlearn.rls.sac(''%s'', ...).', char(varargin{1}));
    end
    return
end
[varargout{1:4}] = engine_step(varargin{:});
end


% =========================================================================
function [phi, R, S, ev] = engine_step(phi, R, z, y, g, S, eq, ~, ~, t, ev)
check_plm(eq);
z = z(:);
s = from_plm(phi, R);
[s, flag, braw] = step(s, y, z(2), g);
if ~isempty(flag)
    if strcmp(flag, 'variance')
        det = sprintf(['variance R_t = %.6g not positive or b_t = %.6g not finite (gain %.6g); ' ...
            'autocorrelation kept at %.6g'], s.R, braw, g, s.b);
    else
        det = sprintf('autocorrelation b_t = %.6g outside [-1, 1] (gain %.6g); set to %g (mean %.6g, variance %.6g)', ...
            braw, g, s.b, s.a, s.R);
    end
    ev(end+1) = struct('date', double(t), 'type', 'sac_bound', 'variable', eq.target, 'detail', det);
end
[phi, R] = to_plm(s);
end


function [s, flag, braw] = step(s, x, xlag, g, x0)
exact = nargin >= 5 && ~isempty(x0);
a0 = s.a;
b0 = s.b;
R0 = s.R;
e = x - a0;
u = xlag - a0;
a = a0 + g * e;
if exact
    R = R0 + g * ((1 - g) * e^2 - R0);
    br = e * u - b0 * (1 - g) * e^2 + g * e * (x0 - a);
else
    R = R0 + g * (e^2 - R0);
    br = e * u - b0 * e^2;
end
b = b0 + g * (br / R);
braw = b;
flag = '';
if ~(R > 0) || ~isfinite(b)
    b = b0;
    flag = 'variance';
elseif b > 1
    b = 1;
    flag = 'upper';
elseif b < -1
    b = -1;
    flag = 'lower';
end
s.a = a;
s.b = b;
s.R = R;
end


function [phi, R] = to_plm(s)
phi = [s.a * (1 - s.b); s.b];
R = [1, s.a; s.a, s.a^2 + s.R];
end


function s = from_plm(phi, R)
r11 = R(1, 1);
a = R(1, 2) / r11;
s = struct('a', a, 'b', phi(2), 'R', R(2, 2) / r11 - a^2);
end


function check_plm(eq)
own = eq.target;
regs = eq.reg_names;
if isfield(eq, 'var') && ~isempty(eq.var)
    own = eq.var;               % keyed system of N agent types: target <x>__<type>
end
if isfield(eq, 'reg_vars') && ~isempty(eq.reg_vars)
    regs = eq.reg_vars;
end
if logical(eq.constant) && numel(regs) == 1 && strcmp(regs{1}, own) && isequal(eq.reg_lags, 1)
    return
end
if isempty(regs)
    what = 'no regressors';
else
    what = strjoin(cellfun(@(r, l) sprintf('%s{-%d}', r, l), regs, num2cell(eq.reg_lags), ...
        'UniformOutput', false), ', ');
end
error('hetlearn:rls:sacPlm', ['beliefs.update = ''sac'' learns the mean and the first-order autocorrelation of ' ...
    'an AR(1) PLM with a constant on the own first lag (beliefs.plm ''ar1''); the PLM of %s has %s%s.'], ...
    eq.target, what, ternary(logical(eq.constant), ' and a constant', ' and no constant'));
end


function s = ternary(c, a, b)
if c
    s = a;
else
    s = b;
end
end
