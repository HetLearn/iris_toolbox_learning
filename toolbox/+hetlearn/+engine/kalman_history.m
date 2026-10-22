function varargout = kalman_history(varargin)
%KALMAN_HISTORY  History stage of history.mode = 'kalman': time-varying Kalman filter of the ALM (DESIGN_br_extensions 5).
%
%   [S, rec, ev, dK, hinfo] = hetlearn.engine.kalman_history(ctx, S, H, rec, m)
%   hetlearn.engine.kalman_history('write', res, outDir)        kalman_errors.csv
%   T = hetlearn.engine.kalman_history('rmse', res)              one-step RMSE table
%   T = hetlearn.engine.kalman_history('rmse', res, subsamples)
%
%   Called by hetlearn.engine.core in place of hetlearn.engine.history when
%   history.mode = 'kalman' (feature E6). It generalises hlest.loglik_learn (one
%   configuration, its own solver) to any configuration: the ALM is solved by
%   the engine's facility, beliefs and shares move with the unchanged
%   hetlearn.engine.update_learning.
%
%   Inputs (as hetlearn.engine.history)
%     ctx  engine context after hetlearn.engine.state_init (.opts, .spec,
%          .info, .sys, .learnVars, .groups, .groupOf, .init_date, .origin;
%          .blocks optional)
%     S    initial state (hetlearn.engine.state_init)
%     H    RE filter output (hetlearn.re_filter): .range, .data (the
%          observables), .smooth (start state under 'smoothed')
%     rec  allocated record (hetlearn.engine.record)
%     m    loaded model (hetlearn.load_model), the forecast model
%
%   Quarter t = start .. origin (start = H.range(1); beliefs.init.date under
%   history.kalman.init = 'smoothed'):
%   (1) the ALM in force in t: belief parameters phi_{t-1} and the model
%       shares of hetlearn.engine.shares_for_mode (before beliefs.init.date
%       the variant's RE limit, n1_<x> = 1), assigned and solved through
%       hetlearn.engine.facility('solve', ..., 'kalman') unless they equal
%       those of the last solve or ALM check; its state space on the full
%       transition vector x = [xf; xb] (xf rows load on xb_{t-1} only):
%         x_t = A x_{t-1} + K + R e_t,   y_t = Z x_t + H e_t + D,   Cov(e) = Omg
%       (a backward system of hetlearn.engine.solve_model is used the same way)
%   (2) prediction a_{t|t-1}, P_{t|t-1}; predictions y_{t|t-1} of every
%       measurement variable and their covariance F_t; with data (rows without
%       data dropped) the log density l_t = -(n_t log(2 pi) + log det F_t +
%       v_t' F_t^-1 v_t)/2, v_t = y_t - y_{t|t-1}, and the update a_{t|t},
%       P_{t|t}, e_{t|t}; a quarter without data (2020Q1-Q3) is a prediction
%       only, l_t = 0
%   (3) agents' information (from beliefs.init.date): RE forecasts made in t
%       with data to t-1 (expectations.re_info = 'lagged') are the predictions
%       <x>_exp1_RE_{t|t-1}, with period-t data ('current') the filtered
%       <x>_exp1_RE_{t|t}; the learners' PLM forecasts (hetlearn.plm.
%       forecast_value with phi_{t-1}), their regressors and the realised
%       values are the filtered values x_{s|s} stored in real time (each
%       quarter's own update, not revised later)
%   (4) hetlearn.engine.update_learning, unchanged, with the ALM check of the
%       model in force in t+1 under projection.facility 'alm' | 'plm_alm';
%       first = true at beliefs.init.date
%   N agent types and forecast transforms (ctx.nt; docs/DESIGN_br_extensions.md
%   1.1-1.5, phase P6): the ALM in force has the share vectors of
%   hetlearn.engine.shares_for_mode (before beliefs.init.date share 1 on the
%   RE type). Every type's forecast made in t comes from
%   hetlearn.engine.ntypes('forecasts', ..., 'history', t) on the agents'
%   data, the real-time filtered values x_{s|s}, except that with
%   expectations.re_info = 'lagged' every <x>_exp1_RE and <x>_DEg_RE is the
%   prediction x_{t|t-1} (as hetlearn.engine.history_db takes them from
%   H.predicted under history.re_states = 'filtered'), and the target of a
%   're_mean' type, <x>_feRE = x - <x>_exp1_RE{-1}, is rebuilt from x_{t|t}
%   and the RE forecast of t-1 in that data, so it is the error of the RE
%   forecast the agents used. PLM, rule and re_mean types are then evaluated
%   as in the RE-smoother history, transforms as there. update_learning
%   takes its N-type path. The forecast stage starts from the filtered state
%   at the origin (D12), except for what hetlearn.engine.ntypes('seed')
%   writes there: with a 're_mean' type, <x>_exp1_RE at the origin (the
%   forecast the agents used). history.mode = 'kalman' with N types and
%   transforms needs nothing else.
%   Initial condition (history.kalman.init): 'stochastic' (default) the
%   asymptotic mean and covariance of the ALM of the first quarter (the RE
%   limit), as IRIS filter does; an error if it has a root on or outside the
%   unit circle. 'smoothed': the filter starts at beliefs.init.date from the
%   RE-smoothed state (H.smooth) of the quarter before with P = 0, and the
%   agents' data before it are RE-smoothed, as in history.mode = 'inversion'.
%   With as many shocks as observables and no measurement error the update is
%   then exact and the filter equals the inversion until a quarter without
%   data. Under projection.facility = 'none' a quarter without a model
%   solution stops the run (hetlearn:engine:noSolution, stage 'kalman', with
%   its date). history.learn = false and history.re_states = 'filtered' are
%   errors.
%
%   Outputs
%     S, rec, ev  as hetlearn.engine.history: state at the end of the origin;
%                 record of beliefs.init.date .. origin, with the model shares
%                 in force (n1_model); events
%     dK     databank over [hinfo.db_start, origin] of every transition and
%            measurement variable and shock: x_{t|t}, y_{t|t} (the data where
%            observed) and e_{t|t} of each quarter, except that the lags of the
%            state vector at the origin (elements v{-k}) take their values in
%            a_{origin|origin}, so the forecast stage, which hetlearn.engine.core
%            starts from this databank, starts from the filtered state at the
%            origin (D12)
%     hinfo  .alm_check_s, .alm_n_check, .alm_n_solve, .warm (as
%            hetlearn.engine.history), .start, .db_start, .origin, .n_solve,
%            .runtime_s, .kalman (returned by hetlearn.run as res.kalman):
%              .init, .start, .origin, .dates (filter quarters), .loglik_start
%              (beliefs.init.date), .observables (measurement variables), .y
%              (data, NaN = missing), .pred (y_{t|t-1}), .err (y_t - y_{t|t-1},
%              NaN without data), .F (ny x ny x T, covariance of the prediction
%              errors of all measurement variables), .llt (l_t, 0 without data),
%              .n_obs, .loglik (sum of l_t from loglik_start), .filtered and
%              .predicted (databanks over .dates: x_{t|t}, y_{t|t}, e_{t|t};
%              x_{t|t-1}, y_{t|t-1}), .state_names (elements of x), .a_origin,
%              .P_origin, .n_solve, .runtime_s, .fbr_model_maxdiff (max |PLM
%              forecast on the real-time data - the model's <x>_exp1_BR,
%              predicted under beliefs.info 'lagged', filtered under 'current'|;
%              rounding for a PLM whose forecast uses data of one date only,
%              such as AR(1); with N types the max over the 'plm' types),
%              .ftypes_model_maxdiff (N types only: struct by type name of
%              the same difference for every 'plm', 'rule' and 're_mean'
%              type, the type's forecast before the transforms
%              against the model's <x>_exp1_<type>, predicted for a type with
%              information up to t-1, filtered for period-t information; it
%              is rounding when the forecast uses data of one date only, and
%              not otherwise, since the model's lagged states are the filter's
%              revised values and the agents' data the real-time ones)
%
%   'write'  writes kalman_errors.csv in outDir (hetlearn.run, after
%            hetlearn.engine.save_results): date, n_obs, llt, then err_<y>
%            (one-step errors), pred_<y> (predictions), var_<y> (diagonal of
%            F_t) for every measurement variable; without res.kalman a file left
%            by an earlier run of the id is deleted.
%   'rmse'   struct .table (one-step RMSE, rows = measurement variables with
%            data, columns = subsamples), .n (errors used), .loglik (sum of l_t
%            per subsample), .subsamples (name, first, last), .note.
%            subsamples: cell {name, first, last; ...}; default full
%            (beliefs.init.date .. origin), y1966_1983, y1984_2007, y2008_2019,
%            y2020Q4_end (DESIGN_br_extensions 5; 2020Q4 is a four-step
%            prediction after the 2020Q1-Q3 gap), clipped to the filter dates.
%
%   See also hetlearn.engine.core, hetlearn.engine.history,
%   hetlearn.engine.facility, hetlearn.engine.update_learning.

if nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    switch char(varargin{1})
        case 'write'
            write_errors(varargin{2:end});
        case 'rmse'
            varargout{1} = rmse_table(varargin{2:end});
        otherwise
            error('hetlearn:engine:kalman', 'Unknown call hetlearn.engine.kalman_history(''%s'', ...).', ...
                char(varargin{1}));
    end
    return
end
[varargout{1:5}] = run_filter(varargin{:});
end


% =========================================================================
function [S, rec, ev, dK, hinfo] = run_filter(ctx, S, H, rec, m)
tAll = tic;
o = ctx.opts;
if ~logical(o.history.learn)
    error('hetlearn:engine:kalman', 'history.mode = ''kalman'' needs history.learn = true.');
end
if isfield(o.history, 're_states') && strcmp(o.history.re_states, 'filtered')
    error('hetlearn:engine:kalman', ['history.re_states = ''filtered'' applies to history.mode = ' ...
        '''re_smoother'' only (the Kalman history is one-sided by construction).']);
end
sys = ctx.sys;
lv = ctx.learnVars;
if ~isfield(ctx, 'blocks') || isempty(ctx.blocks)
    ctx.blocks = hetlearn.plm.blocks(sys);
end
init = 'stochastic';
if isfield(o.history, 'kalman') && isfield(o.history.kalman, 'init') && ~isempty(o.history.kalman.init)
    init = char(o.history.kalman.init);
end
t0 = ctx.init_date;
origin = ctx.origin;
mF = m;                                   % forecast model (ALM check at the origin)
if isfield(ctx, 'info') && isfield(ctx.info, 'policy') && isstruct(ctx.info.policy) ...
        && isfield(ctx.info.policy, 'ramsey') && logical(ctx.info.policy.ramsey) ...
        && ~isempty(ctx.info.policy.rule_model)
    m = ctx.info.policy.rule_model;       % Ramsey (DESIGN 13): the history is the rule model
end
doAlm = ~strcmp(hetlearn.engine.facility('name', o), 'none');
reLagged = isfield(o.expectations, 're_info') && strcmp(o.expectations.re_info, 'lagged');
isNT = hetlearn.engine.ntypes('on', ctx);       % N agent types, forecast transforms (phase P6)
brInfo = 'lagged';
if isfield(sys, 'info') && ~isempty(sys.info)
    brInfo = char(sys.info);
end

% ---- dates and data ----------------------------------------------------------------------
switch init
    case 'stochastic'
        start = H.range(1);
    case 'smoothed'
        start = t0;
    otherwise
        error('hetlearn:engine:kalman', 'history.kalman.init must be ''stochastic'' or ''smoothed'', not ''%s''.', init);
end
dates = start:origin;
nT = numel(dates);
nPre = numel(start:t0) - 1;               % quarters before beliefs.init.date: the RE limit
if isfield(H, 'data') && isstruct(H.data) && ~isempty(fieldnames(H.data))
    data = H.data;
else
    data = hetlearn.load_database(ctx.spec);
end
yl = reshape(cellstr(get(m, 'yList')), 1, []);
el = reshape(cellstr(get(m, 'eList')), 1, []);
ny = numel(yl);
ne = numel(el);
Y = NaN(ny, nT);
for i = 1:ny
    if isfield(data, yl{i}) && isa(data.(yl{i}), 'Series')
        Y(i, :) = reshape(data.(yl{i})(dates), 1, []);
    end
end

% ---- state vector and storage --------------------------------------------------------------
nm = vector_names(m);
nx = nm.nx;
nf = nm.nf;
cur = nm.cur;
ncur = numel(cur);
rowOf = struct();
for r = 1:ncur
    rowOf.(nm.x_names{cur(r)}) = r;
end
for i = 1:ny
    rowOf.(yl{i}) = ncur + i;
end
maxLagX = max([0, nm.x_lags]);
L = max([sys.maxlag, maxLagX + 1, 1]) + 1;           % columns before the start (agents' lags, start state)
colDates = (start - L):origin;
XF = NaN(ncur + ny, L + nT);              % real-time filtered x_{t|t}, y_{t|t} (column L+k = dates(k))
XP = NaN(ncur + ny, L + nT);              % predictions x_{t|t-1}, y_{t|t-1}
if strcmp(init, 'smoothed')               % data before the start: the RE-smoothed history (as the inversion)
    pre = colDates(1:L);
    vn = [nm.x_names(cur), yl];
    for r = 1:numel(vn)
        if isfield(H.smooth, vn{r})
            XF(r, 1:L) = reshape(H.smooth.(vn{r})(pre), 1, []);
        end
    end
end
EF = zeros(ne, nT);
PRED = NaN(ny, nT);
ERR = NaN(ny, nT);
FALL = NaN(ny, ny, nT);
LLT = zeros(1, nT);
NOBS = zeros(1, nT);

% ---- filter ---------------------------------------------------------------------------------
n1RE = struct();
for i = 1:numel(lv)
    if isNT                               % share vector over the variable's types, 1 on RE
        b = ctx.nt.byvar.(lv{i});
        v = zeros(1, numel(b.types));
        v(b.re_pos) = 1;
        n1RE.(lv{i}) = v;
    else
        n1RE.(lv{i}) = 1;
    end
end
if isNT
    XA = XF;                              % agents' data (the real-time filtered values, see below)
    AV = agent_rows(rowOf, reLagged, lv);
    dTy = struct();
    for j = 1:numel(ctx.nt.types)
        dTy.(ctx.nt.types(j).name) = 0;
    end
end
ev = struct('date', {}, 'type', {}, 'variable', {}, 'detail', {});
h = struct('alm_check_s', 0, 'alm_n_check', 0, 'alm_n_solve', 0, 'warm', []);
solved = false;
lastP = [];
ss = [];
ssPv = [];
Omg = [];
fastPrev = [];
a = [];
Pk = [];
nSolve = 0;
dBR = 0;
c2pi = log(2*pi);
for k = 1:nT
    t = dates(k);
    kc = L + k;
    learn = k > nPre;
    kRec = k - nPre;                      % record index, 1 = beliefs.init.date
    % (1) the ALM in force in t
    if learn
        n1m = hetlearn.engine.shares_for_mode(ctx, S);
    else
        n1m = n1RE;
    end
    P = hetlearn.engine.facility('params', sys, S.phi, lv, n1m);
    pv = cell2mat(struct2cell(P));
    if ~solved || ~isequal(pv, lastP)
        [m, S, r, e] = hetlearn.engine.facility('solve', ctx, m, S, n1m, t, 'kalman');
        n1m = r.n1m;                      % model shares in force in t (kept ones included)
        ev = [ev, e]; %#ok<AGROW>
        nSolve = nSolve + r.n_solve;
        if r.reverted && kRec - 1 >= 1
            for i = 1:numel(sys.eq)       % beliefs in force in t after the revert
                tg = sys.eq(i).target;
                rec.eq(i).phi(:, kRec - 1) = S.phi.(tg);
                rec.eq(i).Rdiag(:, kRec - 1) = diag(S.R.(tg));
            end
        end
        pv = r.pv;
        lastP = pv;
        solved = true;
    end
    if isempty(ss) || ~isequal(pv, ssPv)
        if isempty(Omg)
            Omg = shock_cov(m, ne);
        end
        [ss, fastPrev] = system_of(m, nm, yl, el, Omg, fastPrev, t);
        ssPv = pv;
    end
    if k == 1
        [a, Pk] = initial_state(init, ss, nm, H, start);
    end
    % (2) prediction and update
    a = ss.A*a + ss.K;
    Pk = ss.A*Pk*ss.A' + ss.Q;
    Pk = (Pk + Pk')/2;
    yhat = ss.Zf*a + ss.D;
    C = Pk*ss.Zf' + ss.RH;                % Cov(x_t, y_t | t-1)
    Fa = ss.Zf*C + ss.HG;
    Fa = (Fa + Fa')/2;
    PRED(:, k) = yhat;
    FALL(:, :, k) = Fa;
    XP(1:ncur, kc) = a(cur);
    XP(ncur+1:end, kc) = yhat;
    yf = yhat;
    ob = isfinite(Y(:, k));
    if any(ob)
        v = Y(ob, k) - yhat(ob);
        [Lc, p] = chol(Fa(ob, ob), 'lower');
        if p ~= 0
            error('hetlearn:engine:kalman', ['Period %s (kalman stage): the covariance of the one-step ' ...
                'prediction errors of the observables is not positive definite.'], char(dat2str(t)));
        end
        w = Lc \ v;
        LLT(k) = -0.5*(nnz(ob)*c2pi + 2*sum(log(diag(Lc))) + w'*w);
        u = Lc' \ w;                      % F^-1 v
        Co = C(:, ob);
        a = a + Co*u;
        Kg = (Co / Lc') / Lc;             % C F^-1
        Pk = Pk - Kg*Co';
        Pk = (Pk + Pk')/2;
        EF(:, k) = ss.Ge(:, ob)*u;
        ERR(ob, k) = v;
        NOBS(k) = nnz(ob);
        yf = ss.Zf*a + ss.D + ss.H*EF(:, k);
        yf(ob) = Y(ob, k);
    end
    XF(1:ncur, kc) = a(cur);
    XF(ncur+1:end, kc) = yf;
    if isNT
        XA = agent_column(XA, XF, XP, kc, AV);
    end
    if ~learn
        continue
    end
    % (3) forecasts made in t
    if isNT
        % every type's forecast on the agents' data (DESIGN_br_extensions 1.1, phase P6): fRE = F, the
        % forecasts as they enter the aggregate (fitness), fBR = X, with X.base before the transforms
        getVal = @(name, j) xval(XA, rowOf, kc, name, j);
        [fRE, fBR] = hetlearn.engine.ntypes('forecasts', ctx, S, getVal, 'history', t);
        [dBR, dTy] = model_gap(ctx, fBR, XF, XP, rowOf, kc, dBR, dTy);
    else
        getVal = @(name, j) xval(XF, rowOf, kc, name, j);
        fRE = struct();
        fBR = struct();
        for i = 1:numel(lv)
            x = lv{i};
            rr = xrow(rowOf, [x '_exp1_RE']);
            if reLagged
                fRE.(x) = XP(rr, kc);         % made in t with data up to t-1
            else
                fRE.(x) = XF(rr, kc);
            end
            fBR.(x) = hetlearn.plm.forecast_value(sys, S.phi, getVal, x);
            if isfield(rowOf, [x '_exp1_BR'])
                rb = rowOf.([x '_exp1_BR']);
                if strcmp(brInfo, 'current')
                    dBR = max(dBR, abs(fBR.(x) - XF(rb, kc)));
                else
                    dBR = max(dBR, abs(fBR.(x) - XP(rb, kc)));
                end
            end
        end
    end
    % (4) learning update with the ALM check of the model in force in t+1
    A = [];
    atOrigin = k == nT;
    if doAlm
        if atOrigin
            A = struct('m', mF, 'stage', 'kalman');
        else
            A = struct('m', m, 'stage', 'kalman');
        end
    end
    [S, out, e] = hetlearn.engine.update_learning(ctx, S, t, getVal, fRE, fBR, kRec == 1, A);
    ev = [ev, e]; %#ok<AGROW>
    if ~isempty(out.alm)
        h.alm_check_s = h.alm_check_s + out.alm.time;
        if out.alm.checked
            h.alm_n_check = h.alm_n_check + 1;
            h.alm_n_solve = h.alm_n_solve + out.alm.n_solve;
            nSolve = nSolve + out.alm.n_solve;
            if atOrigin
                h.warm = struct('pv', out.alm.pv, 'm', out.alm.m);
            else
                m = out.alm.m;
                lastP = out.alm.pv;
            end
        end
    end
    rec = hetlearn.engine.record(rec, kRec, ctx, S, out, n1m);
end

% ---- databank for the forecast stage: the filtered state at the origin (D12) -------------------
dbStart = start;
if nT - 1 < maxLagX                       % a short history: the origin's lags reach before the start
    dbStart = origin - maxLagX;
end
cdb = dbStart:origin;
cols = numel(colDates(1):dbStart) - 1 + (1:numel(cdb));
XO = XF;
for i = 1:nx
    if nm.x_lags(i) >= 1                  % lag elements of a_{origin|origin}
        XO(rowOf.(nm.x_names{i}), L + nT - nm.x_lags(i)) = a(i);
    end
end
dK = struct();
vn = [nm.x_names(cur), yl];
for r = 1:numel(vn)
    s = smoothed_series(H, vn{r}, cdb);
    v = XO(r, cols)';
    w = s(cdb);
    v(~isfinite(v)) = w(~isfinite(v));    % before a 'stochastic' start only: keep the RE-smoothed values
    s(cdb) = v;
    dK.(vn{r}) = s;
end
for j = 1:ne
    s = smoothed_series(H, el{j}, cdb);
    s(dates) = EF(j, :)';
    dK.(el{j}) = s;
end

% ---- outputs ------------------------------------------------------------------------------------
filt = struct();
prd = struct();
kk = L + (1:nT);
for r = 1:ncur
    n = nm.x_names{cur(r)};
    filt.(n) = Series(dates, XF(r, kk)');
    prd.(n) = Series(dates, XP(r, kk)');
end
for i = 1:ny
    filt.(yl{i}) = Series(dates, XF(ncur + i, kk)');
    prd.(yl{i}) = Series(dates, PRED(i, :)');
end
for j = 1:ne
    filt.(el{j}) = Series(dates, EF(j, :)');
end
K = struct();
K.init = init;
K.start = start;
K.origin = origin;
K.dates = dates;
K.loglik_start = t0;
K.observables = yl;
K.y = Y;
K.pred = PRED;
K.err = ERR;
K.F = FALL;
K.llt = LLT;
K.n_obs = NOBS;
K.loglik = sum(LLT(nPre+1:end));
K.filtered = filt;
K.predicted = prd;
K.state_names = nm.keys;
K.a_origin = a;
K.P_origin = Pk;
K.n_solve = nSolve;
K.runtime_s = toc(tAll);
K.fbr_model_maxdiff = dBR;
if isNT
    K.ftypes_model_maxdiff = dTy;
end
hinfo = h;
hinfo.start = start;
hinfo.db_start = dbStart;
hinfo.origin = origin;
hinfo.n_solve = nSolve;
hinfo.runtime_s = K.runtime_s;
hinfo.kalman = K;
end


% =========================================================================
function nm = vector_names(m)
% Elements of the transition vector [xf; xb] (IRIS order): base names, lags, keys.
xv = reshape(cellstr(access(m, 'transition-vector')), 1, []);
nb = numel(cellstr(get(m, 'xbVector')));
nx = numel(xv);
base = cell(1, nx);
lag = zeros(1, nx);
for i = 1:nx
    [base{i}, lag(i)] = parse_element(xv{i});
end
nm = struct('nx', nx, 'nb', nb, 'nf', nx - nb);
nm.x_names = base;
nm.x_lags = lag;
nm.keys = element_keys(base, lag);
nm.cur = find(lag == 0);
if numel(unique(base(nm.cur))) ~= numel(nm.cur)
    error('hetlearn:engine:kalman', 'A transition variable appears twice at lag 0 in the transition vector.');
end
end


function [b, k] = parse_element(s)
tok = regexp(s, '^([A-Za-z]\w*)\{-(\d+)\}$', 'tokens', 'once');
if ~isempty(tok)
    b = tok{1};
    k = str2double(tok{2});
elseif ~isempty(regexp(s, '^[A-Za-z]\w*$', 'once'))
    b = s;
    k = 0;
else
    error('hetlearn:engine:kalman', ...
        'Cannot read transition vector element ''%s'' (log variables are not supported).', s);
end
end


function c = element_keys(base, lag)
c = base;
for i = find(lag > 0)
    c{i} = sprintf('%s{-%d}', base{i}, lag(i));
end
end


function Omg = shock_cov(m, ne)
% Covariance of the shocks (std and corr parameters; not changed by learning).
[~, ~, ~, ~, ~, ~, ~, Omg] = sspace(m, 'triangular', false);
Omg = Omg(:, :, 1);
if ~isequal(size(Omg), [ne, ne]) || any(~isfinite(Omg(:)))
    error('hetlearn:engine:kalman', 'Shock covariance matrix not available from the model.');
end
end


function [ss, fastPrev] = system_of(m, nm, yl, el, Omg, fastPrev, t)
% State space of the solved ALM on the full vector, in the order of nm, yl, el.
u = userdata(m);
if isstruct(u) && isfield(u, 'hetlearn_backward') && isstruct(u.hetlearn_backward) && u.hetlearn_backward.ok
    bw = u.hetlearn_backward;             % no IRIS solution, no leads (hetlearn.engine.solve_model)
    T = -(bw.M \ bw.Bb);
    K = -(bw.M \ bw.C);
    R = -(bw.M \ bw.D);
    Z = -(bw.F \ bw.G);
    D = -(bw.F \ bw.H);
    Hm = -(bw.F \ bw.J);
    keys = element_keys([bw.xf_names, bw.xb_names], [zeros(1, bw.nf), bw.xb_lags]);
    nfS = bw.nf;
    yS = bw.y_names;
    eS = bw.e_names;
else
    if isstruct(u) && isfield(u, 'hetlearn_sspace') && ~isempty(u.hetlearn_sspace)
        f = u.hetlearn_sspace;            % cached by solve_model under engine.step = 'fast'
    else
        f = hetlearn.engine.step('build', m, fastPrev);
        fastPrev = f;
    end
    T = f.T;
    K = f.K;
    R = f.R;
    Z = f.Z;
    D = f.D;
    Hm = f.H;
    keys = element_keys(f.names.x_names, f.names.x_lags);
    nfS = f.names.nf;
    yS = f.names.y_names;
    eS = f.names.e_names;
end
[okx, px] = ismember(nm.keys, keys);
[oky, py] = ismember(yl, yS);
[oke, pe] = ismember(el, eS);
if ~all(okx) || numel(keys) ~= nm.nx || nfS ~= nm.nf || any(px(nm.nf+1:end) <= nfS) ...
        || ~all(oky) || ~all(oke)
    error('hetlearn:engine:kalman', 'Period %s: the solved model''s state space does not match its transition vector.', ...
        char(dat2str(t)));
end
if ~isequal(px, 1:nm.nx)
    T = T(px, px(nm.nf+1:end) - nfS);
    K = K(px);
    R = R(px, :);
    Z = Z(:, px(nm.nf+1:end) - nfS);
end
R = R(:, pe);
Hm = Hm(py, pe);
Z = Z(py, :);
D = D(py);
if any(~isfinite([T(:); K(:); R(:); Z(:); D(:); Hm(:)]))
    error('hetlearn:engine:kalman', 'Period %s: the solved model''s state space has non-finite entries.', ...
        char(dat2str(t)));
end
nx = nm.nx;
nf = nm.nf;
ny = numel(yl);
ss = struct();
ss.A = [zeros(nx, nf), T];
ss.K = K;
ss.R = R;
ss.Zf = [zeros(ny, nf), Z];
ss.D = D;
ss.H = Hm;
Q = R*Omg*R';
ss.Q = (Q + Q')/2;
G = ss.Zf*R + Hm;                         % loading of e_t on y_t given x_{t-1}
ss.RH = R*Omg*Hm';                        % Cov(x_t, H e_t)
ss.HG = Hm*Omg*G';
ss.Ge = Omg*G';                           % Cov(e_t, y_t | t-1)
end


function [a, P] = initial_state(init, ss, nm, H, start)
% State mean and MSE at start - 1.
nx = nm.nx;
nf = nm.nf;
nb = nm.nb;
a = zeros(nx, 1);
P = zeros(nx);
if nb == 0
    return
end
ib = nf+1:nx;
switch init
    case 'stochastic'                     % asymptotic distribution (IRIS filter default)
        Tb = ss.A(ib, ib);
        [U, Ts] = schur(Tb, 'real');
        rt = ordeig(Ts);
        if any(abs(rt) >= 1 - 1e-10)
            error('hetlearn:engine:kalman', ['history.kalman.init = ''stochastic'' needs a stationary ALM in the ' ...
                'first filter quarter %s (largest root %.6g); use history.kalman.init = ''smoothed''.'], ...
                char(dat2str(start)), max(abs(rt)));
        end
        a(ib) = (eye(nb) - Tb) \ ss.K(ib);
        Pb = U*covfun.lyapunov(Ts, U'*ss.Q(ib, ib)*U)*U';
        P(ib, ib) = (Pb + Pb')/2;
    case 'smoothed'                       % RE-smoothed state at start - 1, P = 0
        ab = NaN(nb, 1);
        for j = 1:nb
            n = nm.x_names{nf + j};
            if isfield(H.smooth, n)
                ab(j) = H.smooth.(n)(start - 1 - nm.x_lags(nf + j));
            end
        end
        miss = ~isfinite(ab);
        if any(miss)
            used = any(ss.A(:, nf + find(miss)) ~= 0, 1);
            if any(used)
                bad = find(miss);
                error('hetlearn:engine:kalman', 'history.kalman.init = ''smoothed'': no RE-smoothed value for %s at %s.', ...
                    strjoin(nm.keys(nf + bad(used)), ', '), char(dat2str(start - 1)));
            end
            ab(miss) = 0;
        end
        a(ib) = ab;
end
end


function AV = agent_rows(rowOf, reLagged, lv)
% Rows of the agents' data that differ from the real-time filtered values (N types, phase P6):
% .pred  rows taken from the predictions x_{t|t-1}: with expectations.re_info = 'lagged' every
%        <x>_exp1_RE and <x>_DEg_RE (functions of the period-(t-1) state; hetlearn.engine.history_db
%        takes them from H.predicted under history.re_states = 'filtered')
% .fe    targets of 're_mean' types, <x>_feRE = x - <x>_exp1_RE{-1}, rebuilt from x_{t|t} and the RE
%        forecast of t-1 in the agents' data (rows .row, .x, .re)
f = fieldnames(rowOf);
AV = struct('pred', zeros(1, 0), 'fe', struct('row', {}, 'x', {}, 're', {}));
if reLagged
    sel = endsWith(f, '_exp1_RE') | endsWith(f, '_DEg_RE');
    AV.pred = cellfun(@(n) rowOf.(n), f(sel))';
end
for i = 1:numel(lv)
    x = lv{i};
    if isfield(rowOf, [x '_feRE']) && isfield(rowOf, x) && isfield(rowOf, [x '_exp1_RE'])
        AV.fe(end+1) = struct('row', rowOf.([x '_feRE']), 'x', rowOf.(x), 're', rowOf.([x '_exp1_RE']));
    end
end
end


function XA = agent_column(XA, XF, XP, kc, AV)
% Column kc (quarter t) of the agents' data, once XF(:, kc) and XP(:, kc) are known.
XA(:, kc) = XF(:, kc);
XA(AV.pred, kc) = XP(AV.pred, kc);
for q = 1:numel(AV.fe)
    XA(AV.fe(q).row, kc) = XF(AV.fe(q).x, kc) - XA(AV.fe(q).re, kc - 1);
end
end


function [dP, dT] = model_gap(ctx, X, XF, XP, rowOf, kc, dP, dT)
% |forecast of each 'plm', 'rule' and 're_mean' type before the transforms (X.base) - the
% model's <x>_exp1_<type>|, predicted (information up to t-1) or filtered (period t); dP over 'plm' types
nt = ctx.nt;
for i = 1:numel(ctx.learnVars)
    x = ctx.learnVars{i};
    b = nt.byvar.(x);
    for jj = 1:numel(b.types)
        ty = nt.types(b.types(jj));
        if ~any(strcmp(ty.kind, {'plm', 'rule', 're_mean'})) || ~isfield(rowOf, b.fvars{jj})
            continue
        end
        r = rowOf.(b.fvars{jj});
        if strcmp(ty.info, 'current')
            v = XF(r, kc);
        else
            v = XP(r, kc);
        end
        g = abs(X.base.(x).(ty.name) - v);
        dT.(ty.name) = max(dT.(ty.name), g);
        if strcmp(ty.kind, 'plm')
            dP = max(dP, g);
        end
    end
end
end


function v = xval(X, rowOf, kc, name, j)
% Real-time filtered value of name at t + j (column kc = t).
r = xrow(rowOf, name);
if kc + j < 1
    v = NaN;
else
    v = X(r, kc + j);
end
end


function r = xrow(rowOf, name)
if ~isfield(rowOf, name)
    error('hetlearn:engine:kalman', ['The Kalman history has no series %s (agents'' data must be transition ' ...
        'or measurement variables of the model).'], name);
end
r = rowOf.(name);
end


function s = smoothed_series(H, name, rng)
% Series over rng with the RE-smoothed values (NaN where there are none).
v = NaN(numel(rng), 1);
if isfield(H, 'smooth') && isfield(H.smooth, name) && isa(H.smooth.(name), 'Series')
    v = H.smooth.(name)(rng);
end
s = Series(rng, v(:));
end


% =========================================================================
function write_errors(res, outDir)
% kalman_errors.csv: one-step errors, predictions and their variances by quarter.
f = fullfile(outDir, 'kalman_errors.csv');
if ~isfield(res, 'kalman') || isempty(res.kalman)
    if exist(f, 'file') == 2
        delete(f);                        % left by an earlier Kalman run of this id
    end
    return
end
K = res.kalman;
obs = reshape(K.observables, 1, []);
nT = numel(K.dates);
V = NaN(numel(obs), nT);
for k = 1:nT
    V(:, k) = diag(K.F(:, :, k));
end
hdr = [{'date', 'n_obs', 'llt'}, strcat('err_', obs), strcat('pred_', obs), strcat('var_', obs)];
X = [K.n_obs(:), K.llt(:), K.err', K.pred', V'];
hetlearn.util.write_csv(f, hdr, hetlearn.util.date_str(K.dates), X);
end


function out = rmse_table(res, subs)
% One-step RMSE by measurement variable and subsample, and the log likelihood per subsample.
K = res.kalman;
d = double(K.dates);
if nargin < 2 || isempty(subs)
    subs = {'full', K.loglik_start, K.origin; ...
        'y1966_1983', qq(1966, 1), qq(1983, 4); ...
        'y1984_2007', qq(1984, 1), qq(2007, 4); ...
        'y2008_2019', qq(2008, 1), qq(2019, 4); ...
        'y2020Q4_end', qq(2020, 4), K.origin};
end
keep = false(1, size(subs, 1));
for s = 1:size(subs, 1)
    keep(s) = double(subs{s, 2}) <= d(end) + 1e-6 && double(subs{s, 3}) >= d(1) - 1e-6 ...
        && double(subs{s, 2}) <= double(subs{s, 3}) + 1e-6;
end
subs = subs(keep, :);
has = any(isfinite(K.err), 2)';
obs = K.observables(has);
E = K.err(has, :);
nS = size(subs, 1);
rm = NaN(numel(obs), nS);
n = zeros(numel(obs), nS);
ll = zeros(1, nS);
for s = 1:nS
    in = d >= double(subs{s, 2}) - 1e-6 & d <= double(subs{s, 3}) + 1e-6;
    for i = 1:numel(obs)
        e = E(i, in);
        e = e(isfinite(e));
        n(i, s) = numel(e);
        if ~isempty(e)
            rm(i, s) = sqrt(mean(e.^2));
        end
    end
    ll(s) = sum(K.llt(in));
end
out = struct();
out.table = array2table(rm, 'RowNames', obs, 'VariableNames', subs(:, 1)');
out.n = array2table(n, 'RowNames', obs, 'VariableNames', subs(:, 1)');
out.loglik = array2table(ll, 'VariableNames', subs(:, 1)');
out.subsamples = subs;
out.note = ['one-step prediction errors of the Kalman history (res.kalman.err), model units; quarters ' ...
    'without data are skipped, so the first quarter after a gap is a multi-step prediction'];
end
