function D = decompose(res, vars, range, opts)
%DECOMPOSE  Shock decomposition of a scenario result (DESIGN 16).
%
%   D = hetlearn.decompose(res)
%   D = hetlearn.decompose(res, vars, range, opts)
%
%   Inputs
%     res    result struct of hetlearn.run, or a scenario id (read from
%            <opts.results_dir>/<id>/results.mat)
%     vars   cellstr of variables (default {'pinfobs', 'dy'}), decomposed as
%            deviations from their RE steady state
%     range  reporting dates, a vector or [start, end] (default: every
%            computed date, from the first date with initial conditions in
%            res.paths to the end of the horizon)
%     opts   struct, every field optional:
%       .groups       struct of shock groups, e.g. struct('demand',
%                     {{'eb','eg'}}); each group is one summed component,
%                     shocks in no group stay single
%       .method       'auto' (default: 'iris' for expectations.mode =
%                     'rational', else 'tv') | 'iris' | 'tv'
%       .model        preloaded struct('spec', spec, 'm', m, 'info', info)
%                     of hetlearn.load_model for res.cfg (default: loaded)
%       .save         write the CSV (default true)
%       .results_dir  parent folder of <id>/ (default <root>/results)
%       .file         CSV path (default <results_dir>/<id>/decomposition.csv)
%       .quiet        no progress line (default false)
%
%   Components: one per shock (or group), 'init' (initial conditions) and
%   'beliefs_constants'; 'total' is the deviation of the variable from the
%   RE steady state. The decomposition is additive: total = sum of the
%   components. Reading the learning ('tv') decomposition: the slope beliefs
%   and the shares act inside EVERY shock component, through each period's
%   transition matrices T_t, R_t (a shock's component is its propagation
%   through the models in force), so they are not a component of their own;
%   'beliefs_constants' is only the intercept channel (perceived means:
%   the time-varying constants and their propagation). The CSV column
%   'label' names each component in words ('intercept channel (perceived
%   means)' for beliefs_constants; shock labels from the model file); the
%   component ids are unchanged.
%   'iris': IRIS contributions, simulate(m, res.paths, sim range,
%   'anticipate', false, 'contributions', true) of the RE model, from the
%   first date with initial conditions in res.paths; init = the
%   'Init+Const+Trends' column minus the steady state; 'beliefs_constants'
%   = total minus the rest (the 'Nonlinear' column and rounding; 0 for a
%   linear RE model).
%   'tv': time-varying linear decomposition with the model in force in each
%   period, re-solved: the RE model before the learning model applies (the
%   RE-smoothed history), the parameter values recorded by the inversion
%   (res.inversion.params) over the inversion history, and over the forecast
%   horizon the beliefs phi_{t-1} and model shares n1_model(t) of
%   res.learning: the beliefs in force after the projection facility
%   (DESIGN 4.4; a reverted belief is recorded at its reverted value).
%   Component paths x^c_t = T_t x^c_{t-1} + R_t e^c_t without constants
%   (the state-space matrices of each period's IRIS solution, i.e. the
%   one-period simulate with 'deviation', true; the backward system when
%   IRIS has no solution); c = each shock (e^c = that shock only, zero
%   start) and 'init' (no shocks, start = the deviation of the initial state
%   from the RE steady state). 'beliefs_constants' = total deviation minus
%   the sum of the components: the time-varying intercepts and their
%   propagation. Check: the same matrices with constants rebuild res.paths
%   period by period (D.check.recon_maxerr).
%
%   N agent types and forecast transforms (docs/DESIGN_br_extensions.md
%   1.1-1.5; phase P6): supported, with the model of the run (the N-type file:
%   transform parameters and rule constants are its parameters). 'tv' over
%   the forecast takes every learning type's beliefs from
%   res.learning.<target>__<type> and the share parameters from
%   res.learning.<x>.n_model_<type>; in the RE-model periods the paths of the
%   type forecasts <x>_exp1_<type> ('plm', 'rule', 're_mean' types; they hold
%   the agents' forecasts) are left out of the reconstruction check, as
%   <x>_exp1_BR. Error (hetlearn:options:unsupported): any result of
%   history.mode = 'kalman' (its filtered history is not a path of the model
%   with the filtered shocks, since the state covariance never collapses, so
%   the components would not add up by shock).
%
%   Output D: .scenario, .method, .vars, .dates, .components, .values.<v>
%   (nDates x nComponents, model units), .total.<v>, .ss.<v>, .scale.<v>
%   (report units = model units x spec.report.scale.<v>), .table (long:
%   scenario, date, variable, component, value_model, value_report; with
%   'total' rows), .check (.additivity_maxerr; 'tv': .recon_maxerr,
%   .recon_by_date, .n_solve, .n_backward), .file,
%   .runtime_s.

tAll = tic;
if nargin < 2 || isempty(vars)
    vars = {'pinfobs', 'dy'};
end
vars = reshape(cellstr(vars), 1, []);
if nargin < 3
    range = [];
end
if nargin < 4 || isempty(opts)
    opts = struct();
end
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
def = struct('groups', struct(), 'method', 'auto', 'model', [], 'save', true, ...
    'results_dir', fullfile(root, 'results'), 'file', '', 'quiet', false);
f = fieldnames(opts);
for i = 1:numel(f)
    if ~isfield(def, f{i})
        error('hetlearn:decompose:option', 'Unknown decompose option "%s".', f{i});
    end
    def.(f{i}) = opts.(f{i});
end
opts = def;
if ischar(res) || isstring(res)
    file = fullfile(opts.results_dir, char(res), 'results.mat');
    if exist(file, 'file') ~= 2
        error('hetlearn:decompose:result', 'No results file %s.', file);
    end
    L = load(file, 'res');
    res = L.res;
end
o = res.cfg;
if isfield(o, 'policy') && isfield(o.policy, 'mode') && strcmp(o.policy.mode, 'ramsey')
    error('hetlearn:decompose:ramsey', 'Ramsey-policy results are not supported yet.');
end
if isempty(opts.model)
    spec = hetlearn.load_spec(o.model);
    [m, info] = hetlearn.load_model(spec, o);
else
    spec = opts.model.spec;
    m = opts.model.m;
    info = opts.model.info;
end
method = opts.method;
if strcmp(method, 'auto')
    if strcmp(o.expectations.mode, 'rational')
        method = 'iris';
    else
        method = 'tv';
    end
end
if ~any(strcmp(method, {'iris', 'tv'}))
    error('hetlearn:decompose:option', 'opts.method must be ''auto'', ''iris'' or ''tv''.');
end
hm = '';
if isfield(res, 'history_mode')
    hm = char(res.history_mode);
elseif isfield(o, 'history') && isfield(o.history, 'mode')
    hm = char(o.history.mode);
end
if strcmp(hm, 'kalman')
    error('hetlearn:options:unsupported', ['hetlearn.decompose of %s: history.mode = ''kalman'' is not supported. ' ...
        'Its history is the filtered state of the ALM in force each quarter, which is not a path of the model ' ...
        'with the filtered shocks (the state covariance never collapses), so the components would not add up by ' ...
        'shock. Decompose a run of the same scenario with history.mode = ''re_smoother'' or ''inversion''.'], o.id);
end

% ---- names, data, RE steady state ------------------------------------------------------
xList = reshape(res.meta.xList, 1, []);
yList = reshape(res.meta.yList, 1, []);
eList = reshape(res.meta.eList, 1, []);
names = [xList, yList];
bad = setdiff(vars, names);
if ~isempty(bad)
    error('hetlearn:decompose:vars', 'Not variables of the model: %s.', strjoin(bad, ', '));
end
full = res.dates.full;
nTime = numel(full);
nV = numel(names);
nE = numel(eList);
row = struct();
for i = 1:nV
    row.(names{i}) = i;
end
X = NaN(nV, nTime);
for i = 1:nV
    X(i, :) = reshape(res.paths.(names{i})(full), 1, []);
end
E = zeros(nE, nTime);
for j = 1:nE
    v = reshape(res.paths.(eList{j})(full), 1, []);
    v(~isfinite(v)) = 0;
    E(j, :) = v;
end
ssRE = hetlearn.engine.step('build', m, []);
ss = steady_state(ssRE, names);
Xdev = X - ss;
it0 = 2 + max([0, ssRE.names.xb_lags]);       % first date with initial conditions
if it0 > nTime
    error('hetlearn:decompose:range', 'res.paths is too short for a decomposition.');
end

% ---- components --------------------------------------------------------------------------
check = struct();
switch method
    case 'iris'
        [Cm, check] = iris_contrib(m, res.paths, full, it0, names, vars, eList, ss);
    case 'tv'
        [Cm, check] = tv_contrib(m, spec, info, res, full, it0, X, E, Xdev, row, names, eList);
end
% Cm: nV x nTime x (nE + 1), components = shocks (eList order), init
comps = [eList, {'init'}];
resid = Xdev - sum(Cm, 3);
resid(:, 1:it0-1) = 0;

% ---- groups --------------------------------------------------------------------------------
gn = fieldnames(opts.groups);
used = {};
G = zeros(nV, nTime, 0);
gNames = {};
for g = 1:numel(gn)
    mem = reshape(cellstr(opts.groups.(gn{g})), 1, []);
    bad = setdiff(mem, eList);
    if ~isempty(bad)
        error('hetlearn:decompose:groups', 'Group %s names unknown shock(s): %s.', gn{g}, strjoin(bad, ', '));
    end
    dup = intersect(mem, used);
    if ~isempty(dup)
        error('hetlearn:decompose:groups', 'Shock(s) %s are in more than one group.', strjoin(dup, ', '));
    end
    used = [used, mem]; %#ok<AGROW>
    G(:, :, end+1) = sum(Cm(:, :, ismember(eList, mem)), 3); %#ok<AGROW>
    gNames{end+1} = gn{g}; %#ok<AGROW>
end
single = ~ismember(eList, used);
Cf = cat(3, G, Cm(:, :, [single, false]), Cm(:, :, end), resid);
compNames = [gNames, eList(single), {'init', 'beliefs_constants'}];
eLab = shock_labels(m, eList);
gLab = cellfun(@(g) sprintf('%s shocks (%s)', g, strjoin(reshape(cellstr(opts.groups.(g)), 1, []), ' + ')), ...
    gNames, 'UniformOutput', false);
compLabels = [gLab, eLab(single), {'initial conditions', 'intercept channel (perceived means)'}];

% ---- reporting range and output ----------------------------------------------------------
if isempty(range)
    rd = full(it0:end);
else
    rd = hetlearn.util.to_dates(range);
end
idx = zeros(1, numel(rd));
for k = 1:numel(rd)
    i = find(abs(double(full) - double(rd(k))) < 1e-6, 1);
    if isempty(i) || i < it0
        error('hetlearn:decompose:range', 'Date %s is outside the decomposed range %s-%s.', ...
            char(dat2str(rd(k))), char(dat2str(full(it0))), char(dat2str(full(end))));
    end
    idx(k) = i;
end
D = struct();
D.scenario = o.id;
D.method = method;
D.vars = vars;
D.dates = rd;
D.components = compNames;
D.labels = compLabels;
D.values = struct();
D.total = struct();
D.ss = struct();
D.scale = struct();
rows = {};
ds = hetlearn.util.date_str(rd);
for q = 1:numel(vars)
    v = vars{q};
    r = row.(v);
    V = reshape(Cf(r, idx, :), numel(idx), []);
    tot = Xdev(r, idx)';
    sc = 1;
    if isfield(spec, 'report') && isfield(spec.report, 'scale') && isfield(spec.report.scale, v)
        sc = double(spec.report.scale.(v));
    end
    D.values.(v) = V;
    D.total.(v) = tot;
    D.ss.(v) = ss(r);
    D.scale.(v) = sc;
    for k = 1:numel(idx)
        for c = 1:numel(compNames)
            rows(end+1, :) = {o.id, ds{k}, v, compNames{c}, V(k, c), sc * V(k, c), compLabels{c}}; %#ok<AGROW>
        end
        rows(end+1, :) = {o.id, ds{k}, v, 'total', tot(k), sc * tot(k), ...
            'total deviation from the RE steady state'}; %#ok<AGROW>
    end
end
D.table = cell2table(rows, 'VariableNames', {'scenario', 'date', 'variable', 'component', ...
    'value_model', 'value_report', 'label'});
add = 0;
for q = 1:numel(vars)
    add = max(add, max(abs(sum(D.values.(vars{q}), 2) - D.total.(vars{q}))));
end
check.additivity_maxerr = add;
D.check = check;
D.file = '';
if logical(opts.save)
    file = opts.file;
    if isempty(file)
        file = fullfile(opts.results_dir, o.id, 'decomposition.csv');
    end
    folder = fileparts(file);
    if ~isempty(folder) && exist(folder, 'dir') ~= 7
        mkdir(folder);
    end
    writetable(D.table, file);
    D.file = file;
end
D.runtime_s = toc(tAll);
if ~logical(opts.quiet)
    fprintf('[decompose] %s: %s, %d variables, %s-%s, %d components, %.1f s\n', o.id, method, ...
        numel(vars), char(dat2str(rd(1))), char(dat2str(rd(end))), numel(compNames), D.runtime_s);
end
end


% =========================================================================
function lab = shock_labels(m, eList)
% 'Description (name)' from the model file's shock labels; the name if none.
lab = eList;
try
    names = cellstr(get(m, 'eList'));
    desc = cellstr(get(m, 'eDescript'));
    for j = 1:numel(eList)
        i = find(strcmp(names, eList{j}), 1);
        if ~isempty(i) && i <= numel(desc) && ~isempty(strtrim(desc{i}))
            lab{j} = sprintf('%s (%s)', strtrim(desc{i}), eList{j});
        end
    end
catch
    lab = eList;
end
end


function ss = steady_state(sys, names)
% RE steady state of every transition and measurement variable from the
% state-space solution: xb = (I - T_b)^{-1} K_b, x = T xb + K, y = Z xb + D.
nm = sys.names;
Tb = sys.T(nm.nf+1:end, :);
Kb = sys.K(nm.nf+1:end);
xb = (eye(nm.nb) - Tb) \ Kb;
x = sys.T * xb + sys.K;
y = sys.Z * xb + sys.D;
ss = NaN(numel(names), 1);
for i = 1:numel(names)
    n = names{i};
    if isfield(nm.x_index, n)
        ss(i) = x(nm.x_index.(n));
    elseif isfield(nm.y_index, n)
        ss(i) = y(nm.y_index.(n));
    end
end
end


function fv = type_forecast_vars(nt, lv)
% the paths that hold the agents' own forecasts over the record (hetlearn.engine.assemble): <x>_exp1_<k> of
% the 'plm', 'rule' and 're_mean' types of each learning variable
fv = {};
for i = 1:numel(lv)
    b = nt.byvar.(lv{i});
    for jj = 1:numel(b.types)
        if any(strcmp(nt.types(b.types(jj)).kind, {'plm', 'rule', 're_mean'}))
            fv{end+1} = b.fvars{jj}; %#ok<AGROW>
        end
    end
end
end


function [Cm, check] = iris_contrib(m, paths, full, it0, names, vars, eList, ss)
nTime = numel(full);
nE = numel(eList);
Cm = zeros(numel(names), nTime, nE + 1);
rng = full(it0):full(end);
r = simulate(m, paths, rng, 'anticipate', false, 'contributions', true);
for q = 1:numel(vars)
    v = vars{q};
    i = find(strcmp(names, v), 1);
    s = r.(v);
    dat = s(rng);
    cm = cellstr(s.Comment);
    for c = 1:numel(cm)
        tok = regexp(cm{c}, '<-\(\+\)(.*)$', 'tokens', 'once');
        if isempty(tok)
            tok = {cm{c}};
        end
        nmC = strtrim(tok{1});
        j = find(strcmp(eList, nmC), 1);
        if ~isempty(j)
            Cm(i, it0:end, j) = dat(:, c)';
        elseif strncmp(nmC, 'Init', 4)
            Cm(i, it0:end, nE + 1) = dat(:, c)' - ss(i);
        end                                  % 'Nonlinear' goes to the residual
    end
    Cm(i, 1:it0-1, nE + 1) = 0;
end
check = struct('n_solve', 0, 'n_backward', 0);
end


function [Cm, check] = tv_contrib(m, spec, info, res, full, it0, X, E, Xdev, row, names, eList)
nTime = numel(full);
nV = numel(names);
nE = numel(eList);
nC = nE + 1;
Cm = zeros(nV, nTime, nC);
Cm(:, 1:it0-1, nC) = Xdev(:, 1:it0-1);     % initial conditions; shock components start at 0
recon = zeros(1, nTime);
sys = info.sys;
lv = info.learnVars;
nt = [];
if isfield(info, 'nt') && ~isempty(info.nt)
    nt = info.nt;                          % N agent types (phase P6)
    isBR = reshape(ismember(names, type_forecast_vars(nt, lv)), [], 1);
else
    isBR = reshape(endsWith(names, '_exp1_BR'), [], 1);
end
origin = double(res.dates.origin);
hasInv = isfield(res, 'inversion') && ~isempty(res.inversion) && isfield(res.inversion, 'params');
if hasInv
    invD = double(res.inversion.dates);
    pn = res.inversion.param_names;
end
lastKey = [];
cur = [];
nSolve = 0;
nBack = 0;
for it = it0:nTime
    t = full(it);
    td = double(t);
    % ---- parameters in the model at t ----
    P = [];
    if hasInv && any(abs(invD - td) < 1e-6)
        k = find(abs(invD - td) < 1e-6, 1);
        P = cell2struct(num2cell(res.inversion.params(:, k)), pn(:), 1);
    elseif td > origin + 1e-6
        P = forecast_params(sys, lv, res, t, nt);    % beliefs in force after the projection facility
    end
    % ---- solve (only when the parameters change) ----
    if isempty(P)
        key = 'RE';
    else
        key = cell2mat(struct2cell(P));
    end
    if ~isequal(key, lastKey)
        if isempty(P)
            mt = m;
            cur = struct('ss', hetlearn.engine.step('build', m, []), 'bw', []);
        else
            mt = assign(m, P);
            [mt, ok, msg] = hetlearn.engine.solve_model(mt, spec);
            nSolve = nSolve + 1;
            if ~ok
                error('hetlearn:decompose:solve', 'Period %s: the model in force does not solve (%s).', ...
                    char(dat2str(t)), msg);
            end
            u = userdata(mt);
            if isstruct(u) && isfield(u, 'hetlearn_backward')
                cur = struct('ss', [], 'bw', u.hetlearn_backward);
            elseif isstruct(u) && isfield(u, 'hetlearn_sspace')
                cur = struct('ss', u.hetlearn_sspace, 'bw', []);
            else
                cur = struct('ss', hetlearn.engine.step('build', mt, []), 'bw', []);
            end
        end
        lastKey = key;
    end
    rc = double(~(isempty(P) & isBR));     % RE-model periods: x_exp1_BR in res.paths is the history-stage forecast
    % ---- one period for every component (no constants) and the level check ----
    if ~isempty(cur.ss)
        sy = cur.ss;
        nm = sy.names;
        xbN = nm.xb_names;
        xbL = nm.xb_lags;
        eIdx = cellfun(@(e) nm.e_index.(e), eList);
    else
        bw = cur.bw;
        nBack = nBack + 1;
        xbN = bw.xb_names;
        xbL = bw.xb_lags;
        eIdx = cellfun(@(e) find(strcmp(bw.e_names, e), 1), eList);
    end
    nb = numel(xbN);
    XbC = zeros(nb, nC);
    xbLev = zeros(nb, 1);
    for i = 1:nb
        r = row.(xbN{i});
        XbC(i, :) = reshape(Cm(r, it - 1 - xbL(i), :), 1, nC);
        xbLev(i) = X(r, it - 1 - xbL(i));
    end
    ne = numel(eIdx);
    EC = zeros(numel(eIdx), nC);
    eLev = zeros(numel(eIdx), 1);
    if ~isempty(cur.ss)
        EC = zeros(numel(nm.e_names), nC);
        eLev = zeros(numel(nm.e_names), 1);
    else
        EC = zeros(numel(bw.e_names), nC);
        eLev = zeros(numel(bw.e_names), 1);
    end
    for j = 1:ne
        EC(eIdx(j), j) = E(j, it);
        eLev(eIdx(j)) = E(j, it);
    end
    if ~isempty(cur.ss)
        XC = sy.T * XbC + sy.R * EC;
        YC = sy.Z * XC(nm.nf+1:end, :) + sy.H * EC;
        xl = sy.T * xbLev + sy.R * eLev + sy.K;
        yl = sy.Z * xl(nm.nf+1:end) + sy.H * eLev + sy.D;
        err = 0;
        for i = nm.cur
            r = row.(nm.x_names{i});
            Cm(r, it, :) = reshape(XC(i, :), 1, 1, nC);
            err = max(err, rc(r) * abs(xl(i) - X(r, it)));
        end
        for i = 1:numel(nm.y_names)
            if isfield(row, nm.y_names{i})
                r = row.(nm.y_names{i});
                Cm(r, it, :) = reshape(YC(i, :), 1, 1, nC);
                err = max(err, rc(r) * abs(yl(i) - X(r, it)));
            end
        end
    else
        UC = -(bw.M \ (bw.Bb * XbC + bw.D * EC));
        XbCt = UC(bw.nf+1:end, :);
        YC = -(bw.F \ (bw.G * XbCt + bw.J * EC));
        ul = -(bw.M \ (bw.Bb * xbLev + bw.C + bw.D * eLev));
        yl = -(bw.F \ (bw.G * ul(bw.nf+1:end) + bw.H + bw.J * eLev));
        err = 0;
        for i = 1:bw.nf
            r = row.(bw.xf_names{i});
            Cm(r, it, :) = reshape(UC(i, :), 1, 1, nC);
            err = max(err, rc(r) * abs(ul(i) - X(r, it)));
        end
        for i = 1:bw.nb
            if bw.xb_lags(i) == 0
                r = row.(bw.xb_names{i});
                Cm(r, it, :) = reshape(UC(bw.nf + i, :), 1, 1, nC);
                err = max(err, rc(r) * abs(ul(bw.nf + i) - X(r, it)));
            end
        end
        for i = 1:numel(bw.y_names)
            r = row.(bw.y_names{i});
            Cm(r, it, :) = reshape(YC(i, :), 1, 1, nC);
            err = max(err, rc(r) * abs(yl(i) - X(r, it)));
        end
    end
    recon(it) = err;
end
check = struct();
check.recon_maxerr = max(recon);
check.recon_by_date = recon;
check.n_solve = nSolve;
check.n_backward = nBack;
end


function P = forecast_params(sys, lv, res, t, nt)
% Beliefs phi_{t-1} and the model share n1_model(t) from res.learning. N agent types (nt, phase P6):
% the keyed system's beliefs and every type's model share n_model_<k>(t) as its share parameter.
P = struct();
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    L = res.learning.(e.target);
    for k = 1:numel(e.param_names)
        P.(e.param_names{k}) = L.(e.param_names{k})(t - 1);
    end
end
if nargin >= 5 && ~isempty(nt)
    for i = 1:numel(lv)
        x = lv{i};
        b = nt.byvar.(x);
        for jj = 1:numel(b.names)
            P.(b.share_names{jj}) = res.learning.(x).(['n_model_' b.names{jj}])(t);
        end
    end
    return
end
for i = 1:numel(lv)
    x = lv{i};
    n1 = res.learning.(x).n1_model(t);
    P.(['n1_' x]) = n1;
    P.(['n2_' x]) = 1 - n1;
end
end
