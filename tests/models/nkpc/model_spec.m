function spec = model_spec()
%MODEL_SPEC  Package contract (DESIGN 2) of the closed-form test Phillips curve (tests/test_re_info.m, T3).
%
%   No database: the package is only loaded (hetlearn.load_model), never filtered.
spec = struct();
spec.name = 'nkpc';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'nkpc.model';
spec.params = 'nkpc_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = '';
spec.filter_range = [];
spec.observables = {};
spec.report = struct();
end
