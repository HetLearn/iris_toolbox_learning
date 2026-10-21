function spec = model_spec()
%MODEL_SPEC  Package contract (DESIGN 2) of the scalar level-k test economy (tests/test_anchor.m).
%
%   y_t = mu + b*E y_{t+1} + u_t, u_t = rho*u_{t-1} + e_t (mu 0.5, b 0.8, rho 0.6): the economy of the
%   closed form of level-k thinking of Evans, Gibbs and McGough (2025), with one state so that the
%   anchored forecasts have a coefficient besides the constant. No database: the test loads the model
%   and the engine's initial state only.
spec = struct();
spec.name = 'egm';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'egm.model';
spec.params = 'egm_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = '';
spec.filter_range = [];
spec.observables = {};
spec.report = struct();
end
