function setup_paths()
%SETUP_PATHS  Put IRIS and the hetlearn toolbox on the MATLAB path.
%
%   setup_paths()
%
%   Adds the IRIS toolbox folder and runs iris.startup('--silent') unless
%   IRIS is already started, then adds toolbox/, config/ and scenarios/
%   (with subfolders) of this project. Model folders (models/<name>/) are
%   not added: the toolbox reads them through model_spec.folder.

root = fileparts(mfilename('fullpath'));
irisDir = 'C:\Users\TZ4\OneDrive - Asian Development Bank\Desktop\IRIS-Toolbox-Release-20230622';

irisStarted = exist('Model', 'class') == 8 && exist('Series', 'class') == 8;
if ~irisStarted
    if exist(irisDir, 'dir') ~= 7
        error('setup_paths:noIris', 'IRIS folder not found: %s', irisDir);
    end
    addpath(irisDir);
    iris.startup('--silent');
end

addpath(fullfile(root, 'toolbox'));
% Shadow copies of IRIS files fixed for MATLAB R2025a (toolbox/iris_patches,
% DESIGN 13): added after IRIS has started, at the front of the path, so that
% which('model.Insertable') is the patch. The IRIS installation is untouched.
patchDir = fullfile(root, 'toolbox', 'iris_patches');
if exist(patchDir, 'dir') == 7
    addpath(patchDir, '-begin');
    rehash;
end
addpath(fullfile(root, 'config'));
if exist(fullfile(root, 'scenarios'), 'dir') == 7
    addpath(genpath(fullfile(root, 'scenarios')));
end
end
