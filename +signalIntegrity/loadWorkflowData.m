function [workflowData, resolvedDataMode] = loadWorkflowData(workflowOptions, experimentCatalog)
%LOADWORKFLOWDATA Load reference data or build the synthetic fallback data.
%   [WORKFLOWDATA, RESOLVEDDATAMODE] = signalIntegrity.loadWorkflowData(...)
%   returns normalized experiment data blocks that always use the canonical
%   field names:
%     trainingFeatures, trainingTargets, validationFeatures, validationTargets
%
%   The loader accepts both the canonical field names above and the legacy
%   names used in earlier revisions:
%     XTrain, yTrain, XVal, yVal

arguments
    workflowOptions (1,1) struct
    experimentCatalog (1,:) struct
end

resolvedDataMode = resolveDataMode(workflowOptions.dataMode, workflowOptions.dataFile, experimentCatalog);

if resolvedDataMode == "real"
    workflowData = loadReferenceData(workflowOptions.dataFile, experimentCatalog);
    return;
end

if workflowOptions.showProgress
    fprintf("Using deterministic synthetic fallback dataset.\n");
end

workflowData = struct();
for experimentIndex = 1:numel(experimentCatalog)
    experimentSpec = experimentCatalog(experimentIndex);
    experimentKey = char(experimentSpec.key);

    switch experimentSpec.key
        case "eyeHeight"
            dataBlock = createSyntheticDataBlock(experimentSpec, [32 24 16], 46433, 2.8);
        case "eyeWidth"
            dataBlock = createSyntheticDataBlock(experimentSpec, [24 16], 46434, 0.0045);
        otherwise
            error("signalIntegrity:loadWorkflowData:UnknownExperiment", ...
                "Unknown experiment key: %s", experimentSpec.key);
    end

    dataBlock.metadata = struct('source', "deterministic synthetic fallback");
    workflowData.(experimentKey) = dataBlock;
end
end

function resolvedDataMode = resolveDataMode(requestedDataMode, dataFile, experimentCatalog)
switch requestedDataMode
    case "auto"
        if fileContainsUsableReferenceData(dataFile, experimentCatalog)
            resolvedDataMode = "real";
        else
            resolvedDataMode = "synthetic";
        end
    otherwise
        resolvedDataMode = requestedDataMode;
end
end

function workflowData = loadReferenceData(dataFile, experimentCatalog)
if ~isfile(dataFile)
    error("signalIntegrity:loadWorkflowData:MissingFile", ...
        "Data file '%s' was not found.", dataFile);
end

loadedFileData = load(dataFile);
workflowData = struct();

for experimentIndex = 1:numel(experimentCatalog)
    experimentSpec = experimentCatalog(experimentIndex);
    experimentKey = char(experimentSpec.key);

    if ~isfield(loadedFileData, experimentKey)
        error("signalIntegrity:loadWorkflowData:MissingExperimentBlock", ...
            "Missing experiment block '%s' in %s.", experimentKey, dataFile);
    end

    dataBlock = normalizeDataBlock(loadedFileData.(experimentKey), experimentKey);
    if ~hasVariation(dataBlock.trainingTargets) || ~hasVariation(dataBlock.validationTargets)
        error("signalIntegrity:loadWorkflowData:TemplateData", ...
            ["Data file '%s' still contains constant placeholder targets for %s. " ...
            "Populate the MAT-file with real data or use synthetic mode."], ...
            dataFile, experimentKey);
    end

    dataBlock.metadata = mergeReferenceMetadata(loadedFileData.(experimentKey));
    workflowData.(experimentKey) = dataBlock;
end
end

function dataBlock = createSyntheticDataBlock(experimentSpec, teacherLayerSizes, randomSeed, noiseStandardDeviation)
trainingSampleCount = experimentSpec.trainingSampleCount;
validationSampleCount = experimentSpec.validationSampleCount;
featureCount = experimentSpec.featureCount;

trainingFeatures = randn(trainingSampleCount, featureCount);
validationFeatures = randn(validationSampleCount, featureCount);

teacherParameters = createTeacherParameters(featureCount, teacherLayerSizes, randomSeed);
syntheticTrainingTargets = evaluateTeacherNetwork(trainingFeatures, teacherParameters);
syntheticValidationTargets = evaluateTeacherNetwork(validationFeatures, teacherParameters);

allTargets = [syntheticTrainingTargets; syntheticValidationTargets];
rescaledTargets = rescale(allTargets, experimentSpec.targetRange(1), experimentSpec.targetRange(2));
noisyTargets = rescaledTargets + noiseStandardDeviation * randn(size(rescaledTargets));

trainingTargets = noisyTargets(1:trainingSampleCount);
validationTargets = noisyTargets(trainingSampleCount+1:end);

trainingTargets = min(max(trainingTargets, experimentSpec.targetRange(1)), experimentSpec.targetRange(2));
validationTargets = min(max(validationTargets, experimentSpec.targetRange(1)), experimentSpec.targetRange(2));

dataBlock = struct( ...
    'trainingFeatures', trainingFeatures, ...
    'trainingTargets', trainingTargets, ...
    'validationFeatures', validationFeatures, ...
    'validationTargets', validationTargets);
end

function teacherParameters = createTeacherParameters(inputFeatureCount, hiddenLayerSizes, randomSeed)
originalRandomState = rng;
cleanupObject = onCleanup(@() rng(originalRandomState));
rng(randomSeed, "twister");

layerSizes = [inputFeatureCount, hiddenLayerSizes, 1];
teacherParameters.weights = cell(numel(layerSizes)-1, 1);
teacherParameters.biases = cell(numel(layerSizes)-1, 1);

for layerIndex = 1:(numel(layerSizes)-1)
    fanIn = layerSizes(layerIndex);
    fanOut = layerSizes(layerIndex+1);
    teacherParameters.weights{layerIndex} = (0.25 / sqrt(fanIn)) * randn(fanIn, fanOut);
    teacherParameters.biases{layerIndex} = 0.02 * randn(1, fanOut);
end

clear cleanupObject
end

function targetValues = evaluateTeacherNetwork(featureMatrix, teacherParameters)
layerActivations = featureMatrix;
hiddenLayerCount = numel(teacherParameters.weights) - 1;

for layerIndex = 1:hiddenLayerCount
    layerActivations = tanh( ...
        layerActivations * teacherParameters.weights{layerIndex} + ...
        teacherParameters.biases{layerIndex});
end

targetValues = layerActivations * teacherParameters.weights{end} + teacherParameters.biases{end};
end

function normalizedDataBlock = normalizeDataBlock(rawDataBlock, experimentKey)
normalizedDataBlock = struct();
normalizedDataBlock.trainingFeatures = getRequiredField( ...
    rawDataBlock, ["trainingFeatures", "XTrain"], experimentKey, "training features");
normalizedDataBlock.trainingTargets = getRequiredField( ...
    rawDataBlock, ["trainingTargets", "yTrain"], experimentKey, "training targets");
normalizedDataBlock.validationFeatures = getRequiredField( ...
    rawDataBlock, ["validationFeatures", "XVal"], experimentKey, "validation features");
normalizedDataBlock.validationTargets = getRequiredField( ...
    rawDataBlock, ["validationTargets", "yVal"], experimentKey, "validation targets");

normalizedDataBlock.trainingTargets = normalizedDataBlock.trainingTargets(:);
normalizedDataBlock.validationTargets = normalizedDataBlock.validationTargets(:);

if size(normalizedDataBlock.trainingFeatures, 1) ~= numel(normalizedDataBlock.trainingTargets)
    error("signalIntegrity:loadWorkflowData:TrainingRowMismatch", ...
        "The training rows for %s do not match the number of training targets.", ...
        experimentKey);
end

if size(normalizedDataBlock.validationFeatures, 1) ~= numel(normalizedDataBlock.validationTargets)
    error("signalIntegrity:loadWorkflowData:ValidationRowMismatch", ...
        "The validation rows for %s do not match the number of validation targets.", ...
        experimentKey);
end

if size(normalizedDataBlock.trainingFeatures, 2) ~= size(normalizedDataBlock.validationFeatures, 2)
    error("signalIntegrity:loadWorkflowData:FeatureCountMismatch", ...
        "The training and validation feature counts for %s must match.", ...
        experimentKey);
end
end

function fieldValue = getRequiredField(rawDataBlock, candidateFieldNames, experimentKey, fieldDescription)
fieldValue = [];
fieldWasFound = false;
for fieldIndex = 1:numel(candidateFieldNames)
    candidateFieldName = candidateFieldNames(fieldIndex);
    if isfield(rawDataBlock, candidateFieldName)
        fieldValue = rawDataBlock.(candidateFieldName);
        fieldWasFound = true;
        break;
    end
end

if ~fieldWasFound
    error("signalIntegrity:loadWorkflowData:MissingField", ...
        "Missing %s in the '%s' experiment block.", fieldDescription, experimentKey);
end

if ~isnumeric(fieldValue) || isempty(fieldValue)
    error("signalIntegrity:loadWorkflowData:InvalidFieldType", ...
        "The %s for '%s' must be a non-empty numeric array.", fieldDescription, experimentKey);
end
end

function isUsable = fileContainsUsableReferenceData(dataFile, experimentCatalog)
if ~isfile(dataFile)
    isUsable = false;
    return;
end

try
    loadReferenceData(dataFile, experimentCatalog);
    isUsable = true;
catch
    isUsable = false;
end
end

function hasRealVariation = hasVariation(values)
values = values(:);
hasRealVariation = ~isempty(values) && any(abs(values - values(1)) > 1e-12);
end

function mergedMetadata = mergeReferenceMetadata(rawExperimentBlock)
mergedMetadata = struct('source', "reference data file");

if isfield(rawExperimentBlock, 'metadata') && isstruct(rawExperimentBlock.metadata)
    userFieldNames = fieldnames(rawExperimentBlock.metadata);
    for fieldIndex = 1:numel(userFieldNames)
        fieldName = userFieldNames{fieldIndex};
        mergedMetadata.(fieldName) = rawExperimentBlock.metadata.(fieldName);
    end
end

mergedMetadata.source = "reference data file";
end
