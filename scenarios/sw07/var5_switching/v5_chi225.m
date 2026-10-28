function cfg = v5_chi225()
%V5_CHI225  Model variant 5: intensity of choice 2.25, forecast from the 2022Q2 peak.
%
%   cfg = v5_chi225()
%
%   As a1_learn, with the intensity of choice chi at 2.25 instead of 2; every other
%   setting is the project baseline. Writes compare_a1_learn.csv.

cfg = a1_learn();
cfg.id = 'v5_chi225';
cfg.title = 'Variant 5: learning on inflation, intensity of choice 2.25';
cfg.description = 'As a1_learn, with the intensity of choice chi at 2.25 instead of 2.';
cfg.switching.intensity = 2.25;
cfg.compare_with = {'a1_learn'};
end
