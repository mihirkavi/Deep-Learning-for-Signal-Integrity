function startup_SignalIntegrityAIWorkbench(projectRoot)
%STARTUP_SIGNALINTEGRITYAIWORKBENCH Add source paths and ensure data folders exist.
%
%   startup_SignalIntegrityAIWORKBENCH() uses this file's folder as project root.
%   startup_SignalIntegrityAIWORKBENCH(PROJECTROOT) uses an explicit path.

arguments
    projectRoot (1, :) char = ""
end

if strlength(projectRoot) == 0
    projectRoot = fileparts(mfilename('fullpath'));
end

addpath(genpath(fullfile(projectRoot, 'src')));
addpath(fullfile(projectRoot, 'app'));

ensureProjectFolders(projectRoot);
ensureDemoCsvExists(projectRoot);

fprintf("Signal Integrity AI Workbench: paths configured for %s\n", projectRoot);
end
