function [d, file] = load_database(spec)
%LOAD_DATABASE  Read the model package database (DESIGN 2).
%
%   [d, file] = hetlearn.load_database(spec)
%
%   Inputs
%     spec  model spec (hetlearn.load_spec); spec.database is a CSV written
%           by databank.toCSV or a .mat file, relative to spec.folder (or
%           absolute).
%
%   Outputs
%     d     databank (struct of IRIS Series)
%     file  absolute path of the file read
%
%   A .mat file must hold either one struct variable (the databank) or the
%   databank fields as separate variables.

if ~isfield(spec, 'database') || isempty(spec.database)
    error('hetlearn:load_database:none', 'Model %s has no spec.database.', spec.name);
end
file = spec.database;
if exist(file, 'file') ~= 2 || isempty(fileparts(file))
    file = fullfile(spec.folder, spec.database);
end
if exist(file, 'file') ~= 2
    error('hetlearn:load_database:noFile', 'Database file not found: %s', file);
end
[~, ~, ext] = fileparts(file);
switch lower(ext)
    case '.csv'
        d = databank.fromCSV(file);
    case '.mat'
        L = load(file);
        f = fieldnames(L);
        if numel(f) == 1 && isstruct(L.(f{1}))
            d = L.(f{1});
        else
            d = L;
        end
    otherwise
        error('hetlearn:load_database:type', 'Database must be .csv or .mat: %s', file);
end
end
