%% Create Signal Integrity Data Template
% Run this script to regenerate the placeholder MAT-file used by the
% project. The saved experiment blocks use the canonical field names:
%   trainingFeatures, trainingTargets, validationFeatures, validationTargets
%
% The workflow still accepts the older field names `XTrain`, `yTrain`,
% `XVal`, and `yVal`, but new data files should use the clearer names
% generated here.

outputDataFile = "signalIntegrityExampleData.mat";

eyeHeight = createEmptyExperimentDataBlock(717, 476, 14);
eyeWidth = createEmptyExperimentDataBlock(509, 203, 12);

save(outputDataFile, 'eyeHeight', 'eyeWidth');
fprintf("Created %s.\n", outputDataFile);
fprintf("Populate the zero-filled targets with real data to enable reference-data mode.\n");

function experimentDataBlock = createEmptyExperimentDataBlock( ...
        trainingSampleCount, ...
        validationSampleCount, ...
        featureCount)

experimentDataBlock = struct();
experimentDataBlock.trainingFeatures = zeros(trainingSampleCount, featureCount);
experimentDataBlock.trainingTargets = zeros(trainingSampleCount, 1);
experimentDataBlock.validationFeatures = zeros(validationSampleCount, featureCount);
experimentDataBlock.validationTargets = zeros(validationSampleCount, 1);
end
