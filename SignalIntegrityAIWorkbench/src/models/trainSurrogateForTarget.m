function trainedModel = trainSurrogateForTarget(dataTable, targetName, trainingOptions)
%TRAINSURROGATEFORTARGET Internal trainer for one regression target column.

arguments
    dataTable table
    targetName (1, 1) string
    trainingOptions struct
end

cfg = getDefaultConfig();
split = trainingOptions.trainValSplit;
if isfield(trainingOptions, 'randomSeed')
    seed = trainingOptions.randomSeed;
else
    seed = cfg.training.randomSeed;
end

[XTrain, yTrain, XVal, yVal, normStats] = preprocessDataset(dataTable, targetName, split, seed);

Xraw = table2array(dataTable(:, cfg.featureNames));
trainingBounds = struct( ...
    'minRow', min(Xraw, [], 1), ...
    'maxRow', max(Xraw, [], 1));

modelType = lower(string(trainingOptions.modelType));
if modelType == "deep"
    trainedModel = trainDeepNet(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName);
elseif modelType == "ensemble"
    trainedModel = trainEnsembleModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName);
elseif modelType == "gpr"
    trainedModel = trainGprModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName);
else % linear
    trainedModel = trainLinearModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName);
end

trainedModel.targetName = char(targetName);
trainedModel.normStats = normStats;
trainedModel.trainingBounds = trainingBounds;
trainedModel.timestamp = datetime('now');
trainedModel.trainingOptionsUsed = trainingOptions;
end

function tm = trainDeepNet(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName)
[F, ~] = size(XTrain);
hidden = trainingOptions.hiddenLayerSizes;
if isvector(hidden)
    hidden = hidden(:)';
end

layers = featureInputLayer(F, Normalization="none", Name="input");
for h = 1:numel(hidden)
    layers = [layers; fullyConnectedLayer(hidden(h), Name="fc_"+h)]; %#ok<AGROW>
    act = lower(string(trainingOptions.activation));
    if act == "tanh"
        layers = [layers; tanhLayer(Name="tanh_"+h)]; %#ok<AGROW>
    else
        layers = [layers; reluLayer(Name="relu_"+h)]; %#ok<AGROW>
    end
end
layers = [layers; fullyConnectedLayer(1, Name="out"); regressionLayer(Name="regression")];

opts = trainingOptions("adam", ...
    MaxEpochs=trainingOptions.maxEpochs, ...
    MiniBatchSize=trainingOptions.miniBatchSize, ...
    InitialLearnRate=trainingOptions.learningRate, ...
    ValidationData={XVal, yVal}, ...
    ValidationFrequency=max(1, floor(size(XTrain,1)/trainingOptions.miniBatchSize)), ...
    Shuffle="every-epoch", ...
    Plots="none", ...
    Verbose=false);

% trainNetwork expects predictors as numObs-by-numFeatures for this network layout
net = trainNetwork(XTrain, yTrain, layers, opts);

yPredTrain = predict(net, XTrain);
yPredVal = predict(net, XVal);
metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal);

tm = struct();
tm.type = "deep";
tm.net = net;
tm.metrics = metrics;
tm.normStats = normStats;
tm.trainingBounds = trainingBounds;
tm.targetName = char(targetName);
tm.timestamp = datetime('now');
tm.trainingOptionsUsed = trainingOptions;
end

function tm = trainEnsembleModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName)
t = templateTree('MinLeaf', 5);
Mdl = fitrensemble(XTrain, yTrain, Method="LSBoost", NumLearningCycles=80, Learners=t);

yPredTrain = predict(Mdl, XTrain);
yPredVal = predict(Mdl, XVal);
metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal);

tm = struct();
tm.type = "ensemble";
tm.Mdl = Mdl;
tm.metrics = metrics;
tm.normStats = normStats;
tm.trainingBounds = trainingBounds;
tm.targetName = char(targetName);
tm.timestamp = datetime('now');
tm.trainingOptionsUsed = trainingOptions;
end

function tm = trainLinearModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName)
A = [ones(size(XTrain, 1), 1), XTrain];
beta = A \ yTrain(:);
yPredTrain = A * beta;
Av = [ones(size(XVal, 1), 1), XVal];
yPredVal = Av * beta;
metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal);

tm = struct();
tm.type = "linear";
tm.beta = beta;
tm.metrics = metrics;
tm.normStats = normStats;
tm.trainingBounds = trainingBounds;
tm.targetName = char(targetName);
tm.timestamp = datetime('now');
tm.trainingOptionsUsed = trainingOptions;
end

function tm = trainGprModel(XTrain, yTrain, XVal, yVal, normStats, trainingBounds, trainingOptions, targetName)
try
    Mdl = fitrgp(XTrain, yTrain, BasisFunction="constant", ...
        KernelFunction="squaredexponential", ...
        Standardize=true, ...
        Sigma=0.1);
catch
    Mdl = fitrensemble(XTrain, yTrain, Method="LSBoost", NumLearningCycles=40);
    tm = struct();
    tm.type = "ensemble";
    tm.Mdl = Mdl;
    yPredTrain = predict(Mdl, XTrain);
    yPredVal = predict(Mdl, XVal);
    tm.metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal);
    tm.normStats = normStats;
    tm.trainingBounds = trainingBounds;
    tm.targetName = char(targetName);
    tm.timestamp = datetime('now');
    tm.trainingOptionsUsed = trainingOptions;
    return;
end

yPredTrain = predict(Mdl, XTrain);
yPredVal = predict(Mdl, XVal);
metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal);

tm = struct();
tm.type = "gpr";
tm.Mdl = Mdl;
tm.metrics = metrics;
tm.normStats = normStats;
tm.trainingBounds = trainingBounds;
tm.targetName = char(targetName);
tm.timestamp = datetime('now');
tm.trainingOptionsUsed = trainingOptions;
end
