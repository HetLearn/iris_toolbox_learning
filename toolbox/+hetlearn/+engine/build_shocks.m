function d = build_shocks(ctx, H)
%BUILD_SHOCKS  Starting databank: RE-smoothed history to the origin plus scenario shocks (DESIGN 5.4).
%
%   d = hetlearn.engine.build_shocks(ctx, H)
%
%   Inputs
%     ctx  engine context (.opts, .origin, .horizon, .xList, .yList, .eList)
%     H    RE filter output (hetlearn.re_filter)
%
%   Output
%     d    databank with every transition and measurement variable and
%          shock of the scenario model: H.smooth clipped to the origin, and
%          shocks over the horizon set by opts.shocks:
%            source 'none'      zeros
%            source 'smoothed'  H.smooth shocks over shocks.range (default
%                               the horizon; dates outside the horizon are
%                               ignored), shocks.exclude zeroed, NaN -> 0
%            add {{name, dates, values}, ...}  added on top (values scalar
%                               or one per date; dates a vector or [start, end])

o = ctx.opts.shocks;
hz = ctx.horizon;
origin = ctx.origin;
d = struct();
names = [ctx.xList(:); ctx.yList(:); ctx.eList(:)]';
for i = 1:numel(names)
    n = names{i};
    if ~isfield(H.smooth, n)
        error('hetlearn:engine:history', 'The RE-smoothed history has no series %s.', n);
    end
    x = H.smooth.(n);
    d.(n) = clip(x, x.Start, origin);
end
eList = ctx.eList;
for i = 1:numel(eList)
    d.(eList{i})(hz) = 0;
end
bad = setdiff(o.exclude, eList);
if ~isempty(bad)
    error('hetlearn:engine:shocks', 'shocks.exclude names unknown shock(s): %s.', strjoin(bad, ', '));
end
if strcmp(o.source, 'smoothed')
    rng = hz;
    if ~isempty(o.range)
        rng = hetlearn.util.to_dates(o.range);
    end
    inHz = arrayfun(@(t) any(hetlearn.util.date_eq(hz, t)), rng);
    rng = rng(inHz);
    for i = 1:numel(eList)
        e = eList{i};
        if any(strcmp(o.exclude, e)) || isempty(rng)
            continue
        end
        v = H.smooth.(e)(rng);
        v(~isfinite(v)) = 0;
        d.(e)(rng) = v;
    end
end
for i = 1:numel(o.add)
    a = o.add{i};
    if ~iscell(a) || numel(a) ~= 3
        error('hetlearn:engine:shocks', 'shocks.add{%d} must be {name, dates, values}.', i);
    end
    [n, dt, v] = a{:};
    n = char(n);
    if ~any(strcmp(eList, n))
        error('hetlearn:engine:shocks', 'shocks.add{%d}: %s is not a shock of the model.', i, n);
    end
    dt = hetlearn.util.to_dates(dt);
    v = v(:);
    if isscalar(v)
        v = repmat(v, numel(dt), 1);
    end
    if numel(v) ~= numel(dt)
        error('hetlearn:engine:shocks', 'shocks.add{%d}: %d values for %d dates.', i, numel(v), numel(dt));
    end
    cur = d.(n)(dt);
    cur(~isfinite(cur)) = 0;
    d.(n)(dt) = cur(:) + v;
end
end
