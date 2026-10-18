function [phi0, R0] = training_ols(sys, db, range)
%TRAINING_OLS  Initial beliefs by OLS on a training sample (DESIGN 4.7).
%
%   [phi0, R0] = hetlearn.init.training_ols(sys, db, range)
%
%   Inputs
%     sys    closed PLM system from hetlearn.plm.build_system
%     db     databank (struct of IRIS Series) holding histories of every
%            variable in the system, e.g. the RE-smoothed history
%     range  training range of the target: [start, end] dates or a full
%            date vector; regressors are taken at t - l
%
%   Outputs
%     phi0   struct by target: OLS coefficients (param_names order)
%     R0     struct by target: sample second-moment matrix Z'Z / T
%
%   Periods with a missing (NaN) target or regressor are dropped. An error
%   is raised if fewer observations than coefficients remain.

range = range(:)';
if numel(range) == 2
    range = range(1):range(2);
end
phi0 = struct();
R0 = struct();
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    v = e.target;
    if ~isfield(db, v)
        error('hetlearn:init:noData', 'Databank has no series %s.', v);
    end
    y = series_values(db.(v), range);
    nr = numel(e.reg_names);
    Z = zeros(numel(range), nr);
    for j = 1:nr
        u = e.reg_names{j};
        if ~isfield(db, u)
            error('hetlearn:init:noData', 'Databank has no series %s.', u);
        end
        Z(:, j) = series_values(db.(u), range - e.reg_lags(j));
    end
    if e.constant
        Z = [ones(numel(range), 1), Z]; %#ok<AGROW>
    end
    ok = all(isfinite([y, Z]), 2);
    y = y(ok);
    Z = Z(ok, :);
    T = numel(y);
    if T < size(Z, 2)
        error('hetlearn:init:shortSample', ...
            'Training sample for %s has %d usable observations, %d needed.', v, T, size(Z, 2));
    end
    phi0.(v) = (Z' * Z) \ (Z' * y);
    R0.(v) = (Z' * Z) / T;
end
end


function x = series_values(s, dates)
x = s(dates);
x = double(x(:, 1));
x = x(:);
end
