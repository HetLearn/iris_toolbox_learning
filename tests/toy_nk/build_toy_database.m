function file = build_toy_database()
%BUILD_TOY_DATABASE  Simulated database for the toy NK model (engine tests).
%
%   file = build_toy_database()
%
%   Simulates the RE toy model (every br_<x> = false, i.e. the source model)
%   with unanticipated N(0, std) shocks (rng seed 20261017) over
%   1990Q1-2029Q4 from the steady state and writes obs_y, obs_pie, obs_r over
%   2000Q1-2029Q4 to data/nk3_database.csv (databank.toCSV). Needs IRIS and
%   the hetlearn toolbox on the path (setup_paths).

here = fileparts(mfilename('fullpath'));
spec = hetlearn.load_spec(here);
opts = hetlearn.load_options(struct('expectations', struct('variables', {{}})), struct());
m = hetlearn.load_model(spec, opts);
rng(20261017);
sim = qq(1990, 1):qq(2029, 4);
d = zerodb(m, sim(1) - 4:sim(end));
el = cellstr(get(m, 'eList'));
for i = 1:numel(el)
    d.(el{i})(sim) = m.(['std_' el{i}]) * randn(numel(sim), 1);
end
s = simulate(m, d, sim, 'anticipate', false, 'prependInput', true);
out = struct();
for o = spec.observables
    out.(o{1}) = s.(o{1});
end
if exist(fullfile(here, 'data'), 'dir') ~= 7
    mkdir(fullfile(here, 'data'));
end
file = fullfile(here, spec.database);
databank.toCSV(out, file, qq(2000, 1):qq(2029, 4), 'Format', '%.17g');
end
