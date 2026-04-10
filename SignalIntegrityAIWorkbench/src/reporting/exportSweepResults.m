function exportSweepResults(sweepStruct, exportFolder, baseName)
%EXPORTSWEEPRESULTS Save sweep table CSV and optional plot PNG.
arguments
    sweepStruct struct
    exportFolder (1, :) char
    baseName (1, :) char = "sweep_export"
end

if ~isfolder(exportFolder)
    mkdir(exportFolder);
end

T = table(sweepStruct.pValues, sweepStruct.predictions, ...
    'VariableNames', {sweepStruct.parameterName, 'PredictedMetric'});
writetable(T, fullfile(exportFolder, [baseName, '_data.csv']));

f = figure('Visible', 'off', 'Color', [0.07 0.08 0.1]);
ax = axes(f);
plot(ax, sweepStruct.pValues, sweepStruct.predictions, 'Color', [0.35 0.65 1], 'LineWidth', 1.8);
grid(ax, 'on');
xlabel(ax, sweepStruct.parameterDisplay, 'Color', 'w');
ylabel(ax, char(sweepStruct.targetMetric), 'Color', 'w');
ax.Color = [0.07 0.08 0.1];
ax.XColor = [0.7 0.72 0.75];
ax.YColor = [0.7 0.72 0.75];
title(ax, 'Parameter sweep', 'Color', [0.9 0.92 0.95]);
saveas(f, fullfile(exportFolder, [baseName, '_plot.png']));
close(f);
end
