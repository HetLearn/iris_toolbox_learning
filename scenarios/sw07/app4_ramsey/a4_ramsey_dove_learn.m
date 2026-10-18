function cfg = a4_ramsey_dove_learn()
%A4_RAMSEY_DOVE_LEARN  Application 4: Ramsey policy (commitment), dovish weights, learning on inflation.
%
%   cfg = a4_ramsey_dove_learn()
%
%   As a4_rule_learn with the policy block of a4_ramsey_dove_re (taken from
%   that file, so the two stay identical). With learning the planner
%   re-optimises each quarter given the current beliefs and shares. Caveat:
%   the anchored RE agents forecast with the RE solution under the Taylor
%   rule, not under the Ramsey policy (an open design question).
%   Writes compare_a4_rule_learn.csv.

cfg = a4_rule_learn();
r = a4_ramsey_dove_re();
cfg.id = 'a4_ramsey_dove_learn';
cfg.title = 'App 4: Ramsey policy, dovish weights, learning on inflation';
cfg.description = 'Ramsey policy under commitment from the 2022Q2 peak with loss weights inflation 1, output gap 1, rate 0.1, with inflation expectations a switching mix of RE agents and learners.';
cfg.policy = r.policy;
cfg.compare_with = {'a4_rule_learn'};
end
