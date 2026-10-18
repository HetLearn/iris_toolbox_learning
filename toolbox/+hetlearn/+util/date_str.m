function c = date_str(d)
%DATE_STR  IRIS dates as a cellstr of text such as '2022Q3'.
%
%   c = hetlearn.util.date_str(d)

if isempty(d)
    c = {};
    return
end
c = cellstr(dat2str(d));
c = reshape(c, 1, []);
end
