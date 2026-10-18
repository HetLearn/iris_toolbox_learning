function [R, row] = sw07_smoke_run(cfg, label, outDir)
%SW07_SMOKE_RUN  One SW07 smoke run for test_anchored / test_plm2 (no economic asserts).
%
%   [R, row] = sw07_smoke_run(cfg, label, outDir)
%
%   Runs hetlearn.run(cfg) into outDir (tests/output/results/), then checks
%   that the run completed (the engine's timing assert, x_exp1_BR = PLM
%   forecast with phi_{t-1}, fires as an error otherwise) and that every
%   discrete-choice share n2 and model share n1_model is in [0, 1] over
%   the record. Prints one summary line: runtime, events by type, average
%   annualised inflation 2022Q3-2026Q2 (4*pinfobs) and the quarters with
%   an IRIS solution (no 'explosive' event); ALM reverts = 'projection_alm' events.
%   A stop of the projection facility (hetlearn:engine:almUnstable or
%   :noSolution, DESIGN 4.4) is the documented outcome of the options, so the
%   check passes and reports the message (row.status, row.message).
%
%   Outputs
%     R    one check (name, pass, msg)
%     row  struct: id, label, runtime_s, n_events, events (char), quarters,
%          n_explosive, n_alm_revert, avg_infl, infl (16 x 1), max_root, status
%          ('ok' or the error identifier), message

hz = qq(2022, 3):qq(2026, 2);
name = ['sw07 smoke: ' label];
row = struct('id', cfg.id, 'label', label, 'runtime_s', NaN, 'n_events', NaN, 'events', '', ...
    'quarters', numel(hz), 'n_explosive', NaN, 'n_alm_revert', NaN, 'avg_infl', NaN, ...
    'infl', NaN(numel(hz), 1), 'max_root', NaN, 'status', 'ok', 'message', '');
try
    t0 = tic;
    res = hetlearn.run(cfg, 'results_dir', outDir, 'quiet', true);
    row.runtime_s = toc(t0);
    ev = res.events;
    types = {};
    if ~isempty(ev) && height(ev) > 0
        types = ev.type;
    end
    [u, ~, j] = unique(types);
    cnt = accumarray(j(:), 1, [numel(u), 1]);
    row.events = strjoin(cellfun(@(a, b) sprintf('%s %d', a, b), u(:)', num2cell(cnt(:)'), ...
        'UniformOutput', false), ', ');
    row.n_events = numel(types);
    row.n_explosive = sum(strcmp(types, 'explosive'));
    row.n_alm_revert = sum(strcmp(types, 'projection_alm') | strcmp(types, 'projection_alm_shares'));   % ALM steps (DESIGN 4.4)
    if row.n_explosive > 0
        det = ev.detail(strcmp(types, 'explosive'));
        r = cellfun(@(s) str2double(regexp(s, 'largest abs root ([\d.eE+-]+)', 'tokens', 'once')), det);
        row.max_root = max(r);
    end
    row.infl = 4 * res.paths.pinfobs(hz);
    row.avg_infl = mean(row.infl);
    lv = res.meta.learnVars;
    if ischar(lv)
        lv = {lv};
    end
    rd = res.dates.record;
    ok = true;
    for i = 1:numel(lv)
        L = res.learning.(lv{i});
        a = [L.n2(rd); L.n1_model(hz)];
        ok = ok && all(isfinite(a)) && all(a >= 0 & a <= 1);
    end
    R = struct('name', name, 'pass', ok, 'msg', sprintf( ...
        '%.1f s; events: %s; IRIS solves %d/%d quarters; avg infl %.2f%%', row.runtime_s, ...
        empty_as(row.events, 'none'), numel(hz) - row.n_explosive, numel(hz), row.avg_infl));
    fprintf('SMOKE | %-38s | %6.1f s | IRIS solves %2d/%d | explosive %2d | ALM reverts %3d | max root %8.4g | avg infl %8.2f | events: %s\n', ...
        label, row.runtime_s, numel(hz) - row.n_explosive, numel(hz), row.n_explosive, ...
        row.n_alm_revert, row.max_root, row.avg_infl, empty_as(row.events, 'none'));
    fprintf('SMOKE-PATH | %s | %s\n', label, strjoin(arrayfun(@(v) sprintf('%.2f', v), row.infl', ...
        'UniformOutput', false), ' '));
catch err
    row.runtime_s = toc(t0);
    if any(strcmp(err.identifier, {'hetlearn:engine:almUnstable', 'hetlearn:engine:noSolution'}))
        % a documented stop of the projection facility (DESIGN 4.4): the run did what the
        % options specify; reported, not a failure of the toolbox
        row.status = err.identifier;
        row.message = err.message;
        R = struct('name', name, 'pass', true, 'msg', sprintf('stopped by the projection facility after %.1f s (%s): %s', ...
            row.runtime_s, err.identifier, err.message(1:min(end, 400))));
        fprintf('SMOKE | %-38s | %6.1f s | STOPPED %s | %s\n', label, row.runtime_s, err.identifier, ...
            err.message(1:min(end, 300)));
    else
        R = struct('name', name, 'pass', false, 'msg', getReport(err, 'basic'));
    end
end
end


function s = empty_as(s, d)
if isempty(s)
    s = d;
end
end
