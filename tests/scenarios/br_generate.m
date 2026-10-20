function G = br_generate()
%BR_GENERATE  Generate the default and _relag extended model files of SW07 and the toy models (test_br_regression R1).
%
%   G = br_generate()
%
%   For each package (models/sw07; tests/toy_nk nk3.model as 'nk3' and nk3_lead1.model as 'nk3l1')
%   the source model file and its parameter file are copied to a new temporary folder, and
%   hetlearn.extend_model writes <name>_ext_ar1.model (expectations.re_info = 'current') and
%   <name>_ext_ar1_relag.model ('lagged') there, forced, with the PLM subtree of hetlearn.defaults
%   (beliefs.plm, as hetlearn.load_model passes it) and without the collapse test (the file text
%   does not depend on it). The model caches in models/*/generated/ and tests/toy_nk/generated/
%   are not touched, so the check can run beside other sessions.
%
%   Output G, struct array: package, re_info, file (base name), md5, bytes (uint8 row, the file),
%   generator_version (0 for a <name>_norm.model, the normalised source the generator writes when
%   the source needs it; nk3 does).

here = fileparts(mfilename('fullpath'));    % tests/scenarios
tests = fileparts(here);
root = fileparts(tests);
pk = {'sw07', fullfile(root, 'models', 'sw07'), '', ''
    'nk3', fullfile(tests, 'toy_nk'), '', ''
    'nk3l1', fullfile(tests, 'toy_nk'), 'nk3l1', 'nk3_lead1.model'};
o = hetlearn.load_options(struct(), struct());       % hetlearn.defaults only (no master file)
G = struct('package', {}, 're_info', {}, 'file', {}, 'md5', {}, 'bytes', {}, 'generator_version', {});
for i = 1:size(pk, 1)
    spec = hetlearn.load_spec(pk{i, 2});
    if ~isempty(pk{i, 3})
        spec.name = pk{i, 3};
        spec.model_file = pk{i, 4};
    end
    tmp = tempname;
    mkdir(tmp);
    c = onCleanup(@() rmdir(tmp, 's'));
    copyfile(fullfile(spec.folder, spec.model_file), tmp);
    copyfile(fullfile(spec.folder, [spec.params '.m']), tmp);
    sp = spec;
    sp.folder = tmp;
    for info = {'current', 'lagged'}
        meta = hetlearn.extend_model(sp, o.beliefs.plm, 'force', true, 'validate', false, 're_info', info{1});
        G(end+1) = entry(pk{i, 1}, info{1}, meta.ext_file, meta.generator_version); %#ok<AGROW>
    end
    nf = fullfile(tmp, 'generated', [sp.name '_norm.model']);
    if exist(nf, 'file') == 2
        G(end+1) = entry(pk{i, 1}, 'norm', nf, 0); %#ok<AGROW>
    end
    clear c
end
end


function e = entry(package, reInfo, file, version)
b = hetlearn.util.file_bytes(file);
[~, n, x] = fileparts(file);
e = struct('package', package, 're_info', reInfo, 'file', [n x], 'md5', hetlearn.util.md5(b), ...
    'bytes', b, 'generator_version', version);
end
