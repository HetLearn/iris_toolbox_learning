function cfg = v2_reg()
%V2_REG  Model variant 2: inflation PLM on lagged inflation, output gap and policy rate.
%
%   cfg = v2_reg()
%
%   As a1_learn with pinf_t = alpha + b1*pinf_{t-1} + b2*ygap_{t-1} + b3*r_{t-1}.
%   ygap = y - yf becomes a model variable (derived regressor); ygap and r get
%   their own auxiliary AR(1) PLMs, learned the same way, so the two-step
%   forecast is defined. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v2_reg';
cfg.title = 'Variant 2: learning on inflation with lagged inflation, output gap and rate as regressors';
cfg.description = 'As a1_learn, with the inflation learners regressing inflation on its lag, the lagged output gap and the lagged policy rate.';
cfg.beliefs.plm.derived.ygap = 'y - yf';
cfg.beliefs.plm.by_var.pinf = struct('regressors', {{'pinf{-1}', 'ygap{-1}', 'r{-1}'}}, 'constant', true);
cfg.compare_with = {'a1_learn'};
end
