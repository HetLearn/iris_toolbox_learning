function cfg = v2_ar2()
%V2_AR2  Model variant 2: AR(2) perceived law of motion for inflation.
%
%   cfg = v2_ar2()
%
%   As a1_learn with pinf_t = alpha + b1*pinf_{t-1} + b2*pinf_{t-2} as the
%   learners' PLM. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v2_ar2';
cfg.title = 'Variant 2: learning on inflation with an AR(2) PLM';
cfg.description = 'As a1_learn, with the inflation learners forecasting from an AR(2) with constant instead of an AR(1).';
cfg.beliefs.plm.default = 'ar2';
cfg.compare_with = {'a1_learn'};
end
