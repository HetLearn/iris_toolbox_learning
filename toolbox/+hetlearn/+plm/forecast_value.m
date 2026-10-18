function f = forecast_value(sys, phi, getLag, x, info)
%FORECAST_VALUE  Numeric BR one-step-ahead forecast E(x,1) (DESIGN 4.2).
%
%   f = hetlearn.plm.forecast_value(sys, phi, getLag, x)
%   f = hetlearn.plm.forecast_value(sys, phi, getLag, x, info)
%
%   Inputs
%     sys     closed PLM system from hetlearn.plm.build_system
%     phi     struct by target; phi.<v> is the coefficient column vector
%             ordered like sys.eq(i).param_names (constant first if any)
%     getLag  function handle getLag(name, k) returning the observed value
%             of variable name at t+k, called only with k <= -1 for
%             'lagged' and k <= 0 for 'current' (x_t itself)
%     x       target variable name
%     info    optional information set, 'lagged' | 'current'; default
%             sys.info (beliefs.info as recorded by build_system), else
%             'lagged'
%
%   Output
%     f       scalar, equal to hetlearn.plm.forecast_expr(sys, x, info)
%             evaluated with the same coefficients and data.
%
%   See also hetlearn.plm.forecast_expr.

if nargin < 5 || isempty(info)
    info = 'lagged';
    if isfield(sys, 'info') && ~isempty(sys.info)
        info = sys.info;
    end
end
switch char(info)
    case 'lagged'
        kmax = -1;
    case 'current'
        kmax = 0;
    otherwise
        error('hetlearn:plm:info', 'Information set must be ''lagged'' or ''current'' (got ''%s'').', char(info));
end
f = val(sys, phi, getLag, x, 1, kmax);
end


function s = val(sys, phi, getLag, v, h, kmax)
i = find(strcmp(sys.targets, v), 1);
if isempty(i)
    error('hetlearn:plm:noEquation', 'No PLM equation for %s.', v);
end
e = sys.eq(i);
c = phi.(v);
c = c(:);
if numel(c) ~= numel(e.param_names)
    error('hetlearn:plm:phiSize', 'phi.%s has %d elements, expected %d.', v, numel(c), numel(e.param_names));
end
s = 0;
p = 0;
if e.constant
    p = 1;
    s = c(1);
end
for j = 1:numel(e.reg_names)
    k = h - e.reg_lags(j);
    u = e.reg_names{j};
    if k <= kmax
        t = getLag(u, k);
    else
        t = val(sys, phi, getLag, u, k, kmax);
    end
    s = s + c(p + j) * t;
end
end
