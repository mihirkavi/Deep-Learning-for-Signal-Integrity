function result = compareDesigns(modelBundle, scenarioTable, baselineScenarioName, optimizationMetric)
%COMPAREDESIGNS Score scenarios and compute deltas vs baseline.
arguments
    modelBundle struct
    scenarioTable table % must include Scenario + all feature columns
    baselineScenarioName (1, 1) string
    optimizationMetric (1, 1) string = "eyeHeight" % or eyeWidth
end

cfg = getDefaultConfig();
feat = cfg.featureNames;
if ismember("Scenario", string(scenarioTable.Properties.VariableNames))
    nameCol = scenarioTable.Scenario;
else
    nameCol = scenarioTable.ScenarioName;
end

baselineMask = string(nameCol) == string(baselineScenarioName);
if ~any(baselineMask)
    error("siwb:compareDesigns:MissingBaseline", "Baseline scenario not found.");
end
baseRow = table2array(scenarioTable(baselineMask, feat));
baseOut = predictMetrics(modelBundle, baseRow);

n = height(scenarioTable);
predH = zeros(n, 1);
predW = zeros(n, 1);
passH = false(n, 1);
passW = false(n, 1);
conf = strings(n, 1);

th = getDefaultConfig().thresholds;
for k = 1:n
    row = table2array(scenarioTable(k, feat));
    out = predictMetrics(modelBundle, row);
    predH(k) = out.eyeHeight_mV;
    predW(k) = out.eyeWidth_UI;
    passH(k) = predH(k) >= th.eyeHeightPass_mV;
    passW(k) = predW(k) >= th.eyeWidthPass_UI;
    conf(k) = string(out.confidence);
end

dH = predH - baseOut.eyeHeight_mV;
dW = predW - baseOut.eyeWidth_UI;

score = predH;
if optimizationMetric == "eyeWidth"
    score = predW;
end
[~, bestIx] = max(score);

T = table(nameCol, predH, predW, dH, dW, passH & passW, conf, ...
    'VariableNames', {'Scenario', 'EyeHeight_mV', 'EyeWidth_UI', 'DeltaHeight_mV', 'DeltaWidth_UI', 'PassBoth', 'Confidence'});

result = struct('table', T, 'baseline', baseOut, 'bestRowIndex', bestIx, 'optimizationMetric', optimizationMetric);
end
