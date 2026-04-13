%% Signal Integrity Workflow Example
% This walkthrough reproduces the paper-inspired workflow in a compact,
% inspectable MATLAB project. The script:
% 1) summarizes relevant toolboxes (including Signal Integrity Toolbox when installed),
% 2) explains objectives, inputs, and constraints in plain language,
% 3) trains the eye-height and eye-width regressors with progress in the command window,
% 4) shows integrated figures: training curves, native Signal Integrity Toolbox
%    eyes when available, predictions vs validation, input sensitivity, and
%    a reference RMSE comparison,
% 5) summarizes how to interpret validation vs simulation and how to use the trained nets.

clearvars; clc; close all;

% Ensure project root is on path so +signalIntegrity resolves when CWD differs.
projectRoot = fileparts(mfilename('fullpath'));
if isempty(which('signalIntegrity.resolveWorkflowOptions'))
    addpath(projectRoot);
end

%% Installed toolboxes (Signal Integrity and related products)
fprintf('\n=== Installed toolboxes relevant to signal integrity workflows ===\n');
disp(signalIntegrity.buildToolboxStatusTable());

%% Narrative: SI Toolbox role, goals, design variables, constraints, figure roadmap
signalIntegrity.printWorkflowWalkthroughIntro();

%% Configure the workflow
% The tracked `signalIntegrityExampleData.mat` file is intentionally
% zero-filled, so fresh clones automatically use the deterministic
% synthetic fallback. Run `createSignalIntegrityDataTemplate` to recreate
% the placeholder MAT-file if needed.
%
% Set `SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE=1` for a faster smoke test.
workflowOptions = signalIntegrity.resolveWorkflowOptions();
workflowOptions.dataFile = "signalIntegrityExampleData.mat";
workflowOptions.showPlots = false;
workflowOptions.showProgress = usejava("desktop");
% Optional SI Toolbox waveform override:
% workflowOptions.siWaveformMatFile = "myEyeWaveform.mat";
% workflowOptions.siWaveformVariable = "samples";
% workflowOptions.siWaveformTimeVariable = "time";

fprintf("\nThis run uses populated reference data when available.\n");
fprintf("Otherwise it switches to the deterministic synthetic fallback.\n");

%% Run the workflow
fprintf("\nTraining the models. Full mode can take a few minutes.\n");
workflowResults = runSignalIntegrityWorkflow(workflowOptions);
fprintf("Resolved data mode: %s\n", workflowResults.options.dataMode);

%% Review the results (tables)
disp(workflowResults.summaryTable);

for experimentKey = workflowResults.experimentOrder
    experimentResult = workflowResults.experimentResults.(char(experimentKey));

    fprintf("\n%s\n", experimentResult.experimentSpec.displayName);
    fprintf("Best optimizer: %s\n", experimentResult.bestOptimizerName);
    disp(experimentResult.optimizerComparisonTable);
    fprintf("Reference metrics from the paper:\n");
    disp(experimentResult.referenceOptimizerComparisonTable);
end

signalIntegrity.printWorkflowWalkthroughOutro(workflowResults);

%% Figures: training progress, SI eye diagram, prediction vs validation, sensitivity
if usejava("desktop")
    signalIntegrity.plotExampleWalkthroughFigures(workflowResults);
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
