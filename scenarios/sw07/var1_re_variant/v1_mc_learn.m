function cfg = v1_mc_learn()
%V1_MC_LEARN  Model variant 1: model-consistent RE agents instead of anchored ones.
%
%   cfg = v1_mc_learn()
%
%   As a1_learn with expectations.re_variant = 'model_consistent': the RE
%   agents forecast the heterogeneous economy itself (x{+1} of the model with
%   the learners in it), which is re-solved every quarter with the current
%   beliefs and shares. Writes compare_a1_learn.csv (this minus anchored).

cfg = a1_learn();
cfg.id = 'v1_mc_learn';
cfg.title = 'Variant 1: forecast from the 2022Q2 peak, learning on inflation, model-consistent RE agents';
cfg.description = 'As a1_learn, but the RE agents forecast the heterogeneous economy (re-solved every quarter) instead of using the pure-RE forecast.';
cfg.expectations.re_variant = 'model_consistent';
cfg.compare_with = {'a1_learn'};
end
