function db = history_db(o, H)
%HISTORY_DB  Databank the learners watch on the RE history (history.re_states, DESIGN 5.2).
%
%   db = hetlearn.engine.history_db(opts, H)
%
%   Inputs
%     opts  merged options (hetlearn.load_options); reads history.re_states
%     H     RE filter output (hetlearn.re_filter)
%
%   Output
%     db    H.smooth for history.re_states = 'smoothed' (default; the
%           two-sided Kalman smoother, data over the whole filter range) or
%           H.filtered for 'filtered' (the one-sided filter, x_{t|t}: data up
%           to t only). Used for the RE agents' forecasts <x>_exp1_RE(t), the
%           learners' data and the realised x_t of the fitness errors in the
%           history stage (hetlearn.engine.history, mode 're_smoother'), and
%           for beliefs.init.method = 'training_ols'
%           (hetlearn.engine.state_init). The forecast stage always starts
%           from H.smooth (hetlearn.engine.build_shocks).

db = H.smooth;
if ~isfield(o, 'history') || ~isfield(o.history, 're_states') || ~strcmp(o.history.re_states, 'filtered')
    return
end
if ~isfield(H, 'filtered') || ~isstruct(H.filtered) || isempty(fieldnames(H.filtered))
    error('hetlearn:engine:history', ...
        ['history.re_states = ''filtered'' needs the filtered databank H.filtered of ' ...
        'hetlearn.re_filter (written since 2026-10-19).']);
end
db = H.filtered;
end
