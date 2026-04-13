function trainedExperiment = trainExperimentModels(experimentData, experimentSpec, workflowOptions)
%TRAINEXPERIMENTMODELS Train every configured optimizer for one experiment.
%   TRAINEDEXPERIMENT contains the per-optimizer results, the best
%   optimizer result on the validation set, and the feature-normalization
%   statistics computed from the training data.

arguments
    experimentData (1,1) struct
    experimentSpec (1,1) struct
    workflowOptions (1,1) struct
end

[standardizedTrainingFeatures, standardizedValidationFeatures, normalizationStatistics] = ...
    standardizeUsingTrainingStatistics( ...
        experimentData.trainingFeatures, ...
        experimentData.validationFeatures);

trainingTargets = experimentData.trainingTargets;
validationTargets = experimentData.validationTargets;

trainingOptions = workflowOptions;
trainingOptions.miniBatchSize = experimentSpec.miniBatchSize;

optimizerResults = cell(1, numel(trainingOptions.optimizerNames));
for optimizerIndex = 1:numel(trainingOptions.optimizerNames)
    optimizerName = trainingOptions.optimizerNames(optimizerIndex);

    if trainingOptions.showProgress
        fprintf("  Training optimizer: %s\n", signalIntegrity.getOptimizerDisplayName(optimizerName));
    end

    optimizerResults{optimizerIndex} = trainSingleOptimizerModel( ...
        standardizedTrainingFeatures, ...
        trainingTargets, ...
        standardizedValidationFeatures, ...
        validationTargets, ...
        experimentSpec.hiddenLayerSizes, ...
        trainingOptions, ...
        optimizerName);

    if trainingOptions.showProgress
        printOptimizerMetrics(optimizerResults{optimizerIndex}, experimentSpec.units);
    end
end

validationRmseByOptimizer = cellfun(@(optimizerResult) optimizerResult.validationRmse, optimizerResults);
[~, bestOptimizerIndex] = min(validationRmseByOptimizer);

trainedExperiment = struct( ...
    'optimizerResults', {optimizerResults}, ...
    'bestOptimizerResult', optimizerResults{bestOptimizerIndex}, ...
    'normalizationStatistics', normalizationStatistics);
end

function [standardizedTrainingFeatures, standardizedValidationFeatures, normalizationStatistics] = ...
        standardizeUsingTrainingStatistics(trainingFeatures, validationFeatures)

featureMeans = mean(trainingFeatures, 1);
featureStandardDeviations = std(trainingFeatures, 0, 1);
featureStandardDeviations(featureStandardDeviations < 1e-12) = 1;

standardizedTrainingFeatures = (trainingFeatures - featureMeans) ./ featureStandardDeviations;
standardizedValidationFeatures = (validationFeatures - featureMeans) ./ featureStandardDeviations;

normalizationStatistics = struct( ...
    'featureMeans', featureMeans, ...
    'featureStandardDeviations', featureStandardDeviations);
end

function optimizerResult = trainSingleOptimizerModel( ...
        trainingFeatures, ...
        trainingTargets, ...
        validationFeatures, ...
        validationTargets, ...
        hiddenLayerSizes, ...
        trainingOptions, ...
        optimizerName)

inputFeatureCount = size(trainingFeatures, 2);
network = buildRegressionNetwork(inputFeatureCount, hiddenLayerSizes);
learningRate = resolveLearningRate(trainingOptions, optimizerName);

velocityState = [];
averageSquaredGradientState = [];
trainingRmseHistory = zeros(trainingOptions.maxIterations, 1);
mostRecentTrainingRmse = NaN;
trainingSampleCount = size(trainingFeatures, 1);

for iterationIndex = 1:trainingOptions.maxIterations
    miniBatchIndices = randi(trainingSampleCount, trainingOptions.miniBatchSize, 1);
    miniBatchFeatures = trainingFeatures(miniBatchIndices, :);
    miniBatchTargets = trainingTargets(miniBatchIndices, :);

    dlFeatures = dlarray(miniBatchFeatures', "CB");
    dlTargets = dlarray(miniBatchTargets', "CB");

    [trainingLoss, networkGradients] = dlfeval( ...
        @computeModelGradients, ...
        network, ...
        dlFeatures, ...
        dlTargets, ...
        trainingOptions.l2Penalty);

    if trainingOptions.gradientClipNorm > 0
        networkGradients = dlupdate( ...
            @(gradient) clipGradientByL2Norm(gradient, trainingOptions.gradientClipNorm), ...
            networkGradients);
    end

    switch optimizerName
        case "SGD"
            network = dlupdate( ...
                @(parameter, gradient) parameter - learningRate * gradient, ...
                network, ...
                networkGradients);
        case "Momentum"
            [network, velocityState] = sgdmupdate( ...
                network, ...
                networkGradients, ...
                velocityState, ...
                learningRate, ...
                trainingOptions.momentumFactor);
        case "RMSProp"
            [network, averageSquaredGradientState] = rmspropupdate( ...
                network, ...
                networkGradients, ...
                averageSquaredGradientState, ...
                learningRate, ...
                trainingOptions.rmsDecayFactor, ...
                trainingOptions.rmsEpsilon);
        otherwise
            error("signalIntegrity:trainExperimentModels:UnsupportedOptimizer", ...
                "Unsupported optimizer: %s", optimizerName);
    end

    if iterationIndex == 1 || ...
            mod(iterationIndex, trainingOptions.rmseEvaluationStride) == 0 || ...
            iterationIndex == trainingOptions.maxIterations
        trainingPredictions = predictRegressionTargets( ...
            network, ...
            trainingFeatures, ...
            trainingOptions.predictionMiniBatchSize);
        mostRecentTrainingRmse = computeRootMeanSquareError(trainingPredictions, trainingTargets);
    end

    if isnan(mostRecentTrainingRmse)
        mostRecentTrainingRmse = sqrt(double(gather(extractdata(trainingLoss))));
    end

    trainingRmseHistory(iterationIndex) = mostRecentTrainingRmse;
end

trainingPredictions = predictRegressionTargets( ...
    network, ...
    trainingFeatures, ...
    trainingOptions.predictionMiniBatchSize);
validationPredictions = predictRegressionTargets( ...
    network, ...
    validationFeatures, ...
    trainingOptions.predictionMiniBatchSize);

minimumTrainingTarget = min(trainingTargets);
maximumTrainingTarget = max(trainingTargets);
trainingPredictions = min(max(trainingPredictions, minimumTrainingTarget), maximumTrainingTarget);
validationPredictions = min(max(validationPredictions, minimumTrainingTarget), maximumTrainingTarget);

trainingRelativeErrorPct = computeRelativeErrorPercentages(trainingPredictions, trainingTargets);
validationRelativeErrorPct = computeRelativeErrorPercentages(validationPredictions, validationTargets);

optimizerResult = struct();
optimizerResult.optimizerName = char(optimizerName);
optimizerResult.network = network;
optimizerResult.trainingRmseHistory = trainingRmseHistory;
optimizerResult.trainingRmse = computeRootMeanSquareError(trainingPredictions, trainingTargets);
optimizerResult.validationRmse = computeRootMeanSquareError(validationPredictions, validationTargets);
optimizerResult.maxTrainingRelativeErrorPct = max(trainingRelativeErrorPct);
optimizerResult.maxValidationRelativeErrorPct = max(validationRelativeErrorPct);
optimizerResult.trainingRelativeErrorPct = trainingRelativeErrorPct;
optimizerResult.validationRelativeErrorPct = validationRelativeErrorPct;
optimizerResult.trainingPredictions = trainingPredictions;
optimizerResult.validationPredictions = validationPredictions;
optimizerResult.trainingTargets = trainingTargets;
optimizerResult.validationTargets = validationTargets;
end

function [lossValue, networkGradients] = computeModelGradients(network, dlFeatures, dlTargets, l2Penalty)
dlPredictions = forward(network, dlFeatures);
predictionError = dlPredictions - dlTargets;
meanSquaredError = mean(predictionError.^2, 'all');

if l2Penalty > 0
    l2NormPenalty = dlarray(0.0);
    learnableParameters = network.Learnables;
    for parameterIndex = 1:height(learnableParameters)
        parameterName = learnableParameters.Parameter{parameterIndex};
        if strcmpi(parameterName, "Weights")
            l2NormPenalty = l2NormPenalty + sum(learnableParameters.Value{parameterIndex}.^2, 'all');
        end
    end
    lossValue = meanSquaredError + l2Penalty * l2NormPenalty;
else
    lossValue = meanSquaredError;
end

networkGradients = dlgradient(lossValue, network.Learnables);
end

function network = buildRegressionNetwork(inputFeatureCount, hiddenLayerSizes)
if isempty(hiddenLayerSizes)
    error("signalIntegrity:trainExperimentModels:MissingHiddenLayers", ...
        "At least one hidden layer size is required.");
end

hiddenLayerSizes = reshape(hiddenLayerSizes, 1, []);
layerSequence = cell(2 * numel(hiddenLayerSizes) + 2, 1);
layerSequence{1} = featureInputLayer(inputFeatureCount, Normalization="none", Name="input");

layerPosition = 2;
for hiddenLayerIndex = 1:numel(hiddenLayerSizes)
    layerSequence{layerPosition} = fullyConnectedLayer( ...
        hiddenLayerSizes(hiddenLayerIndex), ...
        Name="fullyConnected" + hiddenLayerIndex);
    layerSequence{layerPosition + 1} = tanhLayer(Name="tanh" + hiddenLayerIndex);
    layerPosition = layerPosition + 2;
end

layerSequence{end} = fullyConnectedLayer(1, Name="output");
network = dlnetwork([layerSequence{:}]);
end

function predictedTargets = predictRegressionTargets(network, featureMatrix, miniBatchSize)
sampleCount = size(featureMatrix, 1);
predictedTargets = zeros(sampleCount, 1);

for startIndex = 1:miniBatchSize:sampleCount
    endIndex = min(startIndex + miniBatchSize - 1, sampleCount);
    dlFeatures = dlarray(featureMatrix(startIndex:endIndex, :)', "CB");
    dlPredictions = forward(network, dlFeatures);
    predictionChunk = gather(extractdata(dlPredictions));
    predictedTargets(startIndex:endIndex) = predictionChunk(:);
end
end

function rmseValue = computeRootMeanSquareError(predictedTargets, referenceTargets)
rmseValue = sqrt(mean((predictedTargets - referenceTargets).^2));
end

function relativeErrorPct = computeRelativeErrorPercentages(predictedTargets, referenceTargets)
referenceMagnitude = max(abs(referenceTargets), 1e-12);
relativeErrorPct = 100 * abs(predictedTargets - referenceTargets) ./ referenceMagnitude;
end

function learningRate = resolveLearningRate(trainingOptions, optimizerName)
switch string(optimizerName)
    case "Momentum"
        learningRate = trainingOptions.momentumLearningRate;
    otherwise
        learningRate = trainingOptions.baseLearningRate;
end
end

function clippedGradient = clipGradientByL2Norm(gradient, maxNorm)
gradientNorm = sqrt(sum(gradient.^2, 'all'));
clippedGradient = gradient;
if gradientNorm > maxNorm
    clippedGradient = gradient * (maxNorm / (gradientNorm + 1e-12));
end
end

function printOptimizerMetrics(optimizerResult, units)
fprintf("    Training RMSE: %.4f %s\n", optimizerResult.trainingRmse, units);
fprintf("    Validation RMSE: %.4f %s\n", optimizerResult.validationRmse, units);
fprintf("    Max training relative error: %.2f %%\n", optimizerResult.maxTrainingRelativeErrorPct);
fprintf("    Max validation relative error: %.2f %%\n", optimizerResult.maxValidationRelativeErrorPct);
end
