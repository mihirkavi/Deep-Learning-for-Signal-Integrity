function demoTable = createDemoDataset(numSamples, randomSeed)
%CREATEDEMODATASET Synthetic demo dataset for training and UI demos.
arguments
    numSamples (1, 1) {mustBePositive, mustBeInteger} = 400
    randomSeed (1, 1) double = 424242
end

rng(randomSeed, "twister");
cfg = getDefaultConfig();
F = numel(cfg.featureNames);

X = zeros(numSamples, F);
for j = 1:F
    lo = cfg.featureLimits(j, 1);
    hi = cfg.featureLimits(j, 2);
    X(:, j) = lo + (hi - lo) .* rand(numSamples, 1);
end

% Simple nonlinear surrogate "physics" for demo (not a real channel solver)
a = [0.4, -0.15, 0.008, 0.006, -1.2, 8.0, -120.0, 0.35, -0.12];
b = 0.02 * randn(numSamples, 1);
eyeHeight_mV = 180 + 40 * tanh(X * a(:) / 20) + 5 * b;

c = [0.02, -0.01, 0.0004, 0.0003, -0.03, 0.12, -4.0, 0.02, -0.015];
d = 0.008 * randn(numSamples, 1);
eyeWidth_UI = 0.30 + 0.06 * tanh(X * c(:)) + d;

demoTable = array2table(X, 'VariableNames', cfg.featureNames);
demoTable.eyeHeight_mV = eyeHeight_mV;
demoTable.eyeWidth_UI = eyeWidth_UI;
end
