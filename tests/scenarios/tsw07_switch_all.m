function cfg = tsw07_switch_all()
%TSW07_SWITCH_ALL  Test scenario: as tsw07_switch_pinf, switching on all 12 forward-looking variables (per-variable shares).

cfg = tsw07_switch_pinf();
cfg.id = 'tsw07_switch_all';
cfg.title = 'Test: forecast from the 2022Q2 peak, switching on all forward-looking variables';
cfg.expectations.variables = 'all';
cfg.shares.structure = 'per_variable';
cfg.compare_with = {};
end
