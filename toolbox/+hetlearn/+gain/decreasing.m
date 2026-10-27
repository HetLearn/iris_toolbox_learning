function varargout = decreasing(cmd, varargin)
%DECREASING  Decreasing gain g_t = 1/(t0 + t): recursive least squares with equal weights on all data.
%
%   f            = hetlearn.gain.decreasing('fields')                     % {}
%   gstate       = hetlearn.gain.decreasing('init', sys, learnVars, gopts)
%   g            = hetlearn.gain.decreasing('gain', gstate, errors, gopts)
%   [gstate, ev] = hetlearn.gain.decreasing('update', gstate, errors, gopts)
%
%   The gain of the k-th update of a PLM equation (k = 1 in the first
%   learning quarter, beliefs.init.date) is
%       g = 1 / (t0 + t),    t = k + 1,    t0 = gain.decreasing.t0 >= 0 (default 0).
%   t counts the observations the beliefs rest on, the initial beliefs being
%   the first. The first update therefore has gain 1/(t0 + 2): it weights the
%   initial beliefs and the first data point equally when t0 = 0, and the
%   moment matrix R stays invertible for a PLM with several coefficients. A
%   larger t0 gives the initial beliefs the weight of t0 + 1 observations.
%   With a constant-only PLM the belief is the running mean of the data and
%   the initial value; with an AR(1) it is the recursive least-squares
%   estimate (Evans and Honkapohja 2001, ch. 2).
%
%   Counting: the count of an equation moves in 'update' only when its
%   residual was observed in t (errors.rls.<target> finite). A quarter with
%   missing data (event 'rls_missing', no update) does not count. As every
%   gain state, the count moves whatever the projection facility did with the
%   candidate beliefs, and it carries on from the history into the forecast,
%   density draws and evaluation origins. gain.value and gain.by_var are not
%   used by this rule.
%
%   Interface of hetlearn.gain.constant (see there for the errors and the timing).
%
%   gstate  struct: .rule ('decreasing'), .count.<target> (updates so far)
%
%   See also hetlearn.gain.constant, hetlearn.gain.koz.

switch char(cmd)
    case 'fields'
        varargout{1} = {};
    case 'init'
        sys = varargin{1};
        G = struct('rule', 'decreasing', 'count', struct());
        if isstruct(sys) && isfield(sys, 'eq')
            for i = 1:numel(sys.eq)
                G.count.(sys.eq(i).target) = 0;
            end
        end
        varargout{1} = G;
    case 'gain'
        G = varargin{1};
        errors = varargin{2};
        t0 = offset(varargin{3});
        g = struct();
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            g.(tg) = 1 / (t0 + count_of(G, tg) + 2);
        end
        varargout{1} = g;
    case 'update'
        G = varargin{1};
        errors = varargin{2};
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            if isfield(errors, 'rls') && isfield(errors.rls, tg) && isfinite(errors.rls.(tg))
                G.count.(tg) = count_of(G, tg) + 1;
            end
        end
        varargout = {G, struct('date', {}, 'type', {}, 'variable', {}, 'detail', {})};
    otherwise
        error('hetlearn:gain:call', 'Unknown call hetlearn.gain.decreasing(''%s'', ...).', char(cmd));
end
end


function c = count_of(G, tg)
c = 0;
if isfield(G, 'count') && isfield(G.count, tg)
    c = G.count.(tg);
end
end


function t0 = offset(gopts)
t0 = 0;
if isstruct(gopts) && isfield(gopts, 'decreasing') && isfield(gopts.decreasing, 't0')
    t0 = double(gopts.decreasing.t0);
end
end
