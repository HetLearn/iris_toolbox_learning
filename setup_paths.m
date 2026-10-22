function setup_paths()
%SETUP_PATHS  Put IRIS and the hetlearn toolbox on the MATLAB path.
%
%   setup_paths()
%
%   Adds the IRIS toolbox folder and runs iris.startup('--silent') unless
%   IRIS is already started, then adds toolbox/, config/ and scenarios/
%   (with subfolders) of this project. Model folders (models/<name>/) are
%   not added: the toolbox reads them through model_spec.folder.
%
%   The IRIS folder (release 20230622) is, in this order:
%     1. the environment variable HETLEARN_IRIS_DIR, if set, for example
%        setenv('HETLEARN_IRIS_DIR', 'D:\toolboxes\IRIS-Toolbox-Release-20230622')
%     2. a folder IRIS-Toolbox-Release-20230622 next to the project folder
%   otherwise setup_paths stops with setup_paths:noIris.

root = fileparts(mfilename('fullpath'));

irisStarted = exist('Model', 'class') == 8 && exist('Series', 'class') == 8;
if ~irisStarted
    irisDir = iris_folder(root);
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


function irisDir = iris_folder(root)
% IRIS folder: HETLEARN_IRIS_DIR, else the sibling IRIS-Toolbox-Release-20230622.
envDir = getenv('HETLEARN_IRIS_DIR');
if ~isempty(envDir)
    if exist(envDir, 'dir') ~= 7
        error('setup_paths:noIris', ...
            'HETLEARN_IRIS_DIR is set to %s, which is not a folder. Point it to the IRIS 20230622 folder.', envDir);
    end
    irisDir = envDir;
    return
end
sibling = fullfile(fileparts(root), 'IRIS-Toolbox-Release-20230622');
if exist(sibling, 'dir') == 7
    irisDir = sibling;
    return
end
error('setup_paths:noIris', ['IRIS Toolbox (release 20230622) not found. Either set the environment ' ...
    'variable HETLEARN_IRIS_DIR to its folder, e.g. setenv(''HETLEARN_IRIS_DIR'', ''D:\\toolboxes\\IRIS-Toolbox-Release-20230622'') ' ...
    'before calling setup_paths, or unzip IRIS into %s.'], sibling);
end
