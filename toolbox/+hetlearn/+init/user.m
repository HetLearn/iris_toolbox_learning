function [phi0, R0] = user(sys, values, fallbackPhi, fallbackR)
%USER  User-supplied initial beliefs with fallback (DESIGN 4.7).
%
%   [phi0, R0] = hetlearn.init.user(sys, values, fallbackPhi, fallbackR)
%
%   Inputs
%     sys          closed PLM system from hetlearn.plm.build_system
%     values       struct by target (opts.beliefs.init.values); for each
%                  target any of
%                    .phi    full coefficient vector (param_names order)
%                    .alpha  constant (only if the PLM has one)
%                    .beta   vector of slope coefficients (regressor order)
%                    .R      k x k second-moment matrix
%                  .phi takes precedence over .alpha/.beta.
%     fallbackPhi  struct by target, used for anything not given (normally
%                  from hetlearn.init.re_moments)
%     fallbackR    struct by target, same
%
%   Outputs
%     phi0, R0     structs by target for every equation in sys
%
%   Entries of values for variables that have no PLM equation raise a
%   warning (likely a typo) and are ignored.

if isempty(values)
    values = struct();
end
extra = setdiff(fieldnames(values), sys.targets);
if ~isempty(extra)
    warning('hetlearn:init:unusedValues', ...
        'beliefs.init.values has entries with no PLM equation (ignored): %s.', strjoin(extra, ', '));
end
phi0 = struct();
R0 = struct();
for i = 1:numel(sys.eq)
    e = sys.eq(i);
    v = e.target;
    k = numel(e.param_names);
    p = fallbackPhi.(v);
    R = fallbackR.(v);
    if isfield(values, v)
        u = values.(v);
        if isfield(u, 'phi') && ~isempty(u.phi)
            p = u.phi(:);
        else
            if isfield(u, 'alpha') && ~isempty(u.alpha)
                if ~e.constant
                    error('hetlearn:init:noConstant', 'The PLM of %s has no constant; drop .alpha.', v);
                end
                p(1) = u.alpha;
            end
            if isfield(u, 'beta') && ~isempty(u.beta)
                b = u.beta(:);
                if numel(b) ~= numel(e.reg_names)
                    error('hetlearn:init:size', 'beliefs.init.values.%s.beta needs %d elements.', ...
                        v, numel(e.reg_names));
                end
                p(e.constant + (1:numel(b))) = b;
            end
        end
        if isfield(u, 'R') && ~isempty(u.R)
            R = u.R;
        end
    end
    p = p(:);
    if numel(p) ~= k
        error('hetlearn:init:size', 'Initial phi for %s has %d elements, expected %d.', v, numel(p), k);
    end
    if ~isequal(size(R), [k k])
        error('hetlearn:init:size', 'Initial R for %s must be %d x %d.', v, k, k);
    end
    phi0.(v) = p;
    R0.(v) = R;
end
end
