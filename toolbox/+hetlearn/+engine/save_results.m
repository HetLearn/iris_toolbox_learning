function outDir = save_results(res, spec, resultsDir)
%SAVE_RESULTS  Write results/<id>/ (DESIGN 9).
%
%   outDir = hetlearn.engine.save_results(res, spec, resultsDir)
%
%   Inputs
%     res         result struct (hetlearn.run)
%     spec        model spec (observables list)
%     resultsDir  parent folder (default <project root>/results)
%
%   Files written in resultsDir/<res.cfg.id>/
%     results.mat        res
%     observables.csv    date + every observable, [filter start, origin+H]
%     paths.csv          date + every transition variable, horizon
%     learning.csv       long format: date, variable, field, value
%     events.csv         date, type, variable, detail, stage
%     compare_<id>.csv   for each res.cfg.compare_with id: this minus that,
%                        observables, horizon (the other scenario is run
%                        first if it has no results)
%     density.mat, density_quantiles.csv, density_events.csv
%                        when res.density exists (density.enabled;
%                        hetlearn.density.write_outputs); res.density is not
%                        stored in results.mat. Without it, density files
%                        left by an earlier run of this id are deleted.
%   Dates are written as text such as 2022Q3.

id = res.cfg.id;
outDir = fullfile(resultsDir, id);
if exist(outDir, 'dir') ~= 7
    mkdir(outDir);
end
D = [];
if isfield(res, 'density')
    D = res.density;
    res = rmfield(res, 'density');
end
save(fullfile(outDir, 'results.mat'), 'res');
if isempty(D)
    stale = {'density.mat', 'density_quantiles.csv', 'density_events.csv'};
    for i = 1:numel(stale)
        if exist(fullfile(outDir, stale{i}), 'file') == 2
            delete(fullfile(outDir, stale{i}));
        end
    end
else
    hetlearn.density.write_outputs(D, outDir);
end

full = res.dates.full;
hz = res.dates.horizon;
obs = spec.observables(isfield(res.paths, spec.observables));
hetlearn.util.write_csv(fullfile(outDir, 'observables.csv'), [{'date'}, obs], ...
    hetlearn.util.date_str(full), values(res.paths, obs, full));

xl = res.meta.xList;
hetlearn.util.write_csv(fullfile(outDir, 'paths.csv'), [{'date'}, xl], ...
    hetlearn.util.date_str(hz), values(res.paths, xl, hz));

% learning.csv (long)
fid = fopen(fullfile(outDir, 'learning.csv'), 'w');
fprintf(fid, 'date,variable,field,value\n');
ds = hetlearn.util.date_str(res.dates.record);
tg = fieldnames(res.learning);
for i = 1:numel(tg)
    L = res.learning.(tg{i});
    f = fieldnames(L);
    for j = 1:numel(f)
        s = L.(f{j});
        if ~isa(s, 'Series')
            continue
        end
        v = s(res.dates.record);
        for k = 1:numel(ds)
            if isfinite(v(k))
                fprintf(fid, '%s,%s,%s,%.17g\n', ds{k}, tg{i}, f{j}, v(k));
            end
        end
    end
end
fclose(fid);

% events.csv
fid = fopen(fullfile(outDir, 'events.csv'), 'w');
fprintf(fid, 'date,type,variable,detail,stage\n');
E = res.events;
hasStage = ismember('stage', E.Properties.VariableNames);
for k = 1:height(E)
    stg = '';
    if hasStage
        stg = E.stage{k};
    end
    fprintf(fid, '%s,%s,%s,%s,%s\n', E.date{k}, E.type{k}, q(E.variable{k}), q(E.detail{k}), stg);
end
fclose(fid);

% comparisons
for i = 1:numel(res.cfg.compare_with)
    oid = res.cfg.compare_with{i};
    other = hetlearn.engine.load_result(oid, resultsDir, true);
    X = values(res.paths, obs, hz);
    Y = NaN(size(X));
    for j = 1:numel(obs)
        if isfield(other.paths, obs{j})
            Y(:, j) = other.paths.(obs{j})(hz);
        end
    end
    hetlearn.util.write_csv(fullfile(outDir, sprintf('compare_%s.csv', oid)), [{'date'}, obs], ...
        hetlearn.util.date_str(hz), X - Y);
end
end


function X = values(db, names, dates)
X = NaN(numel(dates), numel(names));
for j = 1:numel(names)
    X(:, j) = db.(names{j})(dates);
end
end


function s = q(s)
s = ['"' strrep(s, '"', '""') '"'];
end
