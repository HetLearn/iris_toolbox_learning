function cfg = a3_loose_learn()
%A3_LOOSE_LEARN  Application 3: policy 100 bp a year looser than the Taylor rule in 2022Q3-2023Q2, learning.
%
%   cfg = a3_loose_learn()
%
%   As a1_learn with the condition of a3_loose_re (taken from that file, so
%   the two stay identical). Writes compare_a1_learn.csv.

cfg = a1_learn();
c = a3_loose_re();
cfg.id = 'a3_loose_learn';
cfg.title = 'App 3: policy 100 bp looser than the Taylor rule in 2022Q3-2023Q2, learning on inflation';
cfg.description = 'From the 2022Q2 peak, the rate is held 100 bp a year below the Taylor rule for four quarters, with inflation expectations a switching mix of RE agents and learners.';
cfg.conditions = c.conditions;
cfg.compare_with = {'a1_learn'};
end
