%% Signal Integrity Workflow Example
% This walkthrough reproduces the paper-inspired workflow in a compact,
% inspectable MATLAB project. The script:
% 1) reports relevant toolboxes,
% 2) resolves the workflow options,
% 3) trains the eye-height and eye-width regressors, and
% 4) compares the validation metrics against the reference paper.

clearvars; clc; close all;

% Ensure project root is on path so +signalIntegrity resolves when CWD differs.
projectRoot = fileparts(mfilename('fullpath'));
if isempty(which('signalIntegrity.resolveWorkflowOptions'))
    addpath(projectRoot);
end

%% Toolbox overview
disp(signalIntegrity.buildToolboxStatusTable());

%% Configure the workflow
% The tracked `signalIntegrityExampleData.mat` file is intentionally
% zero-filled, so fresh clones automatically use the deterministic
% synthetic fallback. Run `createSignalIntegrityDataTemplate` to recreate
% the placeholder MAT-file if needed.
%
% Set `SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE=1` for a faster smoke test.
workflowOptions = signalIntegrity.resolveWorkflowOptions();
workflowOptions.dataFile = "signalIntegrityExampleData.mat";
workflowOptions.showPlots = usejava("desktop");
workflowOptions.showProgress = false;

fprintf("\nThis run uses populated reference data when available.\n");
fprintf("Otherwise it switches to the deterministic synthetic fallback.\n");

%% Run the workflow
fprintf("\nTraining the models. Full mode can take a few minutes.\n");
workflowResults = runSignalIntegrityWorkflow(workflowOptions);
fprintf("Resolved data mode: %s\n", workflowResults.options.dataMode);

%% Review the results
disp(workflowResults.summaryTable);

for experimentKey = workflowResults.experimentOrder
    experimentResult = workflowResults.experimentResults.(char(experimentKey));

    fprintf("\n%s\n", experimentResult.experimentSpec.displayName);
    fprintf("Best optimizer: %s\n", experimentResult.bestOptimizerName);
    disp(experimentResult.optimizerComparisonTable);
    fprintf("Reference metrics from the paper:\n");
    disp(experimentResult.referenceOptimizerComparisonTable);
end

if workflowOptions.showPlots
    signalIntegrity.plotValidationSummary(workflowResults);
end

%% References
% Lu, Tianjian, Ken Wu, Zhiping Yang, and Ju Sun,
% "High-Speed Channel Modeling with Deep Neural Network for Signal
% Integrity Analysis." A local copy is included as
% `signalIntegrityReferencePaper.pdf`.
%
% MATLAB documentation accessed March 7, 2026:
% 1. MathWorks, "Custom Training Using Automatic Differentiation"
% 2. MathWorks, "Train Network Using Custom Training Loop"
% 3. MathWorks, "Get Started with SerDes Toolbox"
