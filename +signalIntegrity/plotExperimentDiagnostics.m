function plotExperimentDiagnostics(optimizerResults, bestOptimizerResult, experimentSpec, workflowOptions)
%PLOTEXPERIMENTDIAGNOSTICS Plot optimizer convergence and validation error.

arguments
    optimizerResults cell
    bestOptimizerResult (1,1) struct
    experimentSpec (1,1) struct
    workflowOptions (1,1) struct
end

figureHandle = figure('Color', 'w', 'Name', experimentSpec.displayName + " Diagnostics");
tiledlayout(figureHandle, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
hold on;
for optimizerIndex = 1:numel(optimizerResults)
    plot(optimizerResults{optimizerIndex}.trainingRmseHistory, 'LineWidth', 1.4, ...
        'DisplayName', signalIntegrity.getOptimizerDisplayName(optimizerResults{optimizerIndex}.optimizerName));
end
hold off;
grid on;
xlabel('Iteration');
ylabel("Training RMSE (" + experimentSpec.units + ")");
title(experimentSpec.displayName + " Convergence");
legend('Location', 'northeast');

nexttile;
plot(bestOptimizerResult.validationRelativeErrorPct, '.', 'MarkerSize', 10);
grid on;
xlabel('Validation sample');
ylabel('Relative error (%)');
title(experimentSpec.displayName + " Validation Error (" + ...
    signalIntegrity.getOptimizerDisplayName(bestOptimizerResult.optimizerName) + ")");

if workflowOptions.saveFigures
    ensureFolderExists(workflowOptions.figureOutputFolder);
    exportgraphics( ...
        figureHandle, ...
        fullfile(workflowOptions.figureOutputFolder, experimentSpec.key + "Diagnostics.png"));
end
end

function ensureFolderExists(folderPath)
if ~isfolder(folderPath)
    mkdir(folderPath);
end
end
