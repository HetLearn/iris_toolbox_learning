function txt = forecast_expr(sys, x, info)
%FORECAST_EXPR  IRIS text of the BR one-step-ahead forecast E(x,1) (DESIGN 4.2).
%
%   txt = hetlearn.plm.forecast_expr(sys, x)
%   txt = hetlearn.plm.forecast_expr(sys, x, info)
%
%   Inputs
%     sys   closed PLM system from hetlearn.plm.build_system
%     x     target variable name (must be in sys.targets)
%     info  optional information set, 'lagged' | 'current'; default sys.info
%           (build_system records beliefs.info there), else 'lagged'
%
%   Output
%     txt  char, nested expression built from
%            E(v,h) = alpha_v + sum_j beta_vj * T(u_j, h - l_j)
%            T(u,k) = u{k} if k <= kmax, else (E(u,k))
%          kmax = -1 for 'lagged' (data up to t-1, the user's spec) and 0 for
%          'current' (period-t data, IJCB eq. 12; u{0} is written u). For
%          the default AR(1) PLM:
%            'lagged'   alpha_x + beta_x*(alpha_x + beta_x*x{-1})
%            'current'  alpha_x + beta_x*x
%          Under 'current' every regressor lag is >= 1, so E(x,1) never
%          recurses: AR(2) alpha + b1*x + b2*x{-1}, VAR(1) alpha + B*X_t.
%
%   See also hetlearn.plm.forecast_value, hetlearn.plm.build_system.

if nargin < 3 || isempty(info)
    info = 'lagged';
    if isfield(sys, 'info') && ~isempty(sys.info)
        info = sys.info;
    end
end
kmax = info_kmax(info);
txt = expr(sys, x, 1, kmax);
end


function s = expr(sys, v, h, kmax)
i = find(strcmp(sys.targets, v), 1);
if isempty(i)
    error('hetlearn:plm:noEquation', 'No PLM equation for %s.', v);
end
e = sys.eq(i);
terms = {};
p = 0;
if e.constant
    p = 1;
    terms{end+1} = e.param_names{1};
end
for j = 1:numel(e.reg_names)
    k = h - e.reg_lags(j);
    u = e.reg_names{j};
    if k == 0 && kmax == 0
        t = u;
    elseif k <= kmax
        t = sprintf('%s{%d}', u, k);
    else
        t = ['(' expr(sys, u, k, kmax) ')'];
    end
    terms{end+1} = [e.param_names{p + j} '*' t]; %#ok<AGROW>
end
s = strjoin(terms, ' + ');
end


function kmax = info_kmax(info)
switch char(info)
    case 'lagged'
        kmax = -1;
    case 'current'
        kmax = 0;
    otherwise
        error('hetlearn:plm:info', 'Information set must be ''lagged'' or ''current'' (got ''%s'').', char(info));
end
end
