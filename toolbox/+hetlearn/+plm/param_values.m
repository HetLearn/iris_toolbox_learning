function P = param_values(sys, phi)
%PARAM_VALUES  IRIS parameter assignments for the PLM beliefs.
%
%   P = hetlearn.plm.param_values(sys, phi)
%
%   Inputs
%     sys  closed PLM system from hetlearn.plm.build_system
%     phi  struct by target of coefficient column vectors (param_names order)
%
%   Output
%     P    struct with one field per belief parameter, e.g. P.alpha_pinf,
%          P.beta_pinf, P.beta_pinf__w_l2; assign to a model with
%          m = assign(m, P) or field by field.

P = struct();
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    c = phi.(e.target);
    c = c(:);
    if numel(c) ~= numel(e.param_names)
        error('hetlearn:plm:phiSize', 'phi.%s has %d elements, expected %d.', ...
            e.target, numel(c), numel(e.param_names));
    end
    for k = 1:numel(e.param_names)
        P.(e.param_names{k}) = c(k);
    end
end
end
