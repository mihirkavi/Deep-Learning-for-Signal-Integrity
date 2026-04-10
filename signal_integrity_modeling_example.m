%% Signal Integrity Modeling in MATLAB
% This example shows how MATLAB tools can implement a published signal
% integrity workflow. The cited paper is included as a reference, but the
% main focus here is the MATLAB workflow:
% 1) prepare training data,
% 2) train two neural network models,
% 3) compare training methods, and
% 4) review validation accuracy.
%
% The two prediction targets are eye height and eye width, which are common
% signal integrity measures for high-speed links.

clear; clc; close all;

%% MATLAB tools used in this example
toolboxTable = toolboxStatusTable();
disp(toolboxTable);

%% Configure the example
% If `signal_integrity_example_data.mat` contains populated reference data,
% the example uses it automatically. Otherwise it falls back to a
% deterministic synthetic dataset so the workflow still runs end-to-end.
%
% Set `SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE=1` for a faster smoke test.
config = struct();
config.dataFile = "signal_integrity_example_data.mat";
config.makePlots = usejava("desktop");
config.verbose = false;

fprintf("\nThis example will use populated reference data when available.\n");
fprintf("Otherwise it falls back to a deterministic synthetic dataset.\n");

%% Run the workflow
fprintf("\nTraining the models. This can take a few minutes in full mode.\n");
results = signal_integrity_modeling_core(config);
fprintf("Selected data mode: %s\n", results.config.dataMode);

%% Review the results
disp(results.summaryTable);

for id = results.experimentOrder
    block = results.experiments.(char(id));
    fprintf("\n%s\n", block.config.displayName);
    fprintf("Best training method: %s\n", block.bestTrainingMethod);
    disp(block.resultsTable);
    fprintf("Reference values from the cited paper:\n");
    disp(block.referenceTable);
end

if config.makePlots
    makeValidationSummaryPlot(results);
end

%% References
% Reference workflow:
% Lu, Tianjian, Ken Wu, Zhiping Yang, and Ju Sun, "High-Speed Channel
% Modeling with Deep Neural Network for Signal Integrity Analysis."
% Local copy included in this workspace as `46433.pdf`.
%
% MATLAB documentation, accessed March 7, 2026:
% 1. MathWorks, "Custom Training Using Automatic Differentiation,"
%    https://www.mathworks.com/help/deeplearning/custom-training-loops.html
% 2. MathWorks, "Train Network Using Custom Training Loop,"
%    https://www.mathworks.com/help/deeplearning/ug/train-network-using-custom-training-loop.html
% 3. MathWorks, "Get Started with SerDes Toolbox,"
%    https://www.mathworks.com/help/serdes/getting-started-with-serdes-toolbox.html

function t = toolboxStatusTable()
toolbox = [ ...
    "Deep Learning Toolbox"; ...
    "Statistics and Machine Learning Toolbox"; ...
    "Signal Processing Toolbox"; ...
    "Communications Toolbox"; ...
    "SerDes Toolbox"];

availability = [ ...
    ~isempty(ver('nnet')); ...
    ~isempty(ver('stats')); ...
    ~isempty(ver('signal')); ...
    ~isempty(ver('comm')); ...
    ~isempty(ver('serdes'))];

role = [ ...
    "Build and train the neural network models"; ...
    "Compare with classical regression models if needed"; ...
    "Study waveforms and frequency content in larger workflows"; ...
    "Visualize communication signals and eye diagrams"; ...
    "Connect model training to channel and equalization studies"];

status = strings(size(availability));
status(availability) = "Available";
status(~availability) = "Not installed";

t = table(toolbox, status, role, ...
    'VariableNames', {'Toolbox', 'Status', 'RoleInThisExample'});
end

function makeValidationSummaryPlot(results)
fig = figure('Color', 'w', 'Name', 'Validation Summary');
tiledlayout(fig, 1, numel(results.experimentOrder), ...
    'TileSpacing', 'compact', 'Padding', 'compact');

for id = results.experimentOrder
    block = results.experiments.(char(id));
    nexttile;
    b = bar([ ...
        min(block.resultsTable.ValidationRootMeanSquareError), ...
        min(block.referenceTable.ReferenceValidationRootMeanSquareError)]);
    b.FaceColor = 'flat';
    b.CData(1, :) = [0.00 0.45 0.74];
    b.CData(2, :) = [0.40 0.40 0.40];
    grid on;
    set(gca, 'XTickLabel', {'This example', 'Reference'});
    ylabel("Validation root-mean-square error (" + block.config.units + ")");
    title(block.config.displayName);
end
end
