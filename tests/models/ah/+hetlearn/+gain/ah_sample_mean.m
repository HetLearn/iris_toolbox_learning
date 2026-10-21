function varargout = ah_sample_mean(cmd, varargin)
%AH_SAMPLE_MEAN  Test gain rule: gain 1/k at the k-th update of each PLM equation (tests/test_ntypes.m).
%
%   Test double for the Anufriev-Hommes LAA anchor, the sample average of
%   all prices: a mean-only belief updated by RLS on a constant with gain
%   1/k is the running mean of the data from beliefs.init.date (the first
%   update has gain 1). gain.rule = 'decreasing' (phase P5) is the toolbox
%   rule; this file lives in tests/models/ah/+hetlearn/+gain/ and is on the
%   path only while tests/test_ntypes.m runs the AH checks. Interface of
%   hetlearn.gain.constant.

switch char(cmd)
    case 'fields'
        varargout{1} = {};
    case 'init'
        sys = varargin{1};
        G = struct('rule', 'ah_sample_mean', 'count', struct());
        for i = 1:numel(sys.eq)
            G.count.(sys.eq(i).target) = 0;
        end
        varargout{1} = G;
    case 'gain'
        G = varargin{1};
        errors = varargin{2};
        g = struct();
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            g.(tg) = 1 / (G.count.(tg) + 1);
        end
        varargout{1} = g;
    case 'update'
        G = varargin{1};
        errors = varargin{2};
        for i = 1:numel(errors.targets)
            tg = errors.targets{i};
            if isfinite(errors.rls.(tg))
                G.count.(tg) = G.count.(tg) + 1;
            end
        end
        varargout = {G, struct('date', {}, 'type', {}, 'variable', {}, 'detail', {})};
    otherwise
        error('hetlearn:gain:call', 'Unknown call ah_sample_mean(''%s'', ...).', char(cmd));
end
end
