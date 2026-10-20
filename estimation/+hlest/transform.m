function y = transform(dir, v, lb, ub)
%TRANSFORM  Map between the bounded parameter space and an unbounded one (logistic).
%
%   u = hlest.transform('u', x, lb, ub)      x in (lb, ub) -> u = log((x-lb)/(ub-x))
%   x = hlest.transform('x', u, lb, ub)      x = lb + (ub-lb) logistic(u)
%   J = hlest.transform('dxdu', u, lb, ub)   dx/du at u (column)
%
%   Every estimated parameter has two finite bounds, so one transformation serves all.

switch dir
    case 'u'
        r = (v - lb)./(ub - lb);
        y = log(r) - log1p(-r);
    case 'x'
        y = lb + (ub - lb)./(1 + exp(-v));
    case 'dxdu'
        e = 1./(1 + exp(-v));
        y = (ub - lb).*e.*(1 - e);
    otherwise
        error('hlest:transform:dir', 'Unknown direction %s.', dir);
end
end
