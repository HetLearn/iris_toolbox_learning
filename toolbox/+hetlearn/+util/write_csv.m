function write_csv(file, header, dates, X)
%WRITE_CSV  Write a CSV with a text date column and numeric columns.
%
%   hetlearn.util.write_csv(file, header, dates, X)
%
%   Inputs
%     file    output path
%     header  cellstr of column names, first one the date column name
%     dates   cellstr of date texts (one per row), e.g. {'2022Q3', ...}
%     X       numeric matrix, numel(dates) x (numel(header) - 1); written
%             with %.17g, NaN as empty

fid = fopen(file, 'w');
if fid < 0
    error('hetlearn:util:write', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', strjoin(header, ','));
for i = 1:numel(dates)
    v = X(i, :);
    s = arrayfun(@num, v, 'UniformOutput', false);
    fprintf(fid, '%s,%s\n', dates{i}, strjoin(s, ','));
end
end

function s = num(v)
if isnan(v)
    s = '';
else
    s = sprintf('%.17g', v);
end
end
