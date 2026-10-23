function [E, info] = draws(F, H)
%DRAWS  Shock draws for a density forecast (DESIGN 14).
%
%   [E, info] = hetlearn.density.draws(F, H)
%
%   Inputs
%     F  forecast-stage bundle (hetlearn.engine.core): F.ctx.opts.density,
%        F.ctx.horizon, F.ctx.eList, F.m (for the model's std_<shock>)
%     H  RE filter output (H.smooth shocks, H.range)
%
%   Outputs
%     E     nT x nS x N array: draw j adds E(:, s, j) to shock info.shocks{s}
%           at info.dates
%     info  .shocks (1 x nS), .dates (1 x nT: density.range within the
%           horizon, default the horizon), .method, .sigma_source
%           ('calibrated' | 'smoothed' | 'bootstrap pool'), .sigma (1 x nS:
%           the std used by 'normal', or the pool std for 'bootstrap'),
%           .sigma_range (dates), .sample_mean (1 x nS, mean of the
%           RE-smoothed shocks over sigma_range), .seed
%           bootstrap only: .pool (nP x nS), .pool_dates, .index (nT x N,
%           pool row drawn for each draw date)
%
%   'normal': E(:, s, j) = sigma_s * z, z iid N(0, 1); sigma_s = the model's
%   std_<shock> ('calibrated') or the sample std (N - 1) of the RE-smoothed
%   shock over density.sigma_range ('smoothed'; default the filter range).
%   'bootstrap': every draw date takes the whole vector of the RE-smoothed
%   shocks of ONE date of sigma_range, drawn uniformly with replacement
%   (jointly across shocks; dates with a missing value are dropped from the
%   pool); with density.demean = true (default) the pool is demeaned
%   first (pool mean over those dates, info.pool_mean), so the draws are
%   centred on the scenario's own shocks; demean = false keeps the smoothed
%   values; never rescaled; density.sigma is not used. Random numbers come from RandStream('mt19937ar', 'Seed',
%   density.seed), drawn draw by draw, so the first k draws do not depend on
%   density.ndraws; the global random stream is not touched.

ctx = F.ctx;
o = ctx.opts.density;
hz = ctx.horizon;
names = reshape(cellstr(o.shocks), 1, []);
if isempty(names)
    error('hetlearn:density:shocks', 'density.shocks must name at least one shock.');
end
bad = setdiff(names, ctx.eList);
if ~isempty(bad)
    error('hetlearn:density:shocks', 'density.shocks names unknown shock(s): %s.', strjoin(bad, ', '));
end
dates = hz;
if ~isempty(o.range)
    r0 = hetlearn.util.to_dates(o.range);
    inHz = arrayfun(@(t) any(hetlearn.util.date_eq(hz, t)), r0);
    dates = r0(inHz);
end
if isempty(dates)
    error('hetlearn:density:range', 'density.range has no date inside the forecast horizon.');
end
sr = H.range;
if ~isempty(o.sigma_range)
    sr = hetlearn.util.to_dates(o.sigma_range);
end
nT = numel(dates);
nS = numel(names);
N = double(o.ndraws);
Psm = NaN(numel(sr), nS);
for s = 1:nS
    Psm(:, s) = reshape(H.smooth.(names{s})(sr), [], 1);
end

info = struct();
info.shocks = names;
info.dates = dates;
info.method = o.method;
info.sigma_range = sr;
info.sample_mean = mean(Psm, 1, 'omitnan');
info.seed = o.seed;
rs = RandStream('mt19937ar', 'Seed', double(o.seed));
E = zeros(nT, nS, N);
switch o.method
    case 'normal'
        sigma = zeros(1, nS);
        switch o.sigma
            case 'calibrated'
                sd = get(F.m, 'std');
                for s = 1:nS
                    sigma(s) = double(sd.(['std_' names{s}]));
                end
            case 'smoothed'
                for s = 1:nS
                    v = Psm(isfinite(Psm(:, s)), s);
                    if numel(v) < 2
                        error('hetlearn:density:sigma', ...
                            'Shock %s has fewer than 2 smoothed values in density.sigma_range.', names{s});
                    end
                    sigma(s) = std(v);
                end
        end
        for j = 1:N
            E(:, :, j) = randn(rs, nT, nS) .* sigma;
        end
        info.sigma_source = o.sigma;
    case 'bootstrap'
        ok = all(isfinite(Psm), 2);
        pool = Psm(ok, :);
        if size(pool, 1) < 2
            error('hetlearn:density:bootstrap', ...
                'Fewer than 2 dates with all drawn shocks smoothed in density.sigma_range.');
        end
        info.pool_mean = mean(pool, 1);
        info.demean = ~isfield(o, 'demean') || logical(o.demean);
        if info.demean
            pool = pool - info.pool_mean;   % centered on the scenario's own shocks
        end
        idx = zeros(nT, N);
        for j = 1:N
            idx(:, j) = randi(rs, size(pool, 1), nT, 1);
            E(:, :, j) = pool(idx(:, j), :);
        end
        sigma = std(pool, 0, 1);
        info.sigma_source = 'bootstrap pool';
        info.pool = pool;
        info.pool_dates = sr(ok);
        info.index = idx;
end
info.sigma = sigma;
end
