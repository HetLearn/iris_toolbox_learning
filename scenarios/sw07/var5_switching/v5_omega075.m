function cfg = v5_omega075()
%V5_OMEGA075  Model variant 5: memory 0.75, forecast from the 2022Q2 peak.
%
%   cfg = v5_omega075()
%
%   As a1_learn, with the memory of the fitness measure omega at 0.75 instead of
%   0.8; every other setting is the project baseline. Writes
%   compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v5_omega075';
cfg.title = 'Variant 5: learning on inflation, memory 0.75';
cfg.description = 'As a1_learn, with the memory of the fitness measure omega at 0.75 instead of 0.8.';
cfg.switching.memory = 0.75;
cfg.compare_with = {'a1_learn'};
end
