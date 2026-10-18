function cfg = v2_ar1nc()
%V2_AR1NC  Model variant 2: AR(1) perceived law of motion for inflation without a constant.
%
%   cfg = v2_ar1nc()
%
%   As a1_learn with pinf_t = beta*pinf_{t-1}: the perceived mean of
%   inflation is fixed at zero (the steady state), only the persistence is
%   learned. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v2_ar1nc';
cfg.title = 'Variant 2: learning on inflation with an AR(1) PLM without constant';
cfg.description = 'As a1_learn, with the inflation learners forecasting from an AR(1) without constant, so only the persistence is learned.';
cfg.beliefs.plm.default = 'ar1_noconst';
cfg.compare_with = {'a1_learn'};
end
