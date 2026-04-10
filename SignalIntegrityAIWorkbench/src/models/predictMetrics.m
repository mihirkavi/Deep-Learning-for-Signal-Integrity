function out = predictMetrics(modelBundle, featureRowRaw)
%PREDICTMETRICS Predict eye height and width from raw 1x9 feature vector.
arguments
    modelBundle struct
    featureRowRaw (1, :) double
end

cfg = getDefaultConfig();
if numel(featureRowRaw) ~= numel(cfg.featureNames)
    error("siwb:predictMetrics:BadSize", "Expected %d features.", numel(cfg.featureNames));
end

muH = modelBundle.eyeHeight.normStats.mu;
sigH = modelBundle.eyeHeight.normStats.sigma;
xh = applyStandardization(featureRowRaw, muH, sigH);

muW = modelBundle.eyeWidth.normStats.mu;
sigW = modelBundle.eyeWidth.normStats.sigma;
xw = applyStandardization(featureRowRaw, muW, sigW);

eyeHeight_mV = predictSingleTarget(modelBundle.eyeHeight, xh);
eyeWidth_UI = predictSingleTarget(modelBundle.eyeWidth, xw);

exH = detectExtrapolation(featureRowRaw, modelBundle.eyeHeight.trainingBounds);
exW = detectExtrapolation(featureRowRaw, modelBundle.eyeWidth.trainingBounds);

if exH.class == "Extrapolated" || exW.class == "Extrapolated"
    conf = "Extrapolated";
    confDisplay = "Extrapolated — verify with full link simulation";
elseif exH.class == "NearBoundary" || exW.class == "NearBoundary"
    conf = "NearBoundary";
    confDisplay = "Near training envelope";
else
    conf = "InRange";
    confDisplay = "High confidence (in-sample envelope)";
end

out = struct( ...
    'eyeHeight_mV', eyeHeight_mV, ...
    'eyeWidth_UI', eyeWidth_UI, ...
    'confidence', conf, ...
    'confidenceDisplay', confDisplay, ...
    'extrapolationEyeHeight', exH, ...
    'extrapolationEyeWidth', exW);
end
