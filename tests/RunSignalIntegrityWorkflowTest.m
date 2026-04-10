classdef RunSignalIntegrityWorkflowTest < matlab.unittest.TestCase
    %RUNSIGNALINTEGRITYWORKFLOWTEST Tests for the public workflow entry point.

    methods (TestClassSetup)
        function addProjectToPath(testCase)
            projectRootFolder = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRootFolder, ...
                IncludingSubfolders=true));
        end
    end

    methods (TestMethodSetup)
        function resetRandomSeed(testCase)
            originalRandomState = rng;
            testCase.addTeardown(@() rng(originalRandomState));
        end
    end

    methods (Test, TestTags = {'Unit'})
        function testQuickSyntheticRunReturnsExpectedSummaryShape(testCase)
            workflowResults = runSignalIntegrityWorkflow(baseWorkflowOptions("synthetic"));

            testCase.verifyEqual(workflowResults.options.dataMode, "synthetic");
            testCase.verifyEqual(workflowResults.experimentOrder, ["eyeHeight", "eyeWidth"]);
            testCase.verifySize(workflowResults.summaryTable, [2 5]);
            testCase.verifyEqual(workflowResults.summaryTable.Experiment, ["Eye Height"; "Eye Width"]);
            testCase.verifyEqual(workflowResults.summaryTable.DataSource, ...
                ["deterministic synthetic fallback"; "deterministic synthetic fallback"]);
        end

        function testSyntheticQuickRunIsDeterministic(testCase)
            firstRun = runSignalIntegrityWorkflow(baseWorkflowOptions("synthetic"));
            secondRun = runSignalIntegrityWorkflow(baseWorkflowOptions("synthetic"));

            testCase.verifyEqual( ...
                firstRun.summaryTable.BestValidationRMSE, ...
                secondRun.summaryTable.BestValidationRMSE, ...
                AbsTol=1e-12);
            testCase.verifyEqual( ...
                firstRun.summaryTable.BestOptimizer, ...
                secondRun.summaryTable.BestOptimizer);
        end

        function testUsableReferenceDataFileSelectsRealMode(testCase)
            temporaryFolder = string(tempname);
            mkdir(temporaryFolder);
            testCase.addTeardown(@() rmdir(temporaryFolder, 's'));

            referenceDataFile = fullfile(temporaryFolder, "referenceData.mat");
            eyeHeight = makeCanonicalDataBlock(717, 476, 14, 150);
            eyeWidth = makeCanonicalDataBlock(509, 203, 12, 0.25);
            save(referenceDataFile, 'eyeHeight', 'eyeWidth');

            workflowOptions = baseWorkflowOptions("auto");
            workflowOptions.dataFile = referenceDataFile;

            workflowResults = runSignalIntegrityWorkflow(workflowOptions);

            testCase.verifyEqual(workflowResults.options.dataMode, "real");
            testCase.verifyEqual(workflowResults.experimentResults.eyeHeight.dataSource, "reference data file");
            testCase.verifyEqual(workflowResults.experimentResults.eyeWidth.dataSource, "reference data file");
        end

        function testLegacyDataFieldNamesRemainSupported(testCase)
            temporaryFolder = string(tempname);
            mkdir(temporaryFolder);
            testCase.addTeardown(@() rmdir(temporaryFolder, 's'));

            legacyDataFile = fullfile(temporaryFolder, "legacyReferenceData.mat");
            eyeHeight = makeLegacyDataBlock(717, 476, 14, 150);
            eyeWidth = makeLegacyDataBlock(509, 203, 12, 0.25);
            save(legacyDataFile, 'eyeHeight', 'eyeWidth');

            workflowOptions = baseWorkflowOptions("real");
            workflowOptions.dataFile = legacyDataFile;

            workflowResults = runSignalIntegrityWorkflow(workflowOptions);

            testCase.verifyEqual(workflowResults.options.dataMode, "real");
            testCase.verifyEqual(workflowResults.experimentResults.eyeHeight.dataSource, "reference data file");
        end

        function testReferenceComparisonTablePreservesCustomOptimizerOrdering(testCase)
            workflowOptions = baseWorkflowOptions("synthetic");
            workflowOptions.optimizerNames = ["RMSProp", "SGD"];

            workflowResults = runSignalIntegrityWorkflow(workflowOptions);
            referenceOptimizerComparisonTable = ...
                workflowResults.experimentResults.eyeHeight.referenceOptimizerComparisonTable;

            testCase.verifyEqual(referenceOptimizerComparisonTable.Optimizer, ...
                ["Root mean square propagation"; "Stochastic gradient descent"]);
            testCase.verifyEqual(referenceOptimizerComparisonTable.ReferenceValidationRMSE, ...
                [3.1; 3.4], AbsTol=1e-12);
        end

        function testLegacyOptionAliasesRemainAccepted(testCase)
            legacyOptions = struct();
            legacyOptions.dataMode = "synthetic";
            legacyOptions.quickMode = true;
            legacyOptions.makePlots = false;
            legacyOptions.verbose = false;
            legacyOptions.optimizers = ["Momentum", "SGD"];

            workflowResults = runSignalIntegrityWorkflow(legacyOptions);

            testCase.verifyEqual(workflowResults.options.optimizerNames, ["Momentum", "SGD"]);
            testCase.verifyFalse(workflowResults.options.showPlots);
            testCase.verifyFalse(workflowResults.options.showProgress);
        end

        function testBuildExampleDataFromSiExportProducesLoadableDataset(testCase)
            temporaryFolder = string(tempname);
            mkdir(temporaryFolder);
            testCase.addTeardown(@() rmdir(temporaryFolder, 's'));

            reference = signalIntegrity.paperFeatureReference();
            heightRowCount = reference.eyeHeight.trainingSampleCount + ...
                reference.eyeHeight.validationSampleCount + 40;
            widthRowCount = reference.eyeWidth.trainingSampleCount + ...
                reference.eyeWidth.validationSampleCount + 30;

            heightTable = buildNumericExportTable( ...
                reference.eyeHeight.predictorColumnNames, ...
                heightRowCount, ...
                reference.eyeHeight.defaultTargetColumnName, ...
                180);
            widthTable = buildNumericExportTable( ...
                reference.eyeWidth.predictorColumnNames, ...
                widthRowCount, ...
                reference.eyeWidth.defaultTargetColumnName, ...
                0.28);

            outputMatFile = fullfile(temporaryFolder, "fromSiExport.mat");
            signalIntegrity.buildExampleDataFromSiExport(heightTable, widthTable, ...
                "OutputMatFile", outputMatFile, ...
                "RandomSeed", 91919);

            workflowOptions = signalIntegrity.resolveWorkflowOptions(struct( ...
                "dataMode", "real", ...
                "dataFile", outputMatFile, ...
                "quickMode", true, ...
                "showPlots", false, ...
                "showProgress", false));
            experimentCatalog = signalIntegrity.getExperimentCatalog();
            [workflowData, resolvedDataMode] = signalIntegrity.loadWorkflowData( ...
                workflowOptions, experimentCatalog);

            testCase.verifyEqual(resolvedDataMode, "real");
            testCase.verifyEqual( ...
                size(workflowData.eyeHeight.validationFeatures, 1), ...
                reference.eyeHeight.validationSampleCount);
            testCase.verifyEqual( ...
                size(workflowData.eyeWidth.validationFeatures, 1), ...
                reference.eyeWidth.validationSampleCount);
            testCase.verifyEqual(workflowData.eyeHeight.metadata.source, "reference data file");
            testCase.verifyTrue(isfield(workflowData.eyeHeight.metadata, "experimentKey"));
        end
    end
end

function workflowOptions = baseWorkflowOptions(dataMode)
workflowOptions = struct();
workflowOptions.dataMode = dataMode;
workflowOptions.quickMode = true;
workflowOptions.showPlots = false;
workflowOptions.showProgress = false;
end

function canonicalDataBlock = makeCanonicalDataBlock( ...
        trainingSampleCount, ...
        validationSampleCount, ...
        featureCount, ...
        targetOffset)

rng(17, "twister");

canonicalDataBlock = struct();
canonicalDataBlock.trainingFeatures = randn(trainingSampleCount, featureCount);
canonicalDataBlock.validationFeatures = randn(validationSampleCount, featureCount);
canonicalDataBlock.trainingTargets = targetOffset + rand(trainingSampleCount, 1);
canonicalDataBlock.validationTargets = targetOffset + rand(validationSampleCount, 1);
end

function exportTable = buildNumericExportTable(predictorNames, rowCount, targetColumnName, targetOffset)
arguments
    predictorNames (1, :) string
    rowCount (1, 1) {mustBePositive, mustBeInteger}
    targetColumnName (1, 1) string
    targetOffset (1, 1) double
end

rng(3, "twister");
exportTable = table();
for columnIndex = 1:numel(predictorNames)
    name = char(predictorNames(columnIndex));
    exportTable.(name) = randn(rowCount, 1);
end
exportTable.(char(targetColumnName)) = targetOffset + 0.05 * randn(rowCount, 1);
end

function legacyDataBlock = makeLegacyDataBlock( ...
        trainingSampleCount, ...
        validationSampleCount, ...
        featureCount, ...
        targetOffset)

canonicalDataBlock = makeCanonicalDataBlock( ...
    trainingSampleCount, ...
    validationSampleCount, ...
    featureCount, ...
    targetOffset);

legacyDataBlock = struct();
legacyDataBlock.XTrain = canonicalDataBlock.trainingFeatures;
legacyDataBlock.yTrain = canonicalDataBlock.trainingTargets;
legacyDataBlock.XVal = canonicalDataBlock.validationFeatures;
legacyDataBlock.yVal = canonicalDataBlock.validationTargets;
end
