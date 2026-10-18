function cfg = a1_learn()
%A1_LEARN  Application 1: forecast from the 2022Q2 inflation peak, learning on inflation.
%
%   cfg = a1_learn()
%
%   As a1_re, with the baseline learning model of sw07_learn (switching RE /
%   AR(1) learners on inflation). The parent of every learning scenario of the
%   applications and model variants. Writes compare_a1_re.csv.

cfg = sw07_learn();
cfg.id = 'a1_learn';
cfg.title = 'App 1: forecast from the 2022Q2 peak, learning on inflation';
cfg.description = 'Unconditional forecast from the 2022Q2 inflation peak with inflation expectations a switching mix of RE agents and AR(1) learners.';
cfg.compare_with = {'a1_re'};
end
