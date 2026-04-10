function workflowResults = runWorkflow(workflowOptions)
%RUNWORKFLOW Orchestrate the signal integrity training workflow.
%   WORKFLOWRESULTS = signalIntegrity.runWorkflow(WORKFLOWOPTIONS)
%   resolves options, loads or synthesizes data, trains each experiment,
%   builds human-readable summary tables, and optionally generates figures.

arguments
    workflowOptions struct = struct()
end

resolvedOptions = signalIntegrity.resolveWorkflowOptions(workflowOptions);
rng(46433, "twister");

experimentCatalog = signalIntegrity.getExperimentCatalog();
[workflowData, resolvedDataMode] = signalIntegrity.loadWorkflowData(resolvedOptions, experimentCatalog);
resolvedOptions.dataMode = resolvedDataMode;
resolvedOptions = applyModeSpecificDefaults(resolvedOptions);

workflowResults = struct();
workflowResults.options = resolvedOptions;
workflowResults.experimentResults = struct();

for experimentIndex = 1:numel(experimentCatalog)
    experimentSpec = experimentCatalog(experimentIndex);
    experimentKey = char(experimentSpec.key);
    experimentData = workflowData.(experimentKey);

    if resolvedOptions.showProgress
        printExperimentHeader(experimentSpec, experimentData);
    end

    trainedExperiment = signalIntegrity.trainExperimentModels( ...
        experimentData, ...
        experimentSpec, ...
        resolvedOptions);

    optimizerComparisonTable = buildOptimizerComparisonTable(trainedExperiment.optimizerResults);
    referenceOptimizerComparisonTable = buildReferenceOptimizerComparisonTable( ...
        experimentSpec, ...
        resolvedOptions.optimizerNames);
    bestOptimizerResult = trainedExperiment.bestOptimizerResult;
    bestOptimizerName = signalIntegrity.getOptimizerDisplayName(bestOptimizerResult.optimizerName);

    if resolvedOptions.showPlots
        signalIntegrity.plotExperimentDiagnostics( ...
            trainedExperiment.optimizerResults, ...
            bestOptimizerResult, ...
            experimentSpec, ...
            resolvedOptions);
    end

    workflowResults.experimentResults.(experimentKey) = struct( ...
        'experimentSpec', experimentSpec, ...
        'dataSource', experimentData.metadata.source, ...
        'optimizerResults', {trainedExperiment.optimizerResults}, ...
        'optimizerComparisonTable', optimizerComparisonTable, ...
        'referenceOptimizerComparisonTable', referenceOptimizerComparisonTable, ...
        'bestOptimizerName', bestOptimizerName, ...
        'bestOptimizerResult', bestOptimizerResult, ...
        'normalizationStatistics', trainedExperiment.normalizationStatistics);

    if resolvedOptions.showProgress
        printExperimentSummary(bestOptimizerName, optimizerComparisonTable);
    end
end

workflowResults.summaryTable = buildSummaryTable(workflowResults.experimentResults, experimentCatalog);
workflowResults.experimentOrder = string({experimentCatalog.key});

if resolvedOptions.showProgress
    fprintf("\n=== Summary ===\n");
    disp(workflowResults.summaryTable);
end
end

function resolvedOptions = applyModeSpecificDefaults(resolvedOptions)
if isempty(resolvedOptions.momentumLearningRate)
    if resolvedOptions.dataMode == "real"
        resolvedOptions.momentumLearningRate = 0.01;
    else
        resolvedOptions.momentumLearningRate = 0.003;
    end
end
end

function printExperimentHeader(experimentSpec, experimentData)
fprintf("\n=== %s ===\n", experimentSpec.displayName);
fprintf("Data source: %s\n", experimentData.metadata.source);
fprintf("Hidden layer sizes: [%s]\n", num2str(experimentSpec.hiddenLayerSizes));
fprintf( ...
    "Training/validation samples: %d / %d\n", ...
    size(experimentData.trainingFeatures, 1), ...
    size(experimentData.validationFeatures, 1));
end

function printExperimentSummary(bestOptimizerName, optimizerComparisonTable)
fprintf("  Best optimizer on validation data: %s\n", bestOptimizerName);
disp(optimizerComparisonTable);
end

function optimizerComparisonTable = buildOptimizerComparisonTable(optimizerResults)
optimizerDisplayNames = string(cellfun( ...
    @(optimizerResult) signalIntegrity.getOptimizerDisplayName(optimizerResult.optimizerName), ...
    optimizerResults, ...
    'UniformOutput', false))';
trainingRmse = cellfun(@(optimizerResult) optimizerResult.trainingRmse, optimizerResults)';
validationRmse = cellfun(@(optimizerResult) optimizerResult.validationRmse, optimizerResults)';
trainingMaxRelativeErrorPct = cellfun( ...
    @(optimizerResult) optimizerResult.maxTrainingRelativeErrorPct, ...
    optimizerResults)';
validationMaxRelativeErrorPct = cellfun( ...
    @(optimizerResult) optimizerResult.maxValidationRelativeErrorPct, ...
    optimizerResults)';

optimizerComparisonTable = table( ...
    optimizerDisplayNames, ...
    trainingRmse, ...
    validationRmse, ...
    trainingMaxRelativeErrorPct, ...
    validationMaxRelativeErrorPct, ...
    'VariableNames', {'Optimizer', 'TrainingRMSE', 'ValidationRMSE', ...
    'TrainingMaxRelativeErrorPct', 'ValidationMaxRelativeErrorPct'});
end

function referenceOptimizerComparisonTable = buildReferenceOptimizerComparisonTable(experimentSpec, optimizerNames)
referenceOptimizerOrder = ["SGD", "Momentum", "RMSProp"];
optimizerDisplayNames = strings(numel(optimizerNames), 1);
referenceTrainingRmse = zeros(numel(optimizerNames), 1);
referenceValidationRmse = zeros(numel(optimizerNames), 1);
referenceTrainingMaxRelativeErrorPct = zeros(numel(optimizerNames), 1);
referenceValidationMaxRelativeErrorPct = zeros(numel(optimizerNames), 1);

for optimizerIndex = 1:numel(optimizerNames)
    optimizerName = optimizerNames(optimizerIndex);
    referenceIndex = find(referenceOptimizerOrder == optimizerName, 1);

    optimizerDisplayNames(optimizerIndex) = signalIntegrity.getOptimizerDisplayName(optimizerName);
    referenceTrainingRmse(optimizerIndex) = experimentSpec.referenceTrainingRmse(referenceIndex);
    referenceValidationRmse(optimizerIndex) = experimentSpec.referenceValidationRmse(referenceIndex);
    referenceTrainingMaxRelativeErrorPct(optimizerIndex) = ...
        experimentSpec.referenceTrainingMaxRelativeErrorPct(referenceIndex);
    referenceValidationMaxRelativeErrorPct(optimizerIndex) = ...
        experimentSpec.referenceValidationMaxRelativeErrorPct(referenceIndex);
end

referenceOptimizerComparisonTable = table( ...
    optimizerDisplayNames, ...
    referenceTrainingRmse, ...
    referenceValidationRmse, ...
    referenceTrainingMaxRelativeErrorPct, ...
    referenceValidationMaxRelativeErrorPct, ...
    'VariableNames', {'Optimizer', 'ReferenceTrainingRMSE', 'ReferenceValidationRMSE', ...
    'ReferenceTrainingMaxRelativeErrorPct', 'ReferenceValidationMaxRelativeErrorPct'});
end

function summaryTable = buildSummaryTable(experimentResults, experimentCatalog)
experimentNames = strings(numel(experimentCatalog), 1);
dataSources = strings(numel(experimentCatalog), 1);
bestOptimizers = strings(numel(experimentCatalog), 1);
bestValidationRmse = zeros(numel(experimentCatalog), 1);
referenceBestValidationRmse = zeros(numel(experimentCatalog), 1);

for experimentIndex = 1:numel(experimentCatalog)
    experimentSpec = experimentCatalog(experimentIndex);
    experimentResult = experimentResults.(char(experimentSpec.key));

    experimentNames(experimentIndex) = experimentSpec.displayName;
    dataSources(experimentIndex) = experimentResult.dataSource;
    bestOptimizers(experimentIndex) = experimentResult.bestOptimizerName;
    bestValidationRmse(experimentIndex) = ...
        min(experimentResult.optimizerComparisonTable.ValidationRMSE);
    referenceBestValidationRmse(experimentIndex) = ...
        min(experimentResult.referenceOptimizerComparisonTable.ReferenceValidationRMSE);
end

summaryTable = table( ...
    experimentNames, ...
    dataSources, ...
    bestOptimizers, ...
    bestValidationRmse, ...
    referenceBestValidationRmse, ...
    'VariableNames', {'Experiment', 'DataSource', 'BestOptimizer', ...
    'BestValidationRMSE', 'ReferenceBestValidationRMSE'});
end
