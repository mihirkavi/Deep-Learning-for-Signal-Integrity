function buildExampleDataFromSiExport(eyeHeightSource, eyeWidthSource, options)
%BUILDEXAMPLEDATAFROMSIEXPORT Build signalIntegrityExampleData.mat from SI export tables.
%
%   signalIntegrity.buildExampleDataFromSiExport(HEIGHT_SRC, WIDTH_SRC)
%   reads predictor/target columns, performs a reproducible train/validation split
%   matching getExperimentCatalog sample counts, and saves a MAT-file for use with
%   loadWorkflowData in "real" mode.
%
%   HEIGHT_SRC and WIDTH_SRC are either MATLAB tables or paths to CSV files whose
%   columns include the default predictor names from paperFeatureReference and
%   the default target column names.
%
%   Name-value options:
%     OutputMatFile       - default "signalIntegrityExampleData.mat"
%     RandomSeed          - default 46433
%     HeightPredictorNames, WidthPredictorNames, HeightTargetColumn, WidthTargetColumn
%     SiToolboxMetadata   - optional struct merged into each experiment block's metadata
%
%   See docs/signalIntegrityToolboxDataset.md.

arguments
    eyeHeightSource
    eyeWidthSource
    options.OutputMatFile (1,1) string = "signalIntegrityExampleData.mat"
    options.RandomSeed (1,1) {mustBeNumeric, mustBeReal, mustBeFinite} = 46433
    options.HeightPredictorNames (1, 14) string = signalIntegrity.paperFeatureReference().eyeHeight.predictorColumnNames
    options.WidthPredictorNames (1, 12) string = signalIntegrity.paperFeatureReference().eyeWidth.predictorColumnNames
    options.HeightTargetColumn (1,1) string = "eyeHeight_mV"
    options.WidthTargetColumn (1,1) string = "eyeWidth_UI"
    options.SiToolboxMetadata struct = struct()
end

heightTable = loadSourceTable(eyeHeightSource);
widthTable = loadSourceTable(eyeWidthSource);

ref = signalIntegrity.paperFeatureReference();
eyeHeight = buildExperimentBlock( ...
    heightTable, ...
    options.HeightPredictorNames, ...
    options.HeightTargetColumn, ...
    ref.eyeHeight.trainingSampleCount, ...
    ref.eyeHeight.validationSampleCount, ...
    options.RandomSeed, ...
    options.SiToolboxMetadata, ...
    "eyeHeight");

eyeWidth = buildExperimentBlock( ...
    widthTable, ...
    options.WidthPredictorNames, ...
    options.WidthTargetColumn, ...
    ref.eyeWidth.trainingSampleCount, ...
    ref.eyeWidth.validationSampleCount, ...
    options.RandomSeed + 1, ...
    options.SiToolboxMetadata, ...
    "eyeWidth");

outputPath = options.OutputMatFile;
save(outputPath, 'eyeHeight', 'eyeWidth', '-v7.3');
fprintf("Wrote %s (eye height rows: %d train / %d val; eye width rows: %d train / %d val).\n", ...
    outputPath, ...
    ref.eyeHeight.trainingSampleCount, ...
    ref.eyeHeight.validationSampleCount, ...
    ref.eyeWidth.trainingSampleCount, ...
    ref.eyeWidth.validationSampleCount);
end

function experimentBlock = buildExperimentBlock( ...
        sourceTable, ...
        predictorNames, ...
        targetColumnName, ...
        trainingSampleCount, ...
        validationSampleCount, ...
        randomSeed, ...
        siToolboxMetadata, ...
        experimentKey)

requiredRows = trainingSampleCount + validationSampleCount;
validateTableColumns(sourceTable, predictorNames, targetColumnName);

predictorMatrix = table2array(sourceTable(:, cellstr(predictorNames)));
targetVector = sourceTable{:, char(targetColumnName)};

if size(predictorMatrix, 1) ~= numel(targetVector)
    error("signalIntegrity:buildExampleDataFromSiExport:RowCountMismatch", ...
        "Predictor rows and target length must match for %s.", experimentKey);
end

rowCount = size(predictorMatrix, 1);
if rowCount < requiredRows
    error("signalIntegrity:buildExampleDataFromSiExport:InsufficientRows", ...
        "Need at least %d rows for %s (train+val), found %d.", ...
        requiredRows, experimentKey, rowCount);
end

rng(randomSeed, "twister");
splitIndex = randperm(rowCount, requiredRows);

trainingIndex = splitIndex(1:trainingSampleCount);
validationIndex = splitIndex(trainingSampleCount+1:end);

experimentBlock = struct();
experimentBlock.trainingFeatures = predictorMatrix(trainingIndex, :);
experimentBlock.validationFeatures = predictorMatrix(validationIndex, :);
experimentBlock.trainingTargets = targetVector(trainingIndex);
experimentBlock.validationTargets = targetVector(validationIndex);

experimentBlock.metadata = struct( ...
    'source', "Signal Integrity Toolbox export (built by buildExampleDataFromSiExport)", ...
    'experimentKey', experimentKey, ...
    'randomSeed', randomSeed, ...
    'predictorColumnNames', {cellstr(predictorNames)}, ...
    'targetColumnName', char(targetColumnName));

if ~isempty(fieldnames(siToolboxMetadata))
    metaNames = fieldnames(siToolboxMetadata);
    for metaIndex = 1:numel(metaNames)
        name = metaNames{metaIndex};
        experimentBlock.metadata.(name) = siToolboxMetadata.(name);
    end
end
end

function validateTableColumns(sourceTable, predictorNames, targetColumnName)
if ~istable(sourceTable)
    error("signalIntegrity:buildExampleDataFromSiExport:InvalidTable", ...
        "Expected a MATLAB table loaded from CSV or supplied in memory.");
end

for predictorIndex = 1:numel(predictorNames)
    name = char(predictorNames(predictorIndex));
    if ~ismember(name, sourceTable.Properties.VariableNames)
        error("signalIntegrity:buildExampleDataFromSiExport:MissingColumn", ...
            "Missing predictor column '%s'.", name);
    end
end

if ~ismember(char(targetColumnName), sourceTable.Properties.VariableNames)
    error("signalIntegrity:buildExampleDataFromSiExport:MissingTarget", ...
        "Missing target column '%s'.", targetColumnName);
end
end

function sourceTable = loadSourceTable(source)
if istable(source)
    sourceTable = source;
    return;
end

if ~(ischar(source) || isstring(source))
    error("signalIntegrity:buildExampleDataFromSiExport:UnsupportedSource", ...
        "Source must be a table or a file path.");
end

pathString = char(source);
if ~isfile(pathString)
    error("signalIntegrity:buildExampleDataFromSiExport:MissingFile", ...
        "File not found: %s", pathString);
end

[~, ~, extension] = fileparts(pathString);
if strcmpi(extension, ".csv")
    sourceTable = readtable(pathString);
else
    fileData = load(pathString);
    variableNames = fieldnames(fileData);
    if isempty(variableNames)
        error("signalIntegrity:buildExampleDataFromSiExport:EmptyMatFile", ...
            "MAT-file %s contains no variables.", pathString);
    end
    candidate = fileData.(variableNames{1});
    if ~istable(candidate)
        error("signalIntegrity:buildExampleDataFromSiExport:MatNotTable", ...
            "First variable in %s must be a table.", pathString);
    end
    sourceTable = candidate;
end
end
