function spec = model_spec()
%MODEL_SPEC  Package contract (DESIGN 2) of the Anufriev-Hommes asset-pricing test economy (tests/test_ntypes.m).
%
%   p_t = (p^e_{t+1} + ybar)/(1 + r) with r = 0.05, ybar = 3, fundamental price
%   p^f = ybar/r = 60 (the Hommes et al. 2005 learning-to-forecast market of
%   Anufriev and Hommes 2012), in deviations from p^f. The database
%   (data/ah_database.csv) holds three initial prices; tests/test_ntypes.m
%   writes it before each run (the RE filter cache key covers the file
%   bytes). The subfolder +hetlearn/+gain holds a test gain rule (sample
%   mean, 1/k) for the LAA anchor.
spec = struct();
spec.name = 'ah';
spec.folder = fileparts(mfilename('fullpath'));
spec.model_file = 'ah.model';
spec.params = 'ah_params';
spec.sstate = '';
spec.linear = true;
spec.assign = struct();
spec.database = 'data/ah_database.csv';
spec.filter_range = [qq(2000, 1), qq(2000, 3)];
spec.observables = {'p_obs'};
spec.report = struct();
end
