function plotValidationSummary(workflowResults)
%PLOTVALIDATIONSUMMARY Compare workflow and reference validation RMSE.

arguments
    workflowResults (1,1) struct
end

figureHandle = figure('Color', 'w', 'Name', 'Validation Summary');
tiledlayout(figureHandle, 1, numel(workflowResults.experimentOrder), ...
    'TileSpacing', 'compact', 'Padding', 'compact');

for experimentKey = workflowResults.experimentOrder
    experimentResult = workflowResults.experimentResults.(char(experimentKey));

    nexttile;
    validationRmseBySource = [ ...
        min(experimentResult.optimizerComparisonTable.ValidationRMSE), ...
        min(experimentResult.referenceOptimizerComparisonTable.ReferenceValidationRMSE)];
    barSeries = bar(validationRmseBySource);
    barSeries.FaceColor = 'flat';
    barSeries.CData(1, :) = [0.00 0.45 0.74];
    barSeries.CData(2, :) = [0.40 0.40 0.40];
    grid on;
    set(gca, 'XTickLabel', {'This project', 'Reference'});
    ylabel("Validation RMSE (" + experimentResult.experimentSpec.units + ")");
    title(experimentResult.experimentSpec.displayName);
end
end
