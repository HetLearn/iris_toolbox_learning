function make_reference()
%MAKE_REFERENCE  Store the test reference for the 2026-10-18 defaults in tests/reference/.
%
%   tests/reference/tsw07_switch_pinf_iris.mat: tsw07_switch_pinf (anchored
%   RE, projection.facility = 'plm_alm', constant gain) run with
%   engine.step = 'iris'; variable ref with fields paths, learning, events,
%   cfg, dates, made (timestamp). Compared by test_gain G14, test_info I5 and
%   test_inversion S3b (iris exactly, fast within 1e-10). Re-run only after a
%   deliberate change of the engine or the defaults, and say so in
%   README_PIPELINE.md.

here = fileparts(mfilename('fullpath'));
tests = fileparts(here);
outDir = fullfile(tests, 'output', 'results');
cfg = tsw07_switch_pinf();
cfg.engine.step = 'iris';
cfg.compare_with = {};
res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true, 'save', false);
ref = struct('paths', res.paths, 'learning', res.learning, 'events', res.events, 'cfg', res.cfg, ...
    'dates', res.dates, 'made', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
save(fullfile(tests, 'reference', 'tsw07_switch_pinf_iris.mat'), 'ref');
fprintf('reference saved: %d events, n2_pinf at the origin %.6f\n', height(res.events), ...
    res.learning.pinf.n2(res.dates.origin));
end
