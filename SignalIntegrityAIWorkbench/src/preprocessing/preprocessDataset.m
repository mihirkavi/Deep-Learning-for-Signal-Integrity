function [XTrain, yTrain, XVal, yVal, normStats] = preprocessDataset(dataTable, targetName, trainValSplit, randomSeed)
%PREPROCESSDATASET Split and extract features/target; standardize using training stats only.
arguments
    dataTable table
    targetName (1, 1) string
    trainValSplit (1, 1) double {mustBeInRange(trainValSplit, 0, 1)} = 0.15
    randomSeed (1, 1) double = 42
end

cfg = getDefaultConfig();
featNames = cfg.featureNames;
subX = dataTable(:, featNames);
X = table2array(subX);
y = dataTable{:, char(targetName)};

n = size(X, 1);
if n < 20
    error("siwb:preprocessDataset:TooFewRows", "Need at least 20 rows (got %d).", n);
end

rng(randomSeed, "twister");
order = randperm(n);
nVal = max(1, round(trainValSplit * n));
nTrain = n - nVal;

trainIdx = order(1:nTrain);
valIdx = order(nTrain+1:end);

XTrain = X(trainIdx, :);
yTrain = y(trainIdx);
XVal = X(valIdx, :);
yVal = y(valIdx);

[XTrain, mu, sigma] = standardizeFeatures(XTrain);
XVal = applyStandardization(XVal, mu, sigma);

normStats = struct('mu', mu, 'sigma', sigma, 'featureNames', {featNames});
end
