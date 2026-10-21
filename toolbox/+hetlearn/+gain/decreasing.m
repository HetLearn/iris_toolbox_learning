function varargout = decreasing(cmd, varargin)
%DECREASING  Decreasing gain g = 1/(t - t0 + n0): sample-mean learning (DESIGN_br_extensions 1.5, phase P5).
%
%   f            = hetlearn.gain.decreasing('fields')                     % {}
%   gstate       = hetlearn.gain.decreasing('init', sys, learnVars, gopts)
%   g            = hetlearn.gain.decreasing('gain', gstate, errors, gopts)
%   [gstate, ev] = hetlearn.gain.decreasing('update', gstate, errors, gopts)
%
%   The gain of the k-th update of a PLM equation (k = 1, 2, ...) is
%       g = 1 / (k - 1 + n0),        n0 = gain.decreasing.n0 >= 1 (default 1).
%   The engine updates every quarter from t0 = beliefs.init.date, so this is
%   g_t = 1/(t - t0 + n0) of the design. With n0 = 1 the first update has gain
%   1: RLS on a constant then gives the running sample mean of the data from
%   t0 (the LAA anchor of Anufriev and Hommes, variant 17), and RLS on an AR(1)
%   the recursive least-squares estimate. n0 > 1 gives the initial belief the
%   weight of n0 - 1 observations (e.g. n0 = t0 + 1 after an OLS fit on t0
%   observations continues as the gain 1/t of full-sample OLS).
%
%   Counting: the count of an equation moves in 'update' only when its residual
%   was observed in t (errors.rls.<target> finite). A quarter with missing data
%   (event 'rls_missing', no RLS update) does not count, so a mean-only belief
%   stays the sample mean of the data seen. As every gain state, the count moves
%   whatever the projection facility did with the candidates (DESIGN 18).
%   gain.value and gain.by_var are not used by this rule.
%
%   Interface of hetlearn.gain.constant (see there for errors and the timing).
%
%   gstate  struct: .rule ('decreasing'), .count.<target> (updates so far)

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
        n0 = start_weight(varargin{3});
        g = struct();
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            g.(tg) = 1 / (count_of(G, tg) + n0);
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


function n0 = start_weight(gopts)
n0 = 1;
if isstruct(gopts) && isfield(gopts, 'decreasing') && isfield(gopts.decreasing, 'n0')
    n0 = double(gopts.decreasing.n0);
end
end
