function cfg = v4_const_full()
%V4_CONST_FULL  Model variant 4: constant gain 0.05 over the history 1966Q1-2026Q2.
%
%   cfg = v4_const_full()
%
%   As v4_const with origin 2026Q2 and horizon 4: beliefs and shares under the
%   constant gain over the whole history to 2026Q2. The baseline (KOZ gain)
%   counterpart is a6_smooth_learn; writes compare_a6_smooth_learn.csv.
%   Replaces v4_koz_full (2026-10-20).

cfg = v4_const();
cfg.id = 'v4_const_full';
cfg.title = 'Variant 4: constant gain of 0.05 on the history 1966Q1-2026Q2';
cfg.description = 'The learning-on-inflation model with the gain held at 0.05 over the history to 2026Q2 (the baseline counterpart is a6_smooth_learn, KOZ gain).';
cfg.forecast.origin = qq(2026, 2);
cfg.forecast.horizon = 4;
cfg.compare_with = {'a6_smooth_learn'};
end
