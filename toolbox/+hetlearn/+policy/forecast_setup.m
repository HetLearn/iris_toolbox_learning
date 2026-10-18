function [d, C] = forecast_setup(ctx, d, C)
%FORECAST_SETUP  Ramsey forecast stage: zero multipliers at and before the origin; rule-only conditions (DESIGN 13).
%
%   [d, C] = hetlearn.policy.forecast_setup(ctx, d, C)
%
%   Inputs
%     ctx  engine context (ctx.info.policy, ctx.origin)
%     d    forecast databank (hetlearn.engine.build_shocks)
%     C    conditions by period (hetlearn.engine.conditions_prepare)
%
%   Outputs (unchanged unless ctx.info.policy.ramsey)
%     d    every Lagrange multiplier is 0 at and before ctx.origin (created
%          if missing); later values are kept, so a continuation call
%          (hetlearn.policy.loss) carries the lags forward
%     C    in periods whose endogenised shocks are all rule-only shocks
%          (e.g. em), exogenised variables other than rule-only variables
%          (e.g. r, which the planner now sets) are dropped: those targets
%          cannot be met under Ramsey policy. Conditions on rule-only
%          variables (ms via em) run and move nothing else.
%          hetlearn.policy.prepare warns about such inputs once per run.

pol = [];
if isfield(ctx, 'info') && isfield(ctx.info, 'policy')
    pol = ctx.info.policy;
end
if isempty(pol) || ~pol.ramsey
    return
end
origin = ctx.origin;
start = [];
for i = 1:numel(pol.multipliers)
    mu = pol.multipliers{i};
    if isfield(d, mu) && isa(d.(mu), 'Series') && ~isempty(d.(mu).Start) && double(d.(mu).Start) <= double(origin)
        d.(mu)(d.(mu).Start:origin) = 0;
    else
        if isempty(start)
            start = d.(pol.instrument).Start;
        end
        d.(mu) = Series(start:origin, zeros(numel(start:origin), 1));
    end
end
for k = 1:numel(C)
    if isempty(C(k).vars) || isempty(C(k).shocks) || ~all(ismember(C(k).shocks, pol.rule_shocks))
        continue
    end
    keep = ismember(C(k).vars, pol.rule_vars);
    C(k).vars = C(k).vars(keep);
    C(k).targets = C(k).targets(keep);
    if ~any(keep)
        C(k).shocks = {};
    end
end
end
