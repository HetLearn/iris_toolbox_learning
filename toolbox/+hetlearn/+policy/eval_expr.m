function v = eval_expr(expr, getter)
%EVAL_EXPR  Evaluate a policy target or discount expression numerically (DESIGN 13).
%
%   v = hetlearn.policy.eval_expr(expr, getter)
%
%   Inputs
%     expr    text in IRIS notation: names, lags name{-k}, numbers, + - * / ^,
%             parentheses and MATLAB functions written as f(...) (exp, log,
%             sqrt, abs, ...); no leads, no $substitutions$ (the generator
%             expands those in spec.policy.discount)
%     getter  function handle getter(name, k): value of name lagged k periods
%             (k = 0 current), a column vector or a scalar (parameters)
%
%   Output
%     v       the expression with every operator applied elementwise
%
%   Example: eval_expr('4*(r - r{-1})', @(n, k) db.(n)(dates - k)).

expr = char(expr);
[tok, s, e] = regexp(expr, '(?<![\w.$])([A-Za-z]\w*)\>(\s*\{[^{}]*\})?', 'tokens', 'start', 'end');
vals = {};
out = '';
pos = 1;
for i = 1:numel(tok)
    name = tok{i}{1};
    sub = tok{i}{2};
    if isempty(sub) && ~isempty(regexp(expr(e(i)+1:end), '^\s*\(', 'once'))
        continue                                % function call, e.g. exp(...)
    end
    k = 0;
    if ~isempty(sub)
        lag = regexp(sub, '^\s*\{\s*-\s*(\d+)\s*\}$', 'tokens', 'once');
        if isempty(lag)
            error('hetlearn:policy:expr', ...
                'In "%s": only lags name{-k} are allowed (found %s%s).', expr, name, strtrim(sub));
        end
        k = str2double(lag{1});
    end
    vals{end+1} = getter(name, k); %#ok<AGROW>
    out = [out, expr(pos:s(i)-1), sprintf('V{%d}', numel(vals))]; %#ok<AGROW>
    pos = e(i) + 1;
end
out = [out, expr(pos:end)];
out = regexprep(out, '(?<!\.)([*/^])', '.$1');
f = str2func(['@(V) ' out]);
v = f(vals);
end
