function L = loss(res, F, opts, info)
%LOSS  Discounted policy loss of a scenario, for rule and Ramsey runs alike (DESIGN 13).
%
%   L = hetlearn.policy.loss(res, F, opts, info)
%
%   Inputs
%     res   result of hetlearn.engine.core (paths, state, dates)
%     F     forecast-stage bundle of hetlearn.engine.core (ctx, m)
%     opts  merged options: policy.loss (weights), policy.discount,
%           policy.loss_horizon
%     info  second output of hetlearn.load_model (info.policy, info.params)
%
%   Output L ([] when the package has no spec.policy)
%     .total        sum_{h=1..N} disc^h sum_k w_k target_k(origin+h)^2
%     .by_target.<k>  contribution of target k (they sum to .total)
%     .weights, .targets (expressions), .target_names, .discount,
%     .discount_source ('spec' | 'option'), .mode, .type
%     .horizon      N = policy.loss_horizon ([] = forecast.horizon)
%     .forecast_horizon  H
%     .continuation true if N > H: periods H+1..N continue the scenario
%                   with zero shocks and no conditions (hetlearn.engine.
%                   forecast from res.state, same model and learning rules)
%     .dates        cellstr of the N dates; .values.<k> target path (N x 1);
%                   .period_loss sum_k w_k target_k^2 (N x 1); .disc_factor
%     .error        '' or the message of a failed continuation (then .total
%                   and .by_target are NaN and a warning is issued)

pol = [];
if isfield(info, 'policy')
    pol = info.policy;
end
if isempty(pol)
    L = [];
    return
end
hz = res.dates.horizon;
H = numel(hz);
N = opts.policy.loss_horizon;
if isempty(N)
    N = H;
end
origin = res.dates.origin;
dates = origin + 1 : origin + N;
names = pol.target_names;

L = struct();
L.mode = pol.mode;
L.type = pol.type;
L.discount = pol.discount;
L.discount_source = pol.discount_source;
L.weights = pol.weights;
L.targets = pol.targets;
L.target_names = names;
L.horizon = N;
L.forecast_horizon = H;
L.continuation = N > H;
L.dates = hetlearn.util.date_str(double(dates));
L.error = '';
L.total = NaN;
L.by_target = struct();
L.values = struct();
for i = 1:numel(names)
    L.by_target.(names{i}) = NaN;
    L.values.(names{i}) = NaN(N, 1);
end
L.period_loss = NaN(N, 1);
L.disc_factor = pol.discount .^ (1:N)';

db = res.paths;
if N > H
    try
        db = continuation(res, F, N - H);
    catch err
        L.error = err.message;
        warning('hetlearn:policy:continuation', ...
            'Loss continuation %s+1..+%d of %s failed: %s', char(dat2str(hz(end))), N - H, opts.id, err.message);
        return
    end
end
P = info.params;
getv = @(n, k) value(db, P, n, k, dates);
tot = 0;
pl = zeros(N, 1);
for i = 1:numel(names)
    v = hetlearn.policy.eval_expr(pol.targets.(names{i}), getv);
    v = v(:) .* ones(N, 1);
    w = pol.weights.(names{i});
    L.values.(names{i}) = v;
    L.by_target.(names{i}) = w * sum(L.disc_factor .* v.^2);
    tot = tot + L.by_target.(names{i});
    pl = pl + w * v.^2;
end
L.total = tot;
L.period_loss = pl;
end


function db = continuation(res, F, n)
% Continue the scenario n periods past the horizon: zero shocks, no conditions.
ctx = F.ctx;
hz = res.dates.horizon;
ctx.horizon = hz(end) + 1 : hz(end) + n;
ctx.quiet = true;
d = res.paths;
for i = 1:numel(ctx.eList)
    d.(ctx.eList{i})(ctx.horizon) = 0;
end
rec = hetlearn.engine.record([], n, ctx);
C = repmat(struct('vars', {{}}, 'shocks', {{}}, 'targets', zeros(0, 1)), 1, n);
[~, ~, ~, db] = hetlearn.engine.forecast(ctx, res.state, d, rec, 0, F.m, C);
end


function v = value(db, P, name, k, dates)
if isfield(db, name) && isa(db.(name), 'Series')
    v = db.(name)(dates - k);
    v = v(:);
elseif isfield(P, name)
    v = P.(name);
else
    error('hetlearn:policy:loss', 'Target name %s is neither a variable of the scenario nor a parameter.', name);
end
end
