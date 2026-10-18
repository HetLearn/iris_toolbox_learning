function cfg = tsw07_switch_pinf()
%TSW07_SWITCH_PINF  Test scenario: as tsw07_peak_re, switching between RE and AR(1) learners on inflation.

cfg = tsw07_peak_re();
cfg.id = 'tsw07_switch_pinf';
cfg.title = 'Test: peak-inflation forecast from 2022Q2, switching on inflation';
cfg.expectations.mode = 'switching';
cfg.expectations.variables = {'pinf'};
cfg.compare_with = {'tsw07_peak_re'};
end
