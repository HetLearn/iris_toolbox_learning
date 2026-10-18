function cfg = v2_var3()
%V2_VAR3  Model variant 2: VAR(1) perceived law of motion in inflation, output gap and policy rate.
%
%   cfg = v2_var3()
%
%   As a1_learn with a VAR(1) with constant over {pinf, ygap, r} (ygap = y - yf,
%   derived). Learning stays on inflation only: ygap and r are auxiliary VAR
%   equations that feed the inflation expectation. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v2_var3';
cfg.title = 'Variant 2: learning on inflation with a VAR(1) in inflation, output gap and rate';
cfg.description = 'As a1_learn, with the inflation learners forecasting from a VAR(1) in inflation, the output gap and the policy rate.';
cfg.beliefs.plm.derived.ygap = 'y - yf';
cfg.beliefs.plm.var = struct('variables', {{'pinf', 'ygap', 'r'}}, 'lags', 1, 'constant', true);
cfg.compare_with = {'a1_learn'};
end
