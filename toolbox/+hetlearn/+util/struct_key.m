function s = struct_key(a)
%STRUCT_KEY  Canonical text of a (nested) struct, for hashing.
%
%   s = hetlearn.util.struct_key(a)
%
%   Fields are sorted by name; numbers are written with %.17g, logicals as
%   0/1, chars as is, nested structs recursively, anything else by class.

if isempty(a) || ~isstruct(a)
    s = '';
    return
end
f = sort(fieldnames(a));
parts = cell(1, numel(f));
for i = 1:numel(f)
    v = a.(f{i});
    if isstruct(v) && isscalar(v)
        v = ['{' hetlearn.util.struct_key(v) '}'];
    elseif isnumeric(v) || islogical(v)
        v = sprintf('%.17g,', double(v));
    elseif ischar(v) || isstring(v)
        v = char(strjoin(string(v), ','));
    elseif iscellstr(v)
        v = strjoin(v, ',');
    else
        v = class(v);
    end
    parts{i} = [f{i} '=' v];
end
s = strjoin(parts, ';');
end
