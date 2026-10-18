function H = prepare(H, info, opts)
%PREPARE  Ramsey runs: zero multipliers in the RE history and one warning on rule inputs (DESIGN 13).
%
%   H = hetlearn.policy.prepare(H, info, opts)
%
%   Inputs
%     H     RE filter output (hetlearn.re_filter, always the rule model)
%     info  second output of hetlearn.load_model (info.policy)
%     opts  merged options (shocks, conditions)
%
%   Output
%     H     unchanged for rule runs. Ramsey runs: H.smooth gets a zero series
%           for every Lagrange multiplier (info.policy.multipliers) over the
%           range of the instrument's smoothed series, so the forecast
%           databank holds zero multipliers at and before the origin (the
%           plan starts at the origin; hetlearn.engine.forecast carries
%           their lags forward).
%
%   Warning hetlearn:policy:ruleInputs (once per run): shocks or conditions
%   that refer to names used only by the policy rule (info.policy.rule_vars,
%   .rule_shocks, e.g. SW07 ms and em) still run but move nothing else under
%   Ramsey policy.

pol = [];
if isfield(info, 'policy')
    pol = info.policy;
end
if isempty(pol) || ~pol.ramsey
    return
end
ref = H.smooth.(pol.instrument);
rng = ref.Start:ref.End;
for i = 1:numel(pol.multipliers)
    H.smooth.(pol.multipliers{i}) = Series(rng, zeros(numel(rng), 1));
end

refs = {};
sh = opts.shocks;
if strcmp(sh.source, 'smoothed')
    x = setdiff(pol.rule_shocks, sh.exclude, 'stable');
    refs = [refs, strcat('smoothed shock ', x)];
end
for i = 1:numel(sh.add)
    a = sh.add{i};
    if iscell(a) && ~isempty(a) && any(strcmp(pol.rule_shocks, char(a{1})))
        refs{end+1} = ['shocks.add ' char(a{1})]; %#ok<AGROW>
    end
end
cs = opts.conditions;
for i = 1:numel(cs)
    v = cellstr(cs(i).variable);
    e = cellstr(cs(i).shock);
    if any(ismember(v, pol.rule_vars)) || any(ismember(e, pol.rule_shocks))
        refs{end+1} = sprintf('condition %s / %s', strjoin(v, ','), strjoin(e, ',')); %#ok<AGROW>
    end
end
if ~isempty(refs)
    warning('hetlearn:policy:ruleInputs', ...
        ['Ramsey policy (%s, %s): %s refer to the policy rule (rule-only names: %s); they run ' ...
        'but have no effect on the other variables.'], opts.id, pol.type, strjoin(unique(refs, 'stable'), '; '), ...
        strjoin([pol.rule_vars, pol.rule_shocks], ', '));
end
end
