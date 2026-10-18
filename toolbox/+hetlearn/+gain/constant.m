function varargout = constant(cmd, varargin)
%CONSTANT  Constant-gain rule (DESIGN 4.3); reference for the gain-rule interface (DESIGN 18).
%
%   f            = hetlearn.gain.constant('fields')                  % {}
%   gstate       = hetlearn.gain.constant('init', sys, learnVars, gopts)
%   g            = hetlearn.gain.constant('gain', gstate, errors, gopts)
%   [gstate, ev] = hetlearn.gain.constant('update', gstate, errors, gopts)
%   g            = hetlearn.gain.constant(state, opts)   % earlier per-equation form
%
%   Interface of every gain rule hetlearn.gain.<rule> (gain.rule):
%     'fields'  cellstr of extra per-equation series the rule records; each
%               is read from gstate.rec.<field>.<target> at the end of every
%               period (hetlearn.engine.record) and appears as
%               res.learning.<target>.<field> and in learning.csv. {} here.
%     'init'    initial gain state. The engine keeps it in the learning state
%               S.gain (hetlearn.engine.state_init), so everything that
%               carries S carries it: the history stage, the inversion
%               history and its snapshots, the forecast stage, density draws
%               (each starts from the origin state), hetlearn.evaluate
%               origins and the Ramsey loss continuation.
%     'gain'    called by hetlearn.engine.update_learning once per period
%               (beliefs.update = 'rls'), after x_t is realised and before
%               the RLS updates: the gain of each equation's update in t.
%     'update'  called after the RLS and projection step of the same
%               period (a separate block of update_learning): the gain state
%               at the end of t, whatever the projection facility did.
%
%   Inputs
%     gstate  gain state S.gain
%     errors  struct, the same in both calls: .t (IRIS date), .first (true
%             in the first learning period), .targets (cellstr, PLM targets
%             in sys.eq order), .rls.<target> (signed one-step PLM residual
%             v_t - phi_{t-1}' z_{t-1}; NaN when data are missing),
%             .forecast.<x> (signed BR expectation error x_t - f^BR_{t-1} of
%             each learning variable; NaN in the first period),
%             .fe_hist.<target> (past residuals, oldest first, up to t),
%             .phi_hist.<target> (k x (t-1) past coefficient vectors)
%     gopts   the gain options subtree (opts.gain): .rule, .value, .by_var,
%             .koz
%
%   Outputs
%     g       struct by PLM target: the gain of this period's RLS update,
%             here gopts.by_var.<target> if present, else gopts.value
%     gstate  gain state at the end of t (unchanged here)
%     ev      events (struct array date, type, variable, detail; none here)

if isstruct(cmd)                    % earlier per-equation interface g = constant(state, opts)
    opts = varargin{1};
    g = opts.value;
    if isfield(opts, 'by_var') && isstruct(opts.by_var) && isfield(cmd, 'target') ...
            && isfield(opts.by_var, cmd.target)
        g = opts.by_var.(cmd.target);
    end
    varargout{1} = g;
    return
end
switch char(cmd)
    case 'fields'
        varargout{1} = {};
    case 'init'
        varargout{1} = struct('rule', 'constant');
    case 'gain'
        errors = varargin{2};
        opts = varargin{3};
        g = struct();
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            v = opts.value;
            if isfield(opts, 'by_var') && isstruct(opts.by_var) && isfield(opts.by_var, tg)
                v = opts.by_var.(tg);
            end
            g.(tg) = v;
        end
        varargout{1} = g;
    case 'update'
        varargout = {varargin{1}, struct('date', {}, 'type', {}, 'variable', {}, 'detail', {})};
    otherwise
        error('hetlearn:gain:call', 'Unknown call hetlearn.gain.constant(''%s'', ...).', char(cmd));
end
end
