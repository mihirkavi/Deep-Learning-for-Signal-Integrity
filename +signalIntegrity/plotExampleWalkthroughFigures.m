function plotExampleWalkthroughFigures(workflowResults)
%PLOTEXAMPLEWALKTHROUGHFIGURES Integrated walkthrough: training, illustrative eyes,
%   prediction vs validation, and first-layer input sensitivity.

arguments
    workflowResults (1, 1) struct
end

if ~usejava('desktop')
    fprintf('Walkthrough figures require a desktop MATLAB session.\n');
    return
end

siWaveform = signalIntegrity.resolveSiWaveformSource(workflowResults.options);

for experimentIndex = 1:numel(workflowResults.experimentOrder)
    experimentKey = char(workflowResults.experimentOrder(experimentIndex));
    experimentResult = workflowResults.experimentResults.(experimentKey);
    spec = experimentResult.experimentSpec;
    optimizerResults = experimentResult.optimizerResults;
    best = experimentResult.bestOptimizerResult;

    fig = figure('Color', 'w', 'Name', spec.displayName + " — walkthrough");

    bestIdx = findBestOptimizerIndex(optimizerResults, best.optimizerName);
    histBest = optimizerResults{bestIdx}.trainingRmseHistory;
    nIter = numel(histBest);
    snapIdx = round(linspace(1, nIter, 3));
    subplot(3, 3, [1, 2, 3]);
    hold on;
    grid on;
    colors = lines(numel(optimizerResults));
    for optimizerIndex = 1:numel(optimizerResults)
        h = optimizerResults{optimizerIndex}.trainingRmseHistory;
        plot(h, 'LineWidth', 1.35, 'Color', colors(optimizerIndex, :), ...
            'DisplayName', signalIntegrity.getOptimizerDisplayName( ...
            optimizerResults{optimizerIndex}.optimizerName));
    end
    for snap = snapIdx
        xline(snap, ':', 'Color', [0.55 0.55 0.55], 'HandleVisibility', 'off');
    end
    hold off;
    xlabel('Training iteration');
    ylabel("Training RMSE (" + spec.units + ")");
    title('Deep learning optimizer progress (training RMSE)');
    legend('Location', 'eastoutside');

    if siWaveform.isAvailable
        subplot(3, 3, [4, 5]);
        [measurementSummary, wasRendered] = signalIntegrity.plotSiEyeDiagram( ...
            gca, siWaveform, "Signal Integrity Toolbox eye diagram");

        subplot(3, 3, 6);
        showSiMeasurementSummary(gca, measurementSummary, wasRendered);
    else
        snapRmse = histBest(snapIdx);
        mx = max(histBest, [], 'omitnan');
        mn = min(histBest, [], 'omitnan');
        denom = max(mx - mn, eps);
        openFactors = (mx - snapRmse) ./ denom;
        openFactors = max(0.08, min(1, openFactors));
        labels = {
            sprintf('Early (iter %d)', snapIdx(1))
            sprintf('Mid (iter %d)', snapIdx(2))
            sprintf('Late (iter %d)', snapIdx(3))
            };

        for eyeIndex = 1:3
            subplot(3, 3, 3 + eyeIndex);
            illustrativeEyeSchematic(gca, openFactors(eyeIndex), string(spec.key), ...
                labels{eyeIndex}, snapRmse(eyeIndex), spec.units);
        end
    end

    subplot(3, 3, [7, 8]);
    yTrue = best.validationTargets(:);
    yHat = best.validationPredictions(:);
    hold on;
    scatter(yTrue, yHat, 14, 'filled', 'MarkerFaceAlpha', 0.45);
    lim = [min([yTrue; yHat]), max([yTrue; yHat])];
    plot(lim, lim, 'k--', 'LineWidth', 1.1);
    hold off;
    grid on;
    axis equal;
    xlabel("Validation target (" + spec.units + ")");
    ylabel("Model prediction (" + spec.units + ")");
    title({
        sprintf('Prediction vs hold-out validation (%s)', char(experimentResult.bestOptimizerName))
        sprintf('Validation RMSE = %.4f %s', best.validationRmse, spec.units)
        });

    subplot(3, 3, 9);
    imp = firstHiddenLayerFeatureImportance(best.network);
    bar(imp, 'FaceColor', [0.15 0.45 0.65]);
    grid on;
    xlabel('Input feature index');
    ylabel('Weight L2 norm');
    title('Input sensitivity (first hidden layer)');

    sgtitle(fig, {
        spec.displayName + " — training, SI eye diagram, validation, inputs"
        buildFigureSubtitle(siWaveform)
        });
end

signalIntegrity.plotValidationSummary(workflowResults);
end

function idx = findBestOptimizerIndex(optimizerResults, optimizerNameChar)
idx = 1;
for k = 1:numel(optimizerResults)
    if strcmp(optimizerResults{k}.optimizerName, optimizerNameChar)
        idx = k;
        return
    end
end
end

function illustrativeEyeSchematic(ax, openingFactor, experimentKey, iterLabel, rmseValue, unitsStr)
cla(ax);
hold(ax, 'on');
axis(ax, 'equal');
openingFactor = max(0.08, min(1, openingFactor));

railY = 0.55;
plot(ax, [-1.1 1.1], [railY railY], 'k-', 'LineWidth', 2);
plot(ax, [-1.1 1.1], [-railY -railY], 'k-', 'LineWidth', 2);

if experimentKey == "eyeHeight"
    w = 0.32;
    h = 0.1 + 0.65 * openingFactor;
elseif experimentKey == "eyeWidth"
    w = 0.1 + 0.65 * openingFactor;
    h = 0.34;
else
    w = 0.15 + 0.45 * openingFactor;
    h = 0.15 + 0.45 * openingFactor;
end

fill(ax, w * [1 0 -1 0 1], h * [0 1 0 -1 0], [0.75 0.88 1.0], 'EdgeColor', [0.1 0.1 0.3], 'LineWidth', 1.2);
plot(ax, [0 0], [-railY railY], 'Color', [0.6 0.6 0.6], 'LineStyle', ':', 'LineWidth', 1);
hold(ax, 'off');
axis(ax, [-1.1 1.1 -0.75 0.75]);
set(ax, 'XTick', [], 'YTick', []);
box(ax, 'off');
title(ax, {iterLabel, sprintf('RMSE %.4g %s', rmseValue, unitsStr)}, 'FontSize', 9);
end

function showSiMeasurementSummary(ax, measurementSummary, wasRendered)
axis(ax, [0 1 0 1]);
set(ax, 'XTick', [], 'YTick', []);
box(ax, 'on');

summaryLines = strings(0, 1);
summaryLines(end + 1) = "Waveform source";
summaryLines(end + 1) = measurementSummary.sourceDescription;

if isfinite(measurementSummary.eyeHeight)
    summaryLines(end + 1) = sprintf('Measured eyeHeight = %.4g', measurementSummary.eyeHeight);
end
if isfinite(measurementSummary.eyeWidth)
    summaryLines(end + 1) = sprintf('Measured eyeWidth = %.4g s', measurementSummary.eyeWidth);
end
if ~wasRendered
    summaryLines(end + 1) = "Native eye plot was unavailable, see note below.";
end
if strlength(measurementSummary.note) > 0
    summaryLines(end + 1) = measurementSummary.note;
end

text(ax, 0.5, 0.5, summaryLines, ...
    'HorizontalAlignment', 'center', ...
    'Interpreter', 'none');
title(ax, 'Toolbox measurement summary');
end

function v = firstHiddenLayerFeatureImportance(net)
learn = net.Learnables;
idx = find(strcmp(learn.Parameter, "Weights"), 1);
if isempty(idx)
    v = 0;
    return
end
W = learn.Value{idx};
v = vecnorm(W, 2, 2);
end

function subtitleText = buildFigureSubtitle(siWaveform)
if siWaveform.isAvailable
    subtitleText = "Middle row uses native Signal Integrity Toolbox eye plotting and measurements.";
else
    subtitleText = "No SI waveform was available, so the middle row falls back to schematic eyes.";
end
end
