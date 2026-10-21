function cfg = br25b_kf_average()
%BR25B_KF_AVERAGE  BR portfolio 25b: equal-weight average of five small forecasting models learned by the Kalman filter (Slobodyan and Wouters 2012a).
%
%   cfg = br25b_kf_average()
%
%   As a1_learn, with docs/DESIGN_br_extensions.md mechanism 25 and the 25b
%   row of section 3: for each sticky forward expectation x (inve, pk, rk, c,
%   lab, pinf, w) five learned models with fixed weights 0.2 each (mode
%   'fixed_shares', no RE agents): M1 AR(1); M2 AR(1) plus r_{t-1} and
%   pinf_{t-1}; M3 AR(2); M4 AR(1) plus pinf_{t-1}; M5 AR(1) plus r_{t-1},
%   pinf_{t-1} and y_{t-1}, each with a constant. For x = pinf, M4 is M1 and
%   M2 has pinf_{t-1} once. Kalman-filter learning with gamma = 0.031 (SW
%   2008 draft); gain.rule = 'constant' with gain.value = 0.031 so that the
%   recorded gain shows gamma. The flex block stays RE (D2). Writes
%   compare_a1_learn.csv and compare_a1_re.csv when it completes.

cfg = a1_learn();
cfg.id = 'br25b_kf_average';
cfg.title = 'BR 25b: equal-weight average of five small models learned by the Kalman filter';
cfg.description = 'As a1_learn, with each sticky-economy forward expectation the equal-weight average of five small models (AR(1), AR(2), AR(1) plus rate, inflation or output) learned by the Kalman filter, gamma = 0.031.';
ST7 = {'inve', 'pk', 'rk', 'c', 'lab', 'pinf', 'w'};
cfg.expectations.variables = ST7;
cfg.expectations.mode = 'fixed_shares';
cfg.expectations.types = { ...
    struct('name', 'M1', 'kind', 'plm', 'update', 'kf'), ...                                            % AR(1)
    struct('name', 'M2', 'kind', 'plm', 'plm', small_model(ST7, {'r{-1}', 'pinf{-1}'}), 'update', 'kf'), ...  % AR(1) + r, pinf
    struct('name', 'M3', 'kind', 'plm', 'plm', 'ar2', 'update', 'kf'), ...                              % AR(2)
    struct('name', 'M4', 'kind', 'plm', 'plm', small_model(ST7, {'pinf{-1}'}), 'update', 'kf'), ...     % AR(1) + pinf
    struct('name', 'M5', 'kind', 'plm', 'plm', small_model(ST7, {'r{-1}', 'pinf{-1}', 'y{-1}'}), 'update', 'kf')};  % AR(1) + r, pinf, y
cfg.shares.fixed = struct('M1', 0.2, 'M2', 0.2, 'M3', 0.2, 'M4', 0.2, 'M5', 0.2);
cfg.beliefs.kf.gamma = 0.031;
cfg.gain.rule = 'constant';
cfg.gain.value = 0.031;                       % the recorded gain column shows gamma
cfg.compare_with = {'a1_learn', 'a1_re'};
end


function p = small_model(vars, extra)
% Partial beliefs.plm subtree: for every variable its own first lag plus the extra regressors
% (a regressor already in the list is not repeated), with a constant.
p = struct('by_var', struct());
for i = 1:numel(vars)
    r = unique([{[vars{i} '{-1}']}, extra], 'stable');
    p.by_var.(vars{i}) = struct('regressors', {r}, 'constant', true);
end
end
