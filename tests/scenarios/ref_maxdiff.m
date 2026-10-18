function [d, worst] = ref_maxdiff(res, ref)
%REF_MAXDIFF  Max abs difference of paths (full range) and learning series (record dates) between a result and a stored reference.
d = 0;
worst = '';
for n = fieldnames(ref.paths)'
    if ~isa(ref.paths.(n{1}), 'Series') || ~isfield(res.paths, n{1})
        continue
    end
    a = res.paths.(n{1})(ref.dates.full);
    b = ref.paths.(n{1})(ref.dates.full);
    k = ~(isnan(a) & isnan(b));
    v = max([0; abs(a(k) - b(k))]);
    if isnan(v) || v > d
        d = v;
        worst = n{1};
    end
end
for x = fieldnames(ref.learning)'
    for f = fieldnames(ref.learning.(x{1}))'
        s = ref.learning.(x{1}).(f{1});
        if isa(s, 'Series')
            a = res.learning.(x{1}).(f{1})(ref.dates.record);
            b = s(ref.dates.record);
            k = ~(isnan(a) & isnan(b));
            v = max([0; abs(a(k) - b(k))]);
            if isnan(v) || v > d
                d = v;
                worst = [x{1} '.' f{1}];
            end
        end
    end
end
end
