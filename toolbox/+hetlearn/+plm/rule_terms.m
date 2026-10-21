function R = rule_terms(rule, x, k, info, tvars)
%RULE_TERMS  Parse the expression of a 'rule' agent type for one variable (DESIGN_br_extensions 1.1).
%
%   R = hetlearn.plm.rule_terms(rule, x, k, info, tvars)
%
%   Inputs
%     rule   the type's rule (expectations.types(i).rule): an expression,
%            e.g. '0.65*x{-1} + 0.35*self{-1}', or struct('expr', <expression>,
%            'params', struct of numbers)
%     x      the learning variable the type forecasts
%     k      the type name
%     info   'lagged' (data up to t-1: every data term needs a lag >= 1) |
%            'current' (period-t data allowed, lag >= 0)
%     tvars  cellstr of the transition variables of the model
%
%   Terms of the expression (linear in them; numbers, + - * / and
%   parentheses otherwise; lags written v{-k}):
%     x          the variable itself (x{-1}, x{-2}, ...; x = period t under 'current')
%     self       this type's own forecast; only with a lag >= 1 (self{-1} = the
%                forecast of x_t made in t-1), so a rule with self{-1} is a
%                backward equation in its own lag (ADA)
%     mean       a mean-only belief of this type about x, learned like a PLM
%                constant (parameter alpha_<x>__<k>, updated by RLS on a
%                constant with the type's gain; no lag)
%     dn         nominal growth y - y{-1} + pinf (needs transition variables y
%                and pinf): dn{-1} = y{-1} - y{-2} + pinf{-1}
%     <param>    a constant of struct(..., 'params', ...): model parameter
%                <param>__<k>, no lag
%     <name>     any other transition variable of the model, with a lag
%   re1(...) (anchored E_{t-1}, phase P4) and other functions are errors.
%
%   Output R (struct)
%     .text          IRIS right-hand side of <x>_exp1_<k> = ...
%     .mexpr         MATLAB expression in v(j), one j per term (engine
%                    evaluation: f = str2func(['@(v) ' R.mexpr]))
%     .terms         struct array, one per term: kind ('var' | 'self' | 'mean' |
%                    'param'), name (variable, parameter or ''), lag (>= 0)
%     .param_names   struct: param -> model parameter name '<param>__<k>'
%     .param_values  struct: param -> value
%     .maxlag        largest data lag (dn{-k} counts k + 1)
%     .self_maxlag   largest lag of self (0 = no self term)
%     .uses_mean     true if mean occurs; .mean_param 'alpha_<x>__<k>' or ''
%     .expr          the expression as given
%
%   Errors hetlearn:types:rule (syntax, unknown names, timing, a leading
%   self, nonlinear terms).

ID = 'hetlearn:types:rule';
params = struct();
if isstruct(rule)
    expr = rule.expr;
    if isfield(rule, 'params') && ~isempty(rule.params)
        params = rule.params;
    end
else
    expr = rule;
end
expr = strtrim(char(expr));
tvars = reshape(cellstr(tvars), 1, []);
info = char(info);
minLag = 1;
if strcmp(info, 'current')
    minLag = 0;
end
pn = fieldnames(params)';

R = struct('text', '', 'mexpr', '', 'terms', struct('kind', {}, 'name', {}, 'lag', {}), ...
    'param_names', struct(), 'param_values', struct(), 'maxlag', 0, 'self_maxlag', 0, ...
    'uses_mean', false, 'mean_param', '', 'expr', expr);
for i = 1:numel(pn)
    R.param_names.(pn{i}) = sprintf('%s__%s', pn{i}, k);
    R.param_values.(pn{i}) = double(params.(pn{i}));
end
where = sprintf('the rule ''%s'' of type %s for %s', expr, k, x);

txt = {};
mx = {};
p = 1;
n = numel(expr);
while p <= n
    rest = expr(p:end);
    tok = regexp(rest, '^\s+', 'match', 'once');
    if ~isempty(tok)
        txt{end+1} = tok; mx{end+1} = tok; %#ok<AGROW>
        p = p + numel(tok);
        continue
    end
    tok = regexp(rest, '^(\d+\.?\d*([eE][+-]?\d+)?|\.\d+([eE][+-]?\d+)?)', 'match', 'once');
    if ~isempty(tok)
        txt{end+1} = tok; mx{end+1} = tok; %#ok<AGROW>
        p = p + numel(tok);
        continue
    end
    tok = regexp(rest, '^[\+\-\*/\(\)]', 'match', 'once');
    if ~isempty(tok)
        txt{end+1} = tok; mx{end+1} = tok; %#ok<AGROW>
        p = p + 1;
        continue
    end
    [tk, len] = name_token(rest);
    if isempty(tk)
        error(ID, 'Cannot read %s at ''%s''.', where, rest);
    end
    p = p + len;
    nm = tk.name;
    lag = tk.lag;
    if tk.call
        if strcmp(nm, 're1')
            error(ID, ['%s uses re1(...) (the anchored E_{t-1} forecast of an expression), which phase P4 ' ...
                '(generalised anchor) builds.'], where);
        end
        error(ID, '%s calls a function %s(...); only re1(...) is planned (phase P4).', where, nm);
    end
    if tk.lead
        error(ID, '%s: %s has a lead; rules use lags only.', where, nm);
    end
    switch nm
        case 'x'
            [R, j] = add_term(R, 'var', x, check_lag(lag, minLag, nm, where, info));
            [txt, mx] = put(txt, mx, var_text(x, lag), j);
        case 'self'
            if ~tk.braced || lag < 1
                error(ID, '%s: self needs a lag of 1 or more (self{-1} = the forecast made last period).', where);
            end
            [R, j] = add_term(R, 'self', '', lag);
            R.self_maxlag = max(R.self_maxlag, lag);
            [txt, mx] = put(txt, mx, sprintf('%s_exp1_%s{-%d}', x, k, lag), j);
        case 'mean'
            if tk.braced
                error(ID, '%s: mean is a belief in force in t (no lag).', where);
            end
            R.uses_mean = true;
            R.mean_param = sprintf('alpha_%s__%s', x, k);
            [R, j] = add_term(R, 'mean', '', 0);
            [txt, mx] = put(txt, mx, R.mean_param, j);
        case 'dn'
            if ~all(ismember({'y', 'pinf'}, tvars))
                error(ID, '%s: dn (nominal growth y - y{-1} + pinf) needs transition variables y and pinf.', where);
            end
            check_lag(lag, minLag, nm, where, info);
            [R, a] = add_term(R, 'var', 'y', lag);
            [R, b] = add_term(R, 'var', 'y', lag + 1);
            [R, c] = add_term(R, 'var', 'pinf', lag);
            txt{end+1} = sprintf('(%s - %s + %s)', var_text('y', lag), var_text('y', lag + 1), var_text('pinf', lag)); %#ok<AGROW>
            mx{end+1} = sprintf('(v(%d) - v(%d) + v(%d))', a, b, c); %#ok<AGROW>
        otherwise
            if any(strcmp(pn, nm))
                if tk.braced
                    error(ID, '%s: the constant %s takes no lag.', where, nm);
                end
                [R, j] = add_term(R, 'param', nm, 0);
                [txt, mx] = put(txt, mx, R.param_names.(nm), j);
            elseif any(strcmp(tvars, nm))
                [R, j] = add_term(R, 'var', nm, check_lag(lag, minLag, nm, where, info));
                [txt, mx] = put(txt, mx, var_text(nm, lag), j);
            else
                error(ID, ['%s: unknown name %s (terms: x, self, mean, dn, the constants in params, or a ' ...
                    'transition variable of the model).'], where, nm);
            end
    end
end
R.text = strtrim([txt{:}]);
R.mexpr = strtrim([mx{:}]);
if isempty(R.text)
    error(ID, '%s is empty.', where);
end
lags = [R.terms(strcmp({R.terms.kind}, 'var')).lag];
if ~isempty(lags)
    R.maxlag = max(lags);
end
check_linear(R, where, ID);
end


% -------------------------------------------------------------------------
function [tk, len] = name_token(s)
% name, optional {lag} subscript, and whether a '(' follows (a function call)
tk = [];
len = 0;
[tok, e] = regexp(s, '^([A-Za-z]\w*)', 'tokens', 'end', 'once');
if isempty(tok)
    return
end
tk = struct('name', tok{1}, 'lag', 0, 'braced', false, 'lead', false, 'call', false);
len = e;
rest = s(e+1:end);
[sub, e2] = regexp(rest, '^\s*\{\s*([+-]?)\s*(\d+)\s*\}', 'tokens', 'end', 'once');
if ~isempty(sub)
    v = str2double(sub{2});
    if strcmp(sub{1}, '-')
        tk.lag = v;
    else
        tk.lag = -v;
        tk.lead = v > 0;
    end
    tk.braced = true;
    len = len + e2;
    rest = rest(e2+1:end);
end
tk.call = ~isempty(regexp(rest, '^\s*\(', 'once')) && ~tk.braced;
end


function lag = check_lag(lag, minLag, nm, where, info)
if lag < minLag
    error('hetlearn:types:rule', ['%s: %s with lag %d is not in the information set (''%s'': data up to ' ...
        't-%d; write %s{-%d}).'], where, nm, lag, info, minLag, nm, max(minLag, 1));
end
end


function s = var_text(v, lag)
if lag == 0
    s = v;
else
    s = sprintf('%s{-%d}', v, lag);
end
end


function [R, j] = add_term(R, kind, name, lag)
for j = 1:numel(R.terms)
    if strcmp(R.terms(j).kind, kind) && strcmp(R.terms(j).name, name) && R.terms(j).lag == lag
        return
    end
end
R.terms(end+1) = struct('kind', kind, 'name', name, 'lag', lag);
j = numel(R.terms);
end


function [txt, mx] = put(txt, mx, t, j)
txt{end+1} = t;
mx{end+1} = sprintf('v(%d)', j);
end


function check_linear(R, where, ID)
% the rule must be affine in its data terms, the constants held at their values (an IRIS linear model
% would linearise it silently)
try
    f = str2func(['@(v) ' R.mexpr]);
    nT = max(1, numel(R.terms));
    isP = false(nT, 1);
    v0 = zeros(nT, 1);
    for j = 1:numel(R.terms)
        if strcmp(R.terms(j).kind, 'param')
            isP(j) = true;
            v0(j) = R.param_values.(R.terms(j).name);
        end
    end
    rs = RandStream('mt19937ar', 'Seed', 20261020);
    a = (rand(rs, nT, 1) + 0.5) .* ~isP;
    b = (rand(rs, nT, 1) - 1.5) .* ~isP;
    f0 = f(v0);
    fa = f(v0 + a);
    fb = f(v0 + b);
    fab = f(v0 + a + 2 * b);
catch err
    error(ID, '%s is not a valid expression: %s', where, err.message);
end
if ~(isscalar(f0) && isfinite(f0) && isfinite(fa) && isfinite(fb) && isfinite(fab))
    error(ID, '%s does not evaluate to a finite number.', where);
end
d = abs((fab - f0) - ((fa - f0) + 2 * (fb - f0)));
if d > 1e-9 * max([1, abs(fa), abs(fb), abs(fab)])
    error(ID, '%s is not linear in its terms (products or quotients of terms are not allowed).', where);
end
end
