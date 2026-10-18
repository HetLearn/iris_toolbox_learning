function write_outputs(D, outDir)
%WRITE_OUTPUTS  Write density.mat, density_quantiles.csv, density_events.csv (DESIGN 14).
%
%   hetlearn.density.write_outputs(D, outDir)
%
%   Inputs
%     D       output of hetlearn.density.run
%     outDir  results/<id>/ folder (exists)
%
%   Files
%     density.mat            variable 'density' = D (quantiles, means, stds
%                            and point forecasts of every summarised series,
%                            draw information, events; the draws if kept)
%     density_quantiles.csv  long: variable, date, quantile, value_model,
%                            value_report (= value_model x spec.report.scale;
%                            learning series unscaled); empty when NaN
%     density_events.csv     one row per draw: draw, status, the event counts
%                            in the fixed order of D.events (projection_plm,
%                            projection_alm, projection_alm_shares,
%                            explosive_events, rls_missing,
%                            shares_nan, gain_bound), max_abs, message

density = D; %#ok<NASGU>
save(fullfile(outDir, 'density.mat'), 'density');

ds = hetlearn.util.date_str(D.dates);
fid = fopen(fullfile(outDir, 'density_quantiles.csv'), 'w');
if fid < 0
    error('hetlearn:density:write', 'Cannot write %s', fullfile(outDir, 'density_quantiles.csv'));
end
c = onCleanup(@() fclose(fid));
fprintf(fid, 'variable,date,quantile,value_model,value_report\n');
for i = 1:numel(D.names)
    z = D.series.(D.names{i});
    for k = 1:numel(ds)
        for j = 1:numel(D.quantiles)
            fprintf(fid, '%s,%s,%s,%s,%s\n', D.names{i}, ds{k}, num(D.quantiles(j)), ...
                num(z.q(k, j)), num(z.q_report(k, j)));
        end
    end
end
clear c

E = D.events;
fid = fopen(fullfile(outDir, 'density_events.csv'), 'w');
if fid < 0
    error('hetlearn:density:write', 'Cannot write %s', fullfile(outDir, 'density_events.csv'));
end
c = onCleanup(@() fclose(fid));
[~, cols] = hetlearn.density.run('event_types');
fprintf(fid, '%s\n', strjoin([{'draw', 'status'}, cols, {'max_abs', 'message'}], ','));
for k = 1:height(E)
    cnt = zeros(1, numel(cols));
    for j = 1:numel(cols)
        if ismember(cols{j}, E.Properties.VariableNames)
            cnt(j) = E.(cols{j})(k);
        end
    end
    fprintf(fid, '%d,%s,%s,%s,"%s"\n', E.draw(k), E.status{k}, ...
        strjoin(arrayfun(@(v) sprintf('%d', v), cnt, 'UniformOutput', false), ','), ...
        num(E.max_abs(k)), strrep(E.message{k}, '"', '""'));
end
end


function s = num(v)
if isnan(v)
    s = '';
else
    s = sprintf('%.17g', v);
end
end
