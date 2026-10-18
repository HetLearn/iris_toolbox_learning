function t = find_peak(db, name, from, to)
%FIND_PEAK  Date of the maximum of a series over a window (helper for origins).
%
%   t = hetlearn.find_peak(db, name, from, to)
%
%   Inputs
%     db    databank (struct of IRIS Series)
%     name  series name, e.g. 'pinfobs'
%     from  first date of the window
%     to    last date of the window
%
%   Output
%     t     the date of the largest value (the first one if tied); NaN
%           values are ignored

if ~isfield(db, name)
    error('hetlearn:find_peak:noSeries', 'Databank has no series %s.', name);
end
dates = from:to;
v = db.(name)(dates);
v = v(:, 1);
if all(isnan(v))
    error('hetlearn:find_peak:noData', 'Series %s has no data between %s and %s.', ...
        name, char(dat2str(from)), char(dat2str(to)));
end
[~, k] = max(v);
t = dates(k);
end
