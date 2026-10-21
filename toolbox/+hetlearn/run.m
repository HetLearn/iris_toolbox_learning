function res = run(cfg, varargin)
%RUN  Full scenario run: options, model, RE filter, history, forecast, save (DESIGN 5, 9, 14).
%
%   res = hetlearn.run(cfg)
%   res = hetlearn.run(cfg, 'save', false, 'results_dir', folder, 'quiet', true)
%
%   Inputs
%     cfg   scenario options (partial option tree, e.g. from a scenario
%           file); merged as hetlearn.defaults < config/master_options.m <
%           cfg by hetlearn.load_options. Needs cfg.id, cfg.model (model
%           folder name under models/, or a folder path) and
%           cfg.forecast.origin.
%   Options
%     'save'         write results_dir/<id>/ (default true)
%     'results_dir'  parent folder of the results (default <root>/results)
%     'quiet'        suppress the progress lines (default false)
%     'model'        struct('spec', spec, 'm', m, 'info', info) from an
%                    earlier hetlearn.load_spec/hetlearn.load_model call with
%                    the SAME options (skips loading; hetlearn.evaluate)
%     'filter'       RE filter output H to use instead of calling
%                    hetlearn.re_filter (hetlearn.evaluate shares one per
%                    origin across variants)
%
%   Output res (also saved as results/<id>/results.mat)
%     .cfg       merged options
%     .paths     databank [filter start, origin+H]: RE-smoothed history, then
%                the scenario (all transition/measurement variables, shocks)
%     .learning  beliefs, R diagonal, gains, shares, fitness, forecast errors
%                and forecasts by PLM target (Series)
%     .events    table of events (projection facility, explosive periods), with stage
%     .state     final learning state; .dates origin/horizon/record dates
%     .meta      started, finished, runtime_s, IRIS version, model hash,
%                RE filter hash, fit and end date, learning variables,
%                collapse test
%     .loss      discounted policy loss over policy.loss_horizon with the
%                policy.loss weights, rule and Ramsey runs alike
%                (hetlearn.policy.loss; [] without spec.policy); loss.csv
%     .density   only with density.enabled: hetlearn.density.run output
%                (saved as density.mat, not inside results.mat)
%
%   Steps: hetlearn.load_options -> hetlearn.load_spec -> hetlearn.load_model
%   -> hetlearn.re_filter (history.realtime = true: data clipped at the
%   origin, 'end' option) -> hetlearn.engine.core (history and forecast
%   stages) -> hetlearn.density.run (density.enabled) ->
%   hetlearn.engine.save_results.
%
%   See also hetlearn.run_files, hetlearn.compare, hetlearn.evaluate.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
ip = inputParser;
ip.addParameter('save', true);
ip.addParameter('results_dir', fullfile(root, 'results'));
ip.addParameter('quiet', false);
ip.addParameter('model', []);
ip.addParameter('filter', []);
ip.parse(varargin{:});
quiet = logical(ip.Results.quiet);

tAll = tic;
started = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
opts = hetlearn.load_options(cfg);
if isempty(opts.id)
    error('hetlearn:run:id', 'cfg.id must be set.');
end
if isempty(opts.model)
    error('hetlearn:run:model', 'cfg.model must be set.');
end
if isempty(ip.Results.model)
    spec = hetlearn.load_spec(opts.model);
    [m, info] = hetlearn.load_model(spec, opts);
else
    spec = ip.Results.model.spec;
    m = ip.Results.model.m;
    info = ip.Results.model.info;
end
if ~quiet
    lv = strjoin(info.learnVars, ', ');
    if isempty(lv)
        lv = 'none';
    end
    fprintf('[hetlearn] %s: model %s, mode %s, learning variables: %s\n', ...
        opts.id, spec.name, opts.expectations.mode, lv);
end
if ~isempty(ip.Results.filter)
    H = ip.Results.filter;
elseif logical(opts.history.realtime) && strcmp(opts.history.mode, 're_smoother')
    if isempty(opts.forecast.origin)
        error('hetlearn:engine:origin', 'forecast.origin must be set.');
    end
    H = hetlearn.re_filter(spec, opts, 'end', opts.forecast.origin(1));
else
    % Hook for history.mode = 'inversion' (DESIGN 15, 17): the backed-out
    % history is real time by construction, so history.realtime does not
    % truncate anything there; the full-sample RE filter only supplies the
    % state before the inversion start.
    H = hetlearn.re_filter(spec, opts);
end
if ~quiet
    src = 'filtered';
    if H.cached
        src = 'cached';
    end
    if isfield(H, 'realtime') && H.realtime
        src = [src ', real time'];
    end
    fprintf('  RE filter %s-%s (%s): fit error %.2g\n', char(dat2str(H.range(1))), ...
        char(dat2str(H.range(end))), src, H.fit_error);
end
H = hetlearn.policy.prepare(H, info, opts);    % Ramsey: zero multipliers in the history (DESIGN 13)
ctx = struct('opts', opts, 'spec', spec, 'info', info, ...
    'results_dir', ip.Results.results_dir, 'quiet', quiet);
[res, F] = hetlearn.engine.core(ctx, m, H);
res.loss = hetlearn.policy.loss(res, F, opts, info);    % discounted policy loss (DESIGN 13)
if ~quiet && ~isempty(res.loss)
    fprintf('  policy %s: loss %.6g over %d quarters (discount %.6g)\n', opts.policy.mode, ...
        res.loss.total, res.loss.horizon, res.loss.discount);
end
if logical(opts.density.enabled)
    D = hetlearn.density.run(F, res, H);
    res.density = D;
    if ~quiet
        fprintf(['  density: %d draws (%s path), %d used, %d explosive, %d failed, ' ...
            '%.1f s (%.3f s per draw)\n'], D.ndraws, D.path, D.n_used, D.n_explosive, ...
            D.n_error, D.runtime_s, D.s_per_draw);
    end
end
res.meta.started = started;
res.meta.finished = datestr(now, 'yyyy-mm-dd HH:MM:SS'); %#ok<TNOW1,DATST>
res.meta.runtime_s = toc(tAll);
if logical(ip.Results.save)
    out = hetlearn.engine.save_results(res, spec, ip.Results.results_dir);
    hetlearn.policy.write_loss(res.loss, out);          % loss.csv (DESIGN 13)
    hetlearn.engine.kalman_history('write', res, out);  % kalman_errors.csv (history.mode 'kalman'; else a stale one is deleted)
    res.meta.runtime_s = toc(tAll);
    if ~quiet
        fprintf('  saved %s (%.1f s)\n', out, res.meta.runtime_s);
    end
end
end
