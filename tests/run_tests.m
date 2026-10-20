function run_tests(only)
%RUN_TESTS  Run every hetlearn unit test and print one PASS/FAIL line per check.
%
%   run_tests()
%   run_tests(only)   only the suites named in the cellstr only (e.g. to
%                     split a long run: {'test_density', 'test_evaluate'})
%
%   test_density and test_evaluate (density forecasts, recursive forecast
%   evaluation; toy NK checks plus SW07 smoke tests) run after test_sw07,
%   then test_anchored (anchored RE variant, backward simulator) and
%   test_plm2 (VAR learning, derived regressors, AR(2); SW07 smoke runs).
%   test_br_regression (last) compares against references frozen before the
%   bounded-rationality extensions (tests/reference/br_freeze.mat): exact,
%   so run it at the default thread count.
%   Calls setup_paths, runs test_options, test_rls, test_switching,
%   test_plm, test_generator, test_engine (toy NK engine) and test_sw07
%   (SW07 package and template scenarios), prints a summary, and raises an error
%   (nonzero exit status under matlab -batch) if any check fails.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
addpath(root);
setup_paths();
addpath(here);
addpath(fullfile(here, 'scenarios'));     % test scenarios (tsw07_*) and reference helpers, independent of scenarios/
% tests/scenarios/master_options.m (the calibration of 2026-10-18/19 = the defaults) shadows the
% project's config/master_options.m, so the project baseline (changed 2026-10-20) does not reach
% the tests. A suite run on its own outside run_tests needs addpath('tests/scenarios') first; the
% SW07 suites add it themselves.
mo = which('master_options');
if ~startsWith(mo, fullfile(here, 'scenarios'))
    error('run_tests:master', 'master_options resolves to %s, not to tests/scenarios/master_options.m.', mo);
end

suites = {'test_options', 'test_rls', 'test_switching', 'test_plm', 'test_generator', ...
    'test_engine', 'test_sw07', 'test_density', 'test_evaluate', 'test_anchored', 'test_plm2', ...
    'test_inversion', 'test_decompose', 'test_ramsey', ...   % test_ramsey: Ramsey policy (DESIGN 13; toy + SW07 runs, about 80 s)
    'test_info', ...   % test_info: beliefs.info 'lagged' | 'current' (toy + SW07 runs, about 40 s)
    'test_gain', ...   % test_gain: endogenous gain gain.rule = 'koz' (DESIGN 18; unit, toy, SW07 runs)
    'test_facility', ...  % test_facility: projection facility (DESIGN 4.4; unit systems and toy, about 30 s)
    'test_re_states', ... % test_re_states: history.re_states 'smoothed' | 'filtered' (DESIGN 5.2; toy + SW07 runs, about 2 min)
    'test_re_info', ...   % test_re_info: expectations.re_info (DESIGN 19; about 8 min, or one part: see below)
    'test_br_regression'}; % test_br_regression: frozen regression gate of the bounded-rationality extensions
% test_re_info: 'current' | 'lagged'; test_re_info('toy' | 'sw07_model' | 'sw07_runs' | 'sw07_stages') runs one
%   part at a time. test_br_regression (docs/DESIGN_br_extensions.md 1.7): R1 generated files, R2 30 runs exact,
%   about 2 min; references tests/reference/br_freeze.mat, made by tests/scenarios/make_br_freeze.m.
if nargin >= 1 && ~isempty(only)
    suites = suites(ismember(suites, cellstr(only)));
end
results = struct('name', {}, 'pass', {}, 'msg', {});
for i = 1:numel(suites)
    t = tic;
    try
        r = feval(suites{i});
    catch err
        r = struct('name', [suites{i} ': suite crashed'], 'pass', false, ...
            'msg', getReport(err, 'basic'));
    end
    results = [results, r]; %#ok<AGROW>
    fprintf('-- %s: %d checks, %.1f s\n', suites{i}, numel(r), toc(t));
end

fprintf('\n');
for i = 1:numel(results)
    tag = 'PASS';
    if ~results(i).pass
        tag = 'FAIL';
    end
    msg = results(i).msg;
    if ~isempty(msg)
        msg = ['  [' strrep(msg, newline, ' ') ']'];
    end
    fprintf('%s  %s%s\n', tag, results(i).name, msg);
end
nFail = sum(~[results.pass]);
fprintf('\nSummary: %d checks, %d passed, %d failed\n', numel(results), ...
    numel(results) - nFail, nFail);
if nFail > 0
    error('run_tests:failed', '%d check(s) failed.', nFail);
end
end
