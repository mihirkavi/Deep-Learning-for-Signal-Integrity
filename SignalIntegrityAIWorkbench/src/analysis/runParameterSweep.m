function sweep = runParameterSweep(modelBundle, sweepRequest)
%RUNPARAMETERSWEEP Vary one parameter across [pMin,pMax] and predict one metric.

arguments
    modelBundle struct
    sweepRequest struct % .paramIndex .pMin .pMax .numPoints .targetMetric ('eyeHeight'|'eyeWidth') .baselineRow (1x9)
end

cfg = getDefaultConfig();
idx = sweepRequest.paramIndex;
p = linspace(sweepRequest.pMin, sweepRequest.pMax, sweepRequest.numPoints);
rows = repmat(sweepRequest.baselineRow, sweepRequest.numPoints, 1);
rows(:, idx) = p(:);

pred = zeros(sweepRequest.numPoints, 1);
for k = 1:sweepRequest.numPoints
    out = predictMetrics(modelBundle, rows(k, :));
    if sweepRequest.targetMetric == "eyeHeight"
        pred(k) = out.eyeHeight_mV;
    else
        pred(k) = out.eyeWidth_UI;
    end
end

if sweepRequest.targetMetric == "eyeHeight"
    [bestVal, bestIx] = max(pred);
else
    [bestVal, bestIx] = max(pred);
end

sweep = struct();
sweep.parameterName = cfg.featureNames{idx};
sweep.parameterDisplay = cfg.featureDisplayNames{idx};
sweep.pValues = p(:);
sweep.predictions = pred(:);
sweep.bestIndex = bestIx;
sweep.bestParameterValue = p(bestIx);
sweep.bestMetricValue = bestVal;
sweep.targetMetric = sweepRequest.targetMetric;
sweep.rows = rows;
end
