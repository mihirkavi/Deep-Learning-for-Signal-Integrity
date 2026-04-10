%% Signal Integrity Workflow Runner
% Minimal script for exercising the shared workflow from the command line.

clearvars; clc; close all;

% Ensure project root is on path so +signalIntegrity resolves when CWD differs.
projectRoot = fileparts(mfilename('fullpath'));
if isempty(which('signalIntegrity.resolveWorkflowOptions'))
    addpath(projectRoot);
end

workflowOptions = signalIntegrity.resolveWorkflowOptions();
workflowOptions.dataFile = "signalIntegrityExampleData.mat";
workflowOptions.showPlots = usejava("desktop");
workflowOptions.showProgress = true;

workflowResults = runSignalIntegrityWorkflow(workflowOptions);
disp(workflowResults.summaryTable);
