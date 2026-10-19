function cfg = v4_koz_full()
%V4_KOZ_FULL  Model variant 4: endogenous gain over the RE-smoothed history 1966Q1-2026Q2.
%
%   cfg = v4_koz_full()
%
%   As v4_koz with origin 2026Q2 and horizon 4: the gain, beliefs and shares
%   over the whole history to 2026Q2. The constant-gain counterpart is
%   a6_smooth_learn; writes compare_a6_smooth_learn.csv.

cfg = v4_koz();
cfg.id = 'v4_koz_full';
cfg.title = 'Variant 4: endogenous gain on the RE-smoothed history 1966Q1-2026Q2';
cfg.description = 'The learning-on-inflation model with the KOZ endogenous gain run over the RE-smoothed history to 2026Q2.';
cfg.forecast.origin = qq(2026, 2);
cfg.forecast.horizon = 4;
% cfg.gain.koz.error_scale = 1 is inherited from v4_koz (quarterly units, user decision 2026-10-19).
cfg.compare_with = {'a6_smooth_learn'};
end
