function cfg = a6_smooth_learn()
%A6_SMOOTH_LEARN  Application 6: learning on inflation over the RE-smoothed history 1966Q1-2026Q2.
%
%   cfg = a6_smooth_learn()
%
%   As a1_learn with origin 2026Q2: beliefs and shares learned on the
%   RE-smoothed history to 2026Q2. The history itself is the RE one (the
%   learning states are diagnostic there), so its decomposition is the RE
%   decomposition over 1966Q1-2026Q2. Writes compare_a6_smooth_re.csv.

cfg = a1_learn();
cfg.id = 'a6_smooth_learn';
cfg.title = 'App 6: learning on inflation over the RE-smoothed history 1966Q1-2026Q2';
cfg.description = 'Beliefs and shares of the inflation learners on the RE-smoothed history to 2026Q2 (the reference for the inversion).';
cfg.forecast.origin = qq(2026, 2);
cfg.forecast.horizon = 4;
cfg.compare_with = {'a6_smooth_re'};
end
