function db = history_db(o, H)
%HISTORY_DB  Databank the learners watch on the RE history (history.re_states, DESIGN 5.2, 19).
%
%   db = hetlearn.engine.history_db(opts, H)
%
%   Inputs
%     opts  merged options (hetlearn.load_options); reads history.re_states
%           and expectations.re_info
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
%
%   Lagged RE information (expectations.re_info = 'lagged', DESIGN 19):
%   <x>_exp1_RE_t = E_{t-1} x_{t+1} is a function of the period-(t-1) state.
%   Under 'filtered' the forecast made in t with data up to t-1 is then the
%   filter's one-step prediction E[<x>_exp1_RE_t | data up to t-1] =
%   E[x_{t+1} | data up to t-1] (H.predicted, written by hetlearn.re_filter
%   for lagged models), not x_{t|t}, which would use data dated t: every
%   <x>_exp1_RE series of db is taken from H.predicted. The learners' data and
%   the realised values stay x_{t|t}. Under 'smoothed' nothing changes.
%   Generalized anchor: the anchored diagnostic reference
%   <x>_DEg_RE (E_{t-1} x_{t+2}, a function of the t-1 state) is taken from
%   H.predicted as well, and the target of the 're_mean' types, <x>_feRE = x -
%   <x>_exp1_RE{-1}, is rebuilt from x_{t|t} and those predictions, so it is the
%   error of the RE forecast the history stage uses.

db = H.smooth;
if ~isfield(o, 'history') || ~isfield(o.history, 're_states') || ~strcmp(o.history.re_states, 'filtered')
    return
end
if ~isfield(H, 'filtered') || ~isstruct(H.filtered) || isempty(fieldnames(H.filtered))
    error('hetlearn:engine:history', ...
        ['history.re_states = ''filtered'' needs the filtered databank H.filtered of ' ...
        'hetlearn.re_filter.']);
end
db = H.filtered;
if ~(isfield(o, 'expectations') && isfield(o.expectations, 're_info') && strcmp(o.expectations.re_info, 'lagged'))
    return
end
if ~isfield(H, 'predicted') || ~isstruct(H.predicted) || isempty(fieldnames(H.predicted))
    error('hetlearn:engine:history', ...
        ['history.re_states = ''filtered'' with expectations.re_info = ''lagged'' needs the predictions ' ...
        'H.predicted of hetlearn.re_filter (filter of the lagged RE model).']);
end
f = fieldnames(db);
for i = 1:numel(f)
    if (endsWith(f{i}, '_exp1_RE') || endsWith(f{i}, '_DEg_RE')) && isfield(H.predicted, f{i})
        db.(f{i}) = H.predicted.(f{i});
    end
end
for i = 1:numel(f)
    if endsWith(f{i}, '_feRE')
        x = f{i}(1:end-5);
        if isfield(db, x) && isfield(db, [x '_exp1_RE'])
            db.(f{i}) = db.(x) - db.([x '_exp1_RE']){-1};
        end
    end
end
end
