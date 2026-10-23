function cfg = tsw07_a1_learn()
%TSW07_A1_LEARN  Test scenario: the frozen project baseline a1_learn with every baseline setting written out.
%
%   cfg = tsw07_a1_learn()
%
%   As tsw07_a1_re, with inflation expectations a switching mix of anchored RE(t-1) agents and
%   AR(1) learners on data up to t-1 (KOZ gain from 0.05, chi 2, memory 0.8): the test copy of
%   scenarios/sw07/app1_peak/a1_learn.m under the frozen baseline (tsw07_a1_re).
%   compare_with is empty (a1_learn compares with a1_re; the tests do not save).

cfg = tsw07_a1_re();
cfg.id = 'tsw07_a1_learn';
cfg.title = 'Test: baseline a1_learn (frozen), forecast from the 2022Q2 peak, learning on inflation';
cfg.expectations.mode = 'switching';
cfg.compare_with = {};
end
