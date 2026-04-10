function results = signal_integrity_modeling_core(cfg)
%SIGNAL_INTEGRITY_MODELING_CORE Run the published signal integrity workflow.
%   RESULTS = SIGNAL_INTEGRITY_MODELING_CORE(CFG) trains the eye-height and
%   eye-width models from the cited reference workflow, compares three
%   training methods, and returns the key tables and diagnostics.

if nargin < 1
    cfg = struct();
end

cfg = applyDefaultConfig(cfg);

rng(46433, "twister");

experiments = definePaperExperiments();
data = loadOrCreateData(cfg, experiments);

results = struct();
results.config = cfg;
results.experiments = struct();

for e = 1:numel(experiments)
    expCfg = experiments(e);
    expData = data.(char(expCfg.id));

    if cfg.verbose
        fprintf("\n=== %s ===\n", expCfg.displayName);
        fprintf("Data source: %s\n", expData.meta.source);
        fprintf("Hidden layer sizes: [%s]\n", num2str(expCfg.hiddenSizes));
        fprintf("Train/validation samples: %d / %d\n", size(expData.XTrain, 1), size(expData.XVal, 1));
    end

    [XTrain, XVal, normStats] = standardizeByTrain(expData.XTrain, expData.XVal);
    yTrain = expData.yTrain;
    yVal = expData.yVal;

    optimizerResults = cell(1, numel(cfg.optimizers));
    for o = 1:numel(cfg.optimizers)
        optName = cfg.optimizers(o);

        trainCfg = cfg;
        trainCfg.batchSize = expCfg.batchSize;

        if cfg.verbose
            fprintf("  Training method: %s\n", displayNameForTrainingMethod(optName));
        end

        optimizerResults{o} = trainAndEvaluate( ...
            XTrain, yTrain, XVal, yVal, expCfg.hiddenSizes, trainCfg, optName);

        if cfg.verbose
            fprintf("    Training root-mean-square error: %.4f %s\n", optimizerResults{o}.rmseTrain, expCfg.units);
            fprintf("    Validation root-mean-square error: %.4f %s\n", optimizerResults{o}.rmseVal, expCfg.units);
            fprintf("    Maximum training relative error: %.2f %%\n", optimizerResults{o}.maxRelErrTrainPct);
            fprintf("    Maximum validation relative error: %.2f %%\n", optimizerResults{o}.maxRelErrValPct);
        end
    end

    resultsTable = buildResultsTable(optimizerResults);
    referenceTable = buildPaperReferenceTable(expCfg, cfg.optimizers);

    [~, bestIdx] = min(resultsTable.ValidationRootMeanSquareError);
    bestResult = optimizerResults{bestIdx};

    if cfg.makePlots
        makeExperimentPlots(optimizerResults, bestResult, expCfg, cfg);
    end

    expId = char(expCfg.id);
    results.experiments.(expId) = struct( ...
        'config', expCfg, ...
        'dataSource', expData.meta.source, ...
        'optimizerResults', {optimizerResults}, ...
        'resultsTable', resultsTable, ...
        'referenceTable', referenceTable, ...
        'bestTrainingMethod', displayNameForTrainingMethod(bestResult.optimizer), ...
        'bestResult', bestResult, ...
        'normStats', normStats);

    if cfg.verbose
        fprintf("  Best training method on validation data: %s\n", displayNameForTrainingMethod(bestResult.optimizer));
        disp(resultsTable);
    end
end

results.summaryTable = buildSummaryTable(results.experiments, experiments);
results.experimentOrder = string({experiments.id});

if cfg.verbose
    fprintf("\n=== Summary ===\n");
    disp(results.summaryTable);
end
end

function cfg = applyDefaultConfig(cfg)
if ~isfield(cfg, "dataFile")
    cfg.dataFile = "signal_integrity_example_data.mat";
end

if ~isfield(cfg, "dataMode") || strlength(string(cfg.dataMode)) == 0
    if fileHasUsablePaperData(cfg.dataFile)
        cfg.dataMode = "real";
    else
        cfg.dataMode = "synthetic";
    end
end

cfg.dataMode = validatestring(char(string(cfg.dataMode)), {'real', 'synthetic'});
cfg.dataMode = string(cfg.dataMode);

if ~isfield(cfg, "learningRate")
    cfg.learningRate = 0.01;
end

if ~isfield(cfg, "learningRateMomentum")
    if cfg.dataMode == "real"
        cfg.learningRateMomentum = 0.01;
    else
        cfg.learningRateMomentum = 0.003;
    end
end

if ~isfield(cfg, "maxIterations")
    cfg.maxIterations = 4000;
end

if ~isfield(cfg, "optimizers")
    cfg.optimizers = ["SGD", "Momentum", "RMSProp"];
end

if ~isfield(cfg, "momentum")
    cfg.momentum = 0.90;
end

if ~isfield(cfg, "rmsDecay")
    cfg.rmsDecay = 0.90;
end

if ~isfield(cfg, "rmsEpsilon")
    cfg.rmsEpsilon = 1e-8;
end

if ~isfield(cfg, "l2Lambda")
    cfg.l2Lambda = 0;
end

if ~isfield(cfg, "gradClipNorm")
    cfg.gradClipNorm = 5.0;
end

if ~isfield(cfg, "rmseEvalStride")
    cfg.rmseEvalStride = 20;
end

if ~isfield(cfg, "predictionMiniBatch")
    cfg.predictionMiniBatch = 256;
end

if ~isfield(cfg, "saveFigures")
    cfg.saveFigures = false;
end

if ~isfield(cfg, "outputDir")
    cfg.outputDir = "results_46433";
end

if ~isfield(cfg, "makePlots")
    cfg.makePlots = usejava("desktop");
end

if ~isfield(cfg, "verbose")
    cfg.verbose = true;
end

quickEnv = lower(string(getenv("SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE")));
if strlength(quickEnv) == 0
    quickEnv = lower(string(getenv("SI_DNN_QUICK_MODE")));
end
envQuickMode = any(quickEnv == ["1", "true", "yes", "on"]);

if ~isfield(cfg, "quickMode")
    cfg.quickMode = envQuickMode;
end

if ~isfield(cfg, "quickIterations")
    cfg.quickIterations = 300;
end

if cfg.quickMode
    cfg.maxIterations = cfg.quickIterations;
end
end

function experiments = definePaperExperiments()
experiments = struct([]);

experiments(1).id = "eyeHeight";
experiments(1).displayName = "Eye Height";
experiments(1).units = "mV";
experiments(1).hiddenSizes = [100 300 200];
experiments(1).batchSize = 25;
experiments(1).trainCount = 717;
experiments(1).valCount = 476;
experiments(1).featureCount = 14;
experiments(1).targetRange = [148 253];
experiments(1).paperRMSETrain = [3.1 1.9 2.6];
experiments(1).paperRMSEVal = [3.4 2.7 3.1];
experiments(1).paperMaxRelTrain = [6.2 4.1 5.2];
experiments(1).paperMaxRelVal = [5.9 6.1 6.3];

experiments(2).id = "eyeWidth";
experiments(2).displayName = "Eye Width";
experiments(2).units = "UI";
experiments(2).hiddenSizes = [10 20 20 30 20 20 10];
experiments(2).batchSize = 15;
experiments(2).trainCount = 509;
experiments(2).valCount = 203;
experiments(2).featureCount = 12;
experiments(2).targetRange = [0.21 0.37];
experiments(2).paperRMSETrain = [0.006 0.006 0.008];
experiments(2).paperRMSEVal = [0.008 0.008 0.010];
experiments(2).paperMaxRelTrain = [7.9 8.1 8.7];
experiments(2).paperMaxRelVal = [10.6 9.3 9.5];
end

function data = loadOrCreateData(cfg, experiments)
if cfg.dataMode == "real"
    if ~isfile(cfg.dataFile)
        error("Data file '%s' not found.", cfg.dataFile);
    end

    s = load(cfg.dataFile);
    if ~loadedDataIsUsable(s)
        error(["Data file '%s' matches the zero-filled template. " ...
            "Populate it with real simulation data or use synthetic mode."], cfg.dataFile);
    end
    requiredTopFields = ["eyeHeight", "eyeWidth"];
    for k = 1:numel(requiredTopFields)
        f = requiredTopFields(k);
        if ~isfield(s, f)
            error("Missing field '%s' in %s.", f, cfg.dataFile);
        end
        requiredFields = ["XTrain", "yTrain", "XVal", "yVal"];
        for r = 1:numel(requiredFields)
            rf = requiredFields(r);
            if ~isfield(s.(f), rf)
                error("Missing field '%s.%s' in %s.", f, rf, cfg.dataFile);
            end
        end
    end

    data.eyeHeight = validateNumericDataBlock(s.eyeHeight, "eyeHeight");
    data.eyeWidth = validateNumericDataBlock(s.eyeWidth, "eyeWidth");
    data.eyeHeight.meta = struct('source', "reference data file");
    data.eyeWidth.meta = struct('source', "reference data file");
    return;
end

if cfg.verbose
    fprintf("Using deterministic synthetic fallback dataset.\n");
end

for e = 1:numel(experiments)
    expCfg = experiments(e);
    switch expCfg.id
        case "eyeHeight"
            block = generateSyntheticEyeHeight(expCfg);
        case "eyeWidth"
            block = generateSyntheticEyeWidth(expCfg);
        otherwise
            error("Unknown experiment id: %s", expCfg.id);
    end
    block.meta = struct('source', "deterministic synthetic fallback");
    data.(char(expCfg.id)) = block;
end
end

function block = generateSyntheticEyeHeight(expCfg)
Ntr = expCfg.trainCount;
Nva = expCfg.valCount;
D = expCfg.featureCount;

Xtr = randn(Ntr, D);
Xva = randn(Nva, D);

teacher = makeTeacherParams(D, [32 24 16], 46433);
ftr = evalTeacherMap(Xtr, teacher);
fva = evalTeacherMap(Xva, teacher);

allf = [ftr; fva];
scaled = rescale(allf, expCfg.targetRange(1), expCfg.targetRange(2));
yAll = scaled + 2.8 * randn(size(scaled));

ytr = yAll(1:Ntr);
yva = yAll(Ntr+1:end);

ytr = min(max(ytr, expCfg.targetRange(1)), expCfg.targetRange(2));
yva = min(max(yva, expCfg.targetRange(1)), expCfg.targetRange(2));

block = struct('XTrain', Xtr, 'yTrain', ytr, 'XVal', Xva, 'yVal', yva);
end

function block = generateSyntheticEyeWidth(expCfg)
Ntr = expCfg.trainCount;
Nva = expCfg.valCount;
D = expCfg.featureCount;

Xtr = randn(Ntr, D);
Xva = randn(Nva, D);

teacher = makeTeacherParams(D, [24 16], 46434);
ftr = evalTeacherMap(Xtr, teacher);
fva = evalTeacherMap(Xva, teacher);

allf = [ftr; fva];
scaled = rescale(allf, expCfg.targetRange(1), expCfg.targetRange(2));
yAll = scaled + 0.0045 * randn(size(scaled));

ytr = yAll(1:Ntr);
yva = yAll(Ntr+1:end);

ytr = min(max(ytr, expCfg.targetRange(1)), expCfg.targetRange(2));
yva = min(max(yva, expCfg.targetRange(1)), expCfg.targetRange(2));

block = struct('XTrain', Xtr, 'yTrain', ytr, 'XVal', Xva, 'yVal', yva);
end

function teacher = makeTeacherParams(inputDim, hiddenSizes, seed)
state = rng;
rng(seed, "twister");

layerSizes = [inputDim, hiddenSizes, 1];
teacher.W = cell(numel(layerSizes)-1, 1);
teacher.b = cell(numel(layerSizes)-1, 1);

for i = 1:(numel(layerSizes)-1)
    fanIn = layerSizes(i);
    fanOut = layerSizes(i+1);
    teacher.W{i} = (0.25 / sqrt(fanIn)) * randn(fanIn, fanOut);
    teacher.b{i} = 0.02 * randn(1, fanOut);
end

rng(state);
end

function y = evalTeacherMap(X, teacher)
A = X;
numLayers = numel(teacher.W);

for i = 1:(numLayers-1)
    A = tanh(A * teacher.W{i} + teacher.b{i});
end

y = A * teacher.W{end} + teacher.b{end};
end

function block = validateNumericDataBlock(block, blockName)
fields = ["XTrain", "yTrain", "XVal", "yVal"];
for i = 1:numel(fields)
    fn = fields(i);
    v = block.(fn);
    if ~isnumeric(v) || isempty(v)
        error("%s.%s must be a non-empty numeric array.", blockName, fn);
    end
end

if size(block.yTrain, 2) ~= 1
    block.yTrain = block.yTrain(:);
end
if size(block.yVal, 2) ~= 1
    block.yVal = block.yVal(:);
end

if size(block.XTrain, 1) ~= numel(block.yTrain)
    error("Row mismatch in %s train set.", blockName);
end
if size(block.XVal, 1) ~= numel(block.yVal)
    error("Row mismatch in %s validation set.", blockName);
end
end

function tf = fileHasUsablePaperData(dataFile)
if ~isfile(dataFile)
    tf = false;
    return;
end

try
    s = load(dataFile);
    tf = loadedDataIsUsable(s);
catch
    tf = false;
end
end

function tf = loadedDataIsUsable(s)
requiredTopFields = ["eyeHeight", "eyeWidth"];
requiredFields = ["XTrain", "yTrain", "XVal", "yVal"];

for k = 1:numel(requiredTopFields)
    topField = requiredTopFields(k);
    if ~isfield(s, topField)
        tf = false;
        return;
    end

    for r = 1:numel(requiredFields)
        fieldName = requiredFields(r);
        if ~isfield(s.(topField), fieldName)
            tf = false;
            return;
        end

        value = s.(topField).(fieldName);
        if ~isnumeric(value) || isempty(value)
            tf = false;
            return;
        end
    end
end

tf = hasVariation(s.eyeHeight.yTrain) && hasVariation(s.eyeHeight.yVal) && ...
    hasVariation(s.eyeWidth.yTrain) && hasVariation(s.eyeWidth.yVal);
end

function tf = hasVariation(x)
x = x(:);
tf = any(abs(x - x(1)) > 1e-12);
end

function [XTrainZ, XValZ, stats] = standardizeByTrain(XTrain, XVal)
mu = mean(XTrain, 1);
sigma = std(XTrain, 0, 1);
sigma(sigma < 1e-12) = 1;

XTrainZ = (XTrain - mu) ./ sigma;
XValZ = (XVal - mu) ./ sigma;

stats = struct('mu', mu, 'sigma', sigma);
end

function result = trainAndEvaluate(XTrain, yTrain, XVal, yVal, hiddenSizes, cfg, optimizer)
numFeatures = size(XTrain, 2);
dlnet = buildRegressor(numFeatures, hiddenSizes);
learnRate = learningRateForOptimizer(cfg, optimizer);

vel = [];
averageSqGrad = [];
iterationRMSE = zeros(cfg.maxIterations, 1);

N = size(XTrain, 1);
currentTrainRMSE = NaN;

for iter = 1:cfg.maxIterations
    idx = randi(N, cfg.batchSize, 1);
    Xb = XTrain(idx, :);
    yb = yTrain(idx, :);

    dlX = dlarray(Xb', "CB");
    dlY = dlarray(yb', "CB");

    [loss, grads] = dlfeval(@modelGradients, dlnet, dlX, dlY, cfg.l2Lambda);

    if cfg.gradClipNorm > 0
        grads = dlupdate(@(g) clipGradientL2(g, cfg.gradClipNorm), grads);
    end

    switch optimizer
        case "SGD"
            dlnet = dlupdate(@(p, g) p - learnRate * g, dlnet, grads);
        case "Momentum"
            [dlnet, vel] = sgdmupdate(dlnet, grads, vel, learnRate, cfg.momentum);
        case "RMSProp"
            [dlnet, averageSqGrad] = rmspropupdate(dlnet, grads, averageSqGrad, ...
                learnRate, cfg.rmsDecay, cfg.rmsEpsilon);
        otherwise
            error("Unsupported optimizer: %s", optimizer);
    end

    if iter == 1 || mod(iter, cfg.rmseEvalStride) == 0 || iter == cfg.maxIterations
        predTrainNow = predictRegressor(dlnet, XTrain, cfg.predictionMiniBatch);
        currentTrainRMSE = rmse(predTrainNow, yTrain);
    end

    if isnan(currentTrainRMSE)
        currentTrainRMSE = sqrt(double(gather(extractdata(loss))));
    end

    iterationRMSE(iter) = currentTrainRMSE;
end

predTrain = predictRegressor(dlnet, XTrain, cfg.predictionMiniBatch);
predVal = predictRegressor(dlnet, XVal, cfg.predictionMiniBatch);
yMin = min(yTrain);
yMax = max(yTrain);
predTrain = min(max(predTrain, yMin), yMax);
predVal = min(max(predVal, yMin), yMax);

relTrainPct = relativeErrorPercent(predTrain, yTrain);
relValPct = relativeErrorPercent(predVal, yVal);

result = struct();
result.optimizer = char(optimizer);
result.net = dlnet;
result.rmseCurve = iterationRMSE;
result.rmseTrain = rmse(predTrain, yTrain);
result.rmseVal = rmse(predVal, yVal);
result.maxRelErrTrainPct = max(relTrainPct);
result.maxRelErrValPct = max(relValPct);
result.trainRelErrPct = relTrainPct;
result.valRelErrPct = relValPct;
result.predTrain = predTrain;
result.predVal = predVal;
end

function [loss, gradients] = modelGradients(dlnet, dlX, dlY, l2Lambda)
dlYPred = forward(dlnet, dlX);
err = dlYPred - dlY;
mseLoss = mean(err.^2, 'all');

if l2Lambda > 0
    l2Penalty = dlarray(0.0);
    L = dlnet.Learnables;
    for i = 1:height(L)
        pname = L.Parameter{i};
        if strcmpi(pname, 'Weights')
            l2Penalty = l2Penalty + sum(L.Value{i}.^2, 'all');
        end
    end
    loss = mseLoss + l2Lambda * l2Penalty;
else
    loss = mseLoss;
end

gradients = dlgradient(loss, dlnet.Learnables);
end

function dlnet = buildRegressor(numFeatures, hiddenSizes)
layers = [ ...
    featureInputLayer(numFeatures, Normalization="none", Name="in")
    fullyConnectedLayer(hiddenSizes(1), Name="fc1")
    tanhLayer(Name="tanh1")
    ];

for i = 2:numel(hiddenSizes)
    layers = [layers
        fullyConnectedLayer(hiddenSizes(i), Name="fc" + i)
        tanhLayer(Name="tanh" + i)
        ];
end

layers = [layers
    fullyConnectedLayer(1, Name="out")
    ];

dlnet = dlnetwork(layers);
end

function yPred = predictRegressor(dlnet, X, miniBatch)
N = size(X, 1);
yPred = zeros(N, 1);

for s = 1:miniBatch:N
    e = min(s + miniBatch - 1, N);
    dlX = dlarray(X(s:e, :)', "CB");
    dlY = forward(dlnet, dlX);
    yChunk = gather(extractdata(dlY));
    yPred(s:e) = yChunk(:);
end
end

function resultsTable = buildResultsTable(optimizerResults)
trainingMethod = string(cellfun(@(r) displayNameForTrainingMethod(r.optimizer), optimizerResults, 'UniformOutput', false))';
trainingRootMeanSquareError = cellfun(@(r) r.rmseTrain, optimizerResults)';
trainMaxRel = cellfun(@(r) r.maxRelErrTrainPct, optimizerResults)';
validationRootMeanSquareError = cellfun(@(r) r.rmseVal, optimizerResults)';
valMaxRel = cellfun(@(r) r.maxRelErrValPct, optimizerResults)';

resultsTable = table( ...
    trainingMethod, ...
    trainingRootMeanSquareError, ...
    trainMaxRel, ...
    validationRootMeanSquareError, ...
    valMaxRel, ...
    'VariableNames', {'TrainingMethod', 'TrainingRootMeanSquareError', ...
    'TrainingMaxRelativeErrorPct', 'ValidationRootMeanSquareError', ...
    'ValidationMaxRelativeErrorPct'});
end

function paperTable = buildPaperReferenceTable(expCfg, optimizers)
trainingMethod = strings(numel(optimizers), 1);
for i = 1:numel(optimizers)
    trainingMethod(i) = displayNameForTrainingMethod(optimizers(i));
end

paperTable = table( ...
    trainingMethod, ...
    expCfg.paperRMSETrain', ...
    expCfg.paperMaxRelTrain', ...
    expCfg.paperRMSEVal', ...
    expCfg.paperMaxRelVal', ...
    'VariableNames', {'TrainingMethod', 'ReferenceTrainingRootMeanSquareError', ...
    'ReferenceTrainingMaxRelativeErrorPct', ...
    'ReferenceValidationRootMeanSquareError', ...
    'ReferenceValidationMaxRelativeErrorPct'});
end

function summaryTable = buildSummaryTable(experimentResults, experiments)
experimentName = strings(numel(experiments), 1);
dataSource = strings(numel(experiments), 1);
bestTrainingMethod = strings(numel(experiments), 1);
bestValidationRootMeanSquareError = zeros(numel(experiments), 1);
referenceBestValidationRootMeanSquareError = zeros(numel(experiments), 1);

for i = 1:numel(experiments)
    expCfg = experiments(i);
    block = experimentResults.(char(expCfg.id));
    experimentName(i) = expCfg.displayName;
    dataSource(i) = block.dataSource;
    bestTrainingMethod(i) = block.bestTrainingMethod;
    bestValidationRootMeanSquareError(i) = min(block.resultsTable.ValidationRootMeanSquareError);
    referenceBestValidationRootMeanSquareError(i) = min(block.referenceTable.ReferenceValidationRootMeanSquareError);
end

summaryTable = table( ...
    experimentName, ...
    dataSource, ...
    bestTrainingMethod, ...
    bestValidationRootMeanSquareError, ...
    referenceBestValidationRootMeanSquareError, ...
    'VariableNames', {'Experiment', 'DataSource', 'BestTrainingMethod', ...
    'BestValidationRootMeanSquareError', 'ReferenceBestValidationRootMeanSquareError'});
end

function makeExperimentPlots(optimizerResults, bestRes, expCfg, cfg)
fig = figure('Color', 'w', 'Name', expCfg.displayName + " Metrics");
tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
hold on;
for o = 1:numel(optimizerResults)
    plot(optimizerResults{o}.rmseCurve, 'LineWidth', 1.4, ...
        'DisplayName', displayNameForTrainingMethod(optimizerResults{o}.optimizer));
end
hold off;
grid on;
xlabel('Iteration');
ylabel("Training root-mean-square error (" + expCfg.units + ")");
title(expCfg.displayName + " Convergence");
legend('Location', 'northeast');

nexttile;
plot(bestRes.valRelErrPct, '.', 'MarkerSize', 10);
grid on;
xlabel('Validation Sample');
ylabel('Relative Error (%)');
title(expCfg.displayName + " Validation Error (" + displayNameForTrainingMethod(bestRes.optimizer) + ")");

if cfg.saveFigures
    ensureFolder(cfg.outputDir);
    exportgraphics(fig, fullfile(cfg.outputDir, expCfg.id + "_summary.png"));
end
end

function val = rmse(yhat, y)
val = sqrt(mean((yhat - y).^2));
end

function relPct = relativeErrorPercent(yhat, y)
den = max(abs(y), 1e-12);
relPct = 100 * abs(yhat - y) ./ den;
end

function lr = learningRateForOptimizer(cfg, optimizer)
switch string(optimizer)
    case "Momentum"
        lr = cfg.learningRateMomentum;
    otherwise
        lr = cfg.learningRate;
end
end

function g = clipGradientL2(g, maxNorm)
gnorm = sqrt(sum(g.^2, 'all'));
if gnorm > maxNorm
    g = g * (maxNorm / (gnorm + 1e-12));
end
end

function ensureFolder(folder)
if ~isfolder(folder)
    mkdir(folder);
end
end

function name = displayNameForTrainingMethod(method)
switch string(method)
    case "SGD"
        name = "Stochastic gradient descent";
    case "Momentum"
        name = "Stochastic gradient descent with momentum";
    case "RMSProp"
        name = "Root mean square propagation";
    otherwise
        name = string(method);
end
end
