function o = master_options()
%MASTER_OPTIONS  Test copy of config/master_options.m: the calibration of 2026-10-18/19 (= hetlearn.defaults).
%
%   o = master_options()
%
%   The test suites run against this file, not the project's config/master_options.m, so that a
%   change of the project baseline does not move the test references. tests/run_tests.m and every
%   SW07 suite add tests/scenarios/ to the front of the path, so hetlearn.load_options finds this
%   file first (run_tests asserts it). Added on 2026-10-20, when the project baseline moved to the
%   published SW07 parameters, the KOZ gain from 0.05, chi 2, memory 0.8, t-1 RE information,
%   filtered RE states and no projection facility (config/master_options.m).
%
%   The values are those config/master_options.m set until 2026-10-19; they equal
%   hetlearn.defaults(), so the tests run on the defaults as before.

o = struct();
o.gain.value = 0.0585;            % constant gain (IJCB Table 1, HE posterior mean)
o.switching.intensity = 0.51;     % chi (IJCB estimate, quarterly data)
o.switching.memory = 0.6;         % omega (IJCB sec. 4)
o.shares.init_n2 = 0.5;           % initial share of BR (learning) agents
end
