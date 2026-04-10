%% Signal Integrity Workflow Runner
% Minimal script for exercising the shared workflow from the command line.

clearvars; clc; close all;

workflowOptions = signalIntegrity.resolveWorkflowOptions();
workflowOptions.dataFile = "signalIntegrityExampleData.mat";
workflowOptions.showPlots = usejava("desktop");
workflowOptions.showProgress = true;

workflowResults = runSignalIntegrityWorkflow(workflowOptions);
disp(workflowResults.summaryTable);
