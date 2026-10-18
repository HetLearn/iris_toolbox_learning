function B = blocks(sys)
%BLOCKS  PLM blocks: connected sets of PLM equations, the unit of the projection facility's PLM check (DESIGN 4.4).
%
%   B = hetlearn.plm.blocks(sys)
%
%   Input
%     sys  closed PLM system (hetlearn.plm.build_system)
%
%   Output
%     B    1 x nB struct array, ordered by the first equation of each block:
%            .eqs      indices into sys.eq (ascending)
%            .targets  their targets (cellstr, sys.eq order)
%            .label    targets joined with ',' (event text)
%
%   Two equations are linked when one has the other's target among its
%   regressors (any lag). A block is a connected component of that graph:
%   a VAR is one block; an auxiliary equation belongs to the block of the
%   equations that use it (two learning variables that share a regressor
%   are one block); separate AR(1) PLMs are separate blocks. A block is
%   closed (every regressor of its equations is a target in it), so its
%   companion matrix (hetlearn.plm.companion with the block's equations) is
%   defined and the companion of the whole system is block diagonal after
%   a permutation: the largest root of the system is the largest block root.

n = numel(sys.eq);
B = struct('eqs', {}, 'targets', {}, 'label', {});
if n == 0
    return
end
A = eye(n) > 0;
for i = 1:n
    for j = 1:numel(sys.eq(i).reg_names)
        k = find(strcmp(sys.targets, sys.eq(i).reg_names{j}), 1);
        if isempty(k)
            error('hetlearn:plm:open', ...
                'PLM regressor %s of equation %s has no PLM equation: the system is not closed.', ...
                sys.eq(i).reg_names{j}, sys.eq(i).target);
        end
        A(i, k) = true;
        A(k, i) = true;
    end
end
seen = false(1, n);
for i = 1:n
    if seen(i)
        continue
    end
    comp = i;
    seen(i) = true;
    q = 1;
    while q <= numel(comp)
        nb = find(A(comp(q), :) & ~seen);
        seen(nb) = true;
        comp = [comp, nb]; %#ok<AGROW>
        q = q + 1;
    end
    comp = sort(comp);
    tg = sys.targets(comp);
    B(end+1) = struct('eqs', comp, 'targets', {tg}, 'label', strjoin(tg, ',')); %#ok<AGROW>
end
end
