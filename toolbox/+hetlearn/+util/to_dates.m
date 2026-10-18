function d = to_dates(x)
%TO_DATES  Normalise a date input to a row vector of IRIS dates.
%
%   d = hetlearn.util.to_dates(x)
%
%   Inputs
%     x   IRIS date(s): a single date, a date vector, or a two-element
%         [start, end] pair, which is expanded to start:end. A pair of
%         consecutive dates gives the same two dates either way.
%
%   Output
%     d   row vector of dates (class as returned by IRIS date arithmetic)

if isempty(x)
    d = x;
    return
end
x = reshape(x, 1, []);
if numel(x) == 2
    d = x(1):x(2);
else
    d = x;
end
end
