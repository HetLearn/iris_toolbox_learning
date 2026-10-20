function [lp, ll, lpr, out] = logpost(pb, theta, varargin)
%LOGPOST  Log posterior kernel: log likelihood + log prior, with the -Inf rules of the design (5.7).
%
%   [lp, ll, lpr, out] = hlest.logpost(pb, theta)
%   [lp, ll, lpr, out] = hlest.logpost(pb, theta, 'paths', true)    % learning model options
%
%   -Inf when theta is outside the hard bounds or the prior support, the RE model has no
%   unique stable solution, the ALM has no solution at the first check, a prediction-error
%   covariance is not positive definite, or anything is NaN. Later ALM failures are handled
%   by the projection facility inside the likelihood and are part of the model.

theta = theta(:);
ll = -Inf;
lp = -Inf;
out = struct('status', 'ok');
if numel(theta) ~= pb.n || any(~isfinite(theta)) || any(theta < pb.lb) || any(theta > pb.ub)
    lpr = -Inf;
    out.status = 'outside the bounds';
    return
end
lpr = hlest.prior_logpdf(pb.tab, theta);
if ~isfinite(lpr)
    out.status = 'outside the prior support';
    return
end
switch pb.kind
    case 're'
        wantPaths = ~isempty(varargin) && any(strcmp(varargin(1:2:end), 'paths')) && ...
            logical(varargin{find(strcmp(varargin(1:2:end), 'paths'))*2});
        [ll, out] = hlest.loglik_re(pb, theta, wantPaths);
    case 'learn'
        [ll, out] = hlest.loglik_learn(pb, theta, varargin{:});
end
if ~isfinite(ll) || isnan(ll)
    ll = -Inf;
    return
end
lp = ll + lpr;
end
