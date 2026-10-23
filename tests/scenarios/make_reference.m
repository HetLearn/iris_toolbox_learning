function make_reference()
%MAKE_REFERENCE  Store the test references for the current defaults in tests/reference/.
%
%   tests/reference/tsw07_switch_pinf_iris.mat: tsw07_switch_pinf (anchored
%   RE, projection.facility = 'plm_alm', constant gain) run with
%   engine.step = 'iris'; variable ref with fields paths, learning, events,
%   cfg, dates, made (timestamp). Compared by test_gain G14, test_info I5 and
%   test_inversion S3b (iris exactly, fast within 1e-10).
%   tests/reference/tsw07_switch_pinf_fast.mat: the same scenario with the
%   default engine.step = 'fast'; compared exactly by test_re_states S1 (first
%   made with the code before history.re_states existed).
%   Re-run only after a deliberate change of the engine or the defaults.

here = fileparts(mfilename('fullpath'));
tests = fileparts(here);
outDir = fullfile(tests, 'output', 'results');
steps = {'iris', 'tsw07_switch_pinf_iris.mat'; 'fast', 'tsw07_switch_pinf_fast.mat'};
for i = 1:size(steps, 1)
    cfg = tsw07_switch_pinf();
    cfg.engine.step = steps{i, 1};
    cfg.compare_with = {};
    res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false);
    ref = struct('paths', res.paths, 'learning', res.learning, 'events', res.events, 'cfg', res.cfg, ...
        'dates', res.dates, 'made', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    save(fullfile(tests, 'reference', steps{i, 2}), 'ref');
    fprintf('reference %s saved: %d events, n2_pinf at the origin %.6f\n', steps{i, 2}, height(res.events), ...
        res.learning.pinf.n2(res.dates.origin));
end
end
