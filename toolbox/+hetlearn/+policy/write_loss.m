function file = write_loss(L, outDir)
%WRITE_LOSS  Write results/<id>/loss.csv: one row per loss target and a total row (DESIGN 13).
%
%   file = hetlearn.policy.write_loss(L, outDir)
%
%   Inputs
%     L       res.loss (hetlearn.policy.loss); nothing is written when empty
%     outDir  results folder of the scenario
%
%   Columns: target, expression, weight, contribution, share (of the total),
%   discount, horizon, continuation (0/1), mode, type. The per-period target
%   values are in results.mat (res.loss.values, .period_loss).

file = '';
if isempty(L)
    return
end
file = fullfile(outDir, 'loss.csv');
fid = fopen(file, 'w');
if fid < 0
    error('hetlearn:policy:write', 'Cannot write %s', file);
end
c = onCleanup(@() fclose(fid));
fprintf(fid, 'target,expression,weight,contribution,share,discount,horizon,continuation,mode,type\n');
names = L.target_names;
for i = 1:numel(names)
    k = names{i};
    fprintf(fid, '%s,"%s",%.17g,%.17g,%.17g,%.17g,%d,%d,%s,%s\n', k, L.targets.(k), L.weights.(k), ...
        L.by_target.(k), L.by_target.(k) / L.total, L.discount, L.horizon, L.continuation, L.mode, L.type);
end
fprintf(fid, 'total,"",,%.17g,1,%.17g,%d,%d,%s,%s\n', L.total, L.discount, L.horizon, ...
    L.continuation, L.mode, L.type);
end
