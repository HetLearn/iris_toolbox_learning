function pol = setup(spec, meta, opts, P)
%SETUP  Policy settings of a run: mode, type, loss weights, discount, rule names (DESIGN 13).
%
%   pol = hetlearn.policy.setup(spec, meta, opts, P)
%
%   Inputs
%     spec  model spec (hetlearn.load_spec); spec.policy is optional
%     meta  generator meta (hetlearn.extend_model); meta.policy holds the
%           parsed spec.policy (rule equation, targets, expanded discount)
%     opts  merged options: policy.mode, .type, .loss, .discount
%     P     parameter struct of spec.params (evaluates the spec discount)
%
%   Output
%     pol   [] when the package has no spec.policy (then policy.mode =
%           'ramsey' is an error and no loss is computed); else a struct
%       .mode, .type     policy.mode ('rule' | 'ramsey'), policy.type
%       .ramsey          true for mode 'ramsey'
%       .wrapped         true if the generated file holds the rule inside
%                        !if <toggle> (rule label found)
%       .toggle          model-file switch ('ramsey')
%       .instrument, .rule_label   from spec.policy
%       .target_names    cellstr (spec order); .targets struct of expressions
%       .weights         struct by target: policy.loss (targets not named: 0)
%       .discount        numeric discount: policy.discount if given, else
%                        spec.policy.discount (substitutions expanded) at P
%       .discount_source 'spec' | 'option'; .discount_expr  spec text
%       .params          generated parameters to assign: w_<k>,
%                        ramsey_disc_on (1 = override), ramsey_disc
%       .rule_vars, .rule_shocks   names used only by the rule and its own
%                        processes (SW07: ms, em); in a Ramsey model they move
%                        nothing else
%       .multipliers, .rule_model, .rule_assign   filled by hetlearn.load_model
%                        for Ramsey runs (IRIS Lagrange multipliers; solved rule
%                        model with the same toggles; its assign struct)
%
%   Errors: hetlearn:policy:noSpec, :rule (label not found), :unknownTarget,
%   :loss, :discount.

mode = opts.policy.mode;
hasSpec = isfield(meta, 'policy') && isstruct(meta.policy) && ~isempty(meta.policy) ...
    && isfield(meta.policy, 'has') && meta.policy.has;
if ~hasSpec
    if strcmp(mode, 'ramsey')
        error('hetlearn:policy:noSpec', ...
            'policy.mode = ''ramsey'' needs a policy section (spec.policy) in the model package %s.', spec.name);
    end
    pol = [];
    return
end
mp = meta.policy;
if strcmp(mode, 'ramsey') && ~mp.ok
    error('hetlearn:policy:rule', 'policy.mode = ''ramsey'': %s', mp.error);
end

% ---- loss weights ----------------------------------------------------------------------
names = mp.target_names;
L = opts.policy.loss;
if ~isstruct(L) || ~isscalar(L)
    error('hetlearn:policy:loss', 'policy.loss must be a struct of weights by target name.');
end
f = fieldnames(L)';
bad = setdiff(f, names, 'stable');
if ~isempty(bad)
    error('hetlearn:policy:unknownTarget', ...
        'policy.loss names unknown target(s) %s; the targets of %s (spec.policy.targets) are %s.', ...
        strjoin(bad, ', '), spec.name, strjoin(names, ', '));
end
W = struct();
for i = 1:numel(names)
    W.(names{i}) = 0;
    if isfield(L, names{i})
        w = L.(names{i});
        if ~(isnumeric(w) && isscalar(w) && isfinite(w) && w >= 0)
            error('hetlearn:policy:loss', 'policy.loss.%s must be a non-negative number.', names{i});
        end
        W.(names{i}) = double(w);
    end
end

% ---- discount -------------------------------------------------------------------------------
if isempty(opts.policy.discount)
    try
        disc = hetlearn.policy.eval_expr(mp.discount_expanded, @(n, k) param_value(P, n, k));
    catch err
        error('hetlearn:policy:discount', 'spec.policy.discount = %s cannot be evaluated: %s', ...
            mp.discount, err.message);
    end
    src = 'spec';
else
    disc = double(opts.policy.discount);
    src = 'option';
end
if ~(isscalar(disc) && isfinite(disc) && disc > 0)
    error('hetlearn:policy:discount', 'The policy discount must be a positive number (got %g).', disc);
end

% ---- generated parameters --------------------------------------------------------------
prm = struct();
for i = 1:numel(names)
    prm.(mp.weight_params.(names{i})) = W.(names{i});
end
prm.(mp.disc_params{1}) = double(strcmp(src, 'option'));
prm.(mp.disc_params{2}) = 0;
if strcmp(src, 'option')
    prm.(mp.disc_params{2}) = disc;
end

pol = struct();
pol.mode = mode;
pol.type = opts.policy.type;
pol.ramsey = strcmp(mode, 'ramsey');
pol.wrapped = mp.ok;
pol.toggle = mp.toggle;
pol.instrument = mp.instrument;
pol.rule_label = mp.rule_label;
pol.target_names = names;
pol.targets = mp.targets;
pol.weights = W;
pol.discount = disc;
pol.discount_source = src;
pol.discount_expr = mp.discount;
pol.params = prm;
pol.rule_vars = mp.rule_vars;
pol.rule_shocks = mp.rule_shocks;
pol.multipliers = {};
pol.rule_model = [];
pol.rule_assign = [];
end


function v = param_value(P, name, k)
if k ~= 0 || ~isfield(P, name)
    error('hetlearn:policy:discount', '%s is not a parameter of spec.params.', name);
end
v = P.(name);
end
