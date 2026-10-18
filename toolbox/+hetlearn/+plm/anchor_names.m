function [names, vars, lags] = anchor_names(x, states)
%ANCHOR_NAMES  Parameter names of the anchored RE forecast of x (DESIGN 11).
%
%   [names, vars, lags] = hetlearn.plm.anchor_names(x, states)
%
%   Inputs
%     x       forward-looking variable name
%     states  cellstr of IRIS state names (get(m, 'xbVector') of the original
%             model): 'v' (current value) or 'v{-k}' (auxiliary lag k)
%
%   Outputs
%     names   cellstr, 1 + numel(states): 'are_<x>__const', then per state
%             'are_<x>__<v>' (current) or 'are_<x>__<v>_l<k>' (lag k)
%     vars    cellstr of state variable names (v), aligned with states
%     lags    vector of lags k (0 = current), aligned with states
%
%   The anchored equation written by hetlearn.extend_model is
%     x_exp1_RE = are_x__const + sum_j names{1+j} * vars{j}{-lags(j)};
%   Errors (hetlearn:anchor:state) on a state name that is not of the
%   form v or v{-k}, e.g. a log variable printed as log(v).

states = reshape(cellstr(states), 1, []);
n = numel(states);
names = cell(1, n + 1);
vars = cell(1, n);
lags = zeros(1, n);
names{1} = ['are_' x '__const'];
for j = 1:n
    tl = regexp(states{j}, '^([A-Za-z]\w*)\{-(\d+)\}$', 'tokens', 'once');
    t0 = regexp(states{j}, '^([A-Za-z]\w*)$', 'tokens', 'once');
    if ~isempty(tl)
        vars{j} = tl{1};
        lags(j) = str2double(tl{2});
        names{j + 1} = sprintf('are_%s__%s_l%d', x, tl{1}, lags(j));
    elseif ~isempty(t0)
        vars{j} = t0{1};
        lags(j) = 0;
        names{j + 1} = sprintf('are_%s__%s', x, t0{1});
    else
        error('hetlearn:anchor:state', ...
            'State ''%s'' is not of the form v or v{-k}; the anchored RE variant needs plain names.', states{j});
    end
end
end
