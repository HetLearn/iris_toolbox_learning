function varargout = kf(varargin)
%KF  Kalman-filter learning of the PLM coefficients (DESIGN_br_extensions 1.5, variant 25; phase P5).
%
%   Engine step (hetlearn.engine.update_learning, beliefs.update = 'kf' or a
%   type's update 'kf'; the interface of hetlearn.rls.sac):
%   [phi, R, S, ev] = hetlearn.rls.kf(phi, R, z, y, g, S, eq, bopts, gopts, t, ev)
%
%   Recursion and its pieces:
%   [phi, P, K] = hetlearn.rls.kf('step', phi, P, z, y, V, s2)
%   V           = hetlearn.rls.kf('V', gamma, s2, R0)
%   P0          = hetlearn.rls.kf('P0', gamma, s2, R0)
%   s2          = hetlearn.rls.kf('s2_re', phi0, R0, eq)
%   c           = hetlearn.rls.kf('constants', phi0, R0, eq, bopts, gopts)
%
%   The learners treat the PLM coefficients as a random walk (Slobodyan and
%   Wouters 2012): phi_t = phi_{t-1} + eta_t, Var(eta) = V, and y_t = z' phi_t
%   + v_t, Var(v) = s2. After x_t is realised:
%       P_pred = P_{t-1} + V
%       K      = P_pred z (z' P_pred z + s2)^{-1}
%       phi_t  = phi_{t-1} + K (y_t - z' phi_{t-1})
%       P_t    = P_pred - K z' P_pred
%   with the design's constant-gain-equivalent V and P_0 (*derived*; the
%   scalar steady-state gain is gamma):
%       V = gamma^2/(1 - gamma) * s2 * inv(R0),     P_0 = gamma * s2 * inv(R0)
%   R0 = E[z z'] of the initial beliefs (beliefs.init, the RE moments by
%   default); gamma = beliefs.kf.gamma, [] = gain.by_var.<x> where set, else
%   gain.value (variant 25: 0.031); s2 = beliefs.kf.s2: a number > 0, or
%   're_moments' = the PLM residual variance at the RE moments,
%   E[x^2] - phi0' R0 phi0, with E[x^2] read from R0 at the variable's own lag
%   (the RE moments are stationary). 're_moments' needs beliefs.init.method =
%   're_moments' and the own lag among the regressors (error hetlearn:rls:kfS2;
%   e.g. a mean-only PLM: set beliefs.kf.s2 to a number).
%
%   Two consequences (checked in tests/test_learning_rules.m):
%   - s2 cancels: P_pred and V are proportional to s2, so K and the beliefs do
%     not depend on it; it scales P only.
%   - With M = gamma s2 inv(P) the step is phi_t = phi_{t-1} + gamma M_t^{-1}
%     z (y_t - z' phi_{t-1}), M_t = (M_{t-1}^{-1} + gamma/(1 - gamma) R0^{-1})^{-1}
%     + gamma z z': the constant-gain RLS step (gain gamma, R_t = (1 - gamma)
%     R_{t-1} + gamma z z') whenever M_{t-1} = R0, as in the first update from
%     the initial beliefs. For z = 1 (mean-only PLM) M stays at R0 = 1, so KF
%     learning is constant-gain RLS with gain gamma in every period: the RLS
%     limit of the design (scalar steady-state gain gamma; from another P_0 the
%     scalar gain converges to gamma).
%
%   Engine state. S.R.<key> holds M_t = gamma s2 inv(P_t), the moment matrix
%   of the RLS form above, so M_0 = R0: the initial beliefs of
%   hetlearn.engine.state_init apply unchanged, the record's Rdiag stays a
%   second-moment diagonal, and the projection facility's keep and revert of
%   (phi, R) restore P too. S.kf.<key> = struct('gamma', 's2', 'V', 'R0') is
%   set at the first update of each PLM equation (key = its target,
%   <target>__<type> with N agent types). The gain rule's gain g of the period
%   is not used (gamma is fixed): the gain recorded for the period
%   (res.learning.<x>.gain) is still the gain rule's.
%
%   See also hetlearn.rls.update, hetlearn.rls.sac, hetlearn.engine.update_learning.

if ischar(varargin{1}) || isstring(varargin{1})
    switch char(varargin{1})
        case 'step'
            [varargout{1:3}] = kstep(varargin{2:end});
        case 'V'
            varargout{1} = drift(varargin{2:4});
        case 'P0'
            [gam, s2, R0] = varargin{2:4};
            varargout{1} = symm(gam * s2 * inv_spd(R0));
        case 's2_re'
            varargout{1} = s2_re(varargin{2:4});
        case 'constants'
            varargout{1} = constants(varargin{2:6});
        otherwise
            error('hetlearn:rls:call', 'Unknown call hetlearn.rls.kf(''%s'', ...).', char(varargin{1}));
    end
    return
end
[varargout{1:4}] = engine_step(varargin{:});
end


% =========================================================================
function [phi, R, S, ev] = engine_step(phi, R, z, y, ~, S, eq, bopts, gopts, ~, ev)
key = eq.target;
if ~isfield(S, 'kf') || ~isstruct(S.kf) || ~isfield(S.kf, key)
    S.kf.(key) = constants(phi, R, eq, bopts, gopts);      % first update: R = R0
end
c = S.kf.(key);
P = symm(c.gamma * c.s2 * inv_spd(R));
[phi, P] = kstep(phi, P, z, y, c.V, c.s2);
R = symm(c.gamma * c.s2 * inv_spd(P));
end


function [phi, P, K] = kstep(phi, P, z, y, V, s2)
phi = phi(:);
z = z(:);
Pp = P + V;
K = Pp * z / (z' * Pp * z + s2);
phi = phi + K * (y - z' * phi);
P = symm(Pp - K * (z' * Pp));
end


function c = constants(phi, R0, eq, bopts, gopts)
v = eq.target;
if isfield(eq, 'var') && ~isempty(eq.var)
    v = eq.var;
end
gam = [];
if isfield(bopts, 'kf') && isfield(bopts.kf, 'gamma')
    gam = bopts.kf.gamma;
end
src = 'beliefs.kf.gamma';
if isempty(gam)
    gam = gopts.value;
    src = 'gain.value';
    if isfield(gopts, 'by_var') && isstruct(gopts.by_var) && isfield(gopts.by_var, v)
        gam = gopts.by_var.(v);
        src = sprintf('gain.by_var.%s', v);
    end
end
if ~(isnumeric(gam) && isscalar(gam) && gam > 0 && gam < 1)
    error('hetlearn:rls:kfGamma', ['beliefs.update = ''kf'' (%s): the constant-gain equivalent gamma (%s = %s) ' ...
        'must lie in (0, 1).'], eq.target, src, mat2str(gam));
end
s2 = 're_moments';
if isfield(bopts, 'kf') && isfield(bopts.kf, 's2')
    s2 = bopts.kf.s2;
end
if ischar(s2) || isstring(s2)
    m = '';
    if isfield(bopts, 'init') && isfield(bopts.init, 'method')
        m = char(bopts.init.method);
    end
    if ~strcmp(m, 're_moments')
        error('hetlearn:rls:kfS2', ['beliefs.kf.s2 = ''re_moments'' reads the RE moments from the initial ' ...
            'beliefs, which come from beliefs.init.method = ''%s'' here (%s); set beliefs.kf.s2 to a number ' ...
            '(it scales P only: the beliefs do not depend on it).'], m, eq.target);
    end
    s2 = s2_re(phi, R0, eq);
end
c = struct('gamma', gam, 's2', double(s2), 'V', drift(gam, s2, R0), 'R0', R0);
end


function s2 = s2_re(phi0, R0, eq)
own = eq.target;
regs = eq.reg_names;
if isfield(eq, 'var') && ~isempty(eq.var)
    own = eq.var;
end
if isfield(eq, 'reg_vars') && ~isempty(eq.reg_vars)
    regs = eq.reg_vars;
end
j = find(strcmp(regs, own), 1);
if isempty(j)
    error('hetlearn:rls:kfS2', ['beliefs.kf.s2 = ''re_moments'' takes E[%s^2] from the initial moments at the ' ...
        'variable''s own lag, but the PLM of %s has no own lag; set beliefs.kf.s2 to a number (it scales P ' ...
        'only: the beliefs do not depend on it).'], own, eq.target);
end
jj = j + double(logical(eq.constant));
phi0 = phi0(:);
s2 = R0(jj, jj) - phi0' * R0 * phi0;
if ~(isfinite(s2) && s2 > 0)
    error('hetlearn:rls:kfS2', ['beliefs.kf.s2 = ''re_moments'': the PLM residual variance of %s at the RE ' ...
        'moments is %.6g, not positive; set beliefs.kf.s2 to a number.'], eq.target, s2);
end
end


function V = drift(gam, s2, R0)
V = symm(gam^2 / (1 - gam) * s2 * inv_spd(R0));
end


function X = inv_spd(A)
if ~all(isfinite(A(:))) || rcond(A) < 1e-14
    error('hetlearn:rls:kfSingular', 'Kalman-filter learning: a moment or covariance matrix is singular or not finite (rcond %.3g).', ...
        rcond_or_nan(A));
end
X = A \ eye(size(A, 1));
end


function r = rcond_or_nan(A)
r = NaN;
if all(isfinite(A(:)))
    r = rcond(A);
end
end


function A = symm(A)
A = (A + A') / 2;
end
