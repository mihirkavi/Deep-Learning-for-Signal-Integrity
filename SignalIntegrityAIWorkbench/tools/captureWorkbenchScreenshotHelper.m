function captureWorkbenchScreenshotHelper(outputPngPath)
%CAPTUREWORKBENCHSCREENSHOTHELPER Save current figure or create a placeholder note.
%
%   For investor decks, run the app and use MATLAB's exportgraphics on a uiaxes,
%   or use your OS screenshot tool on the uifigure window.

arguments
    outputPngPath (1, :) char = fullfile(pwd, 'si_workbench_preview.png')
end

f = figure('Visible', 'off', 'Color', [0.1 0.11 0.12]);
ax = axes(f);
text(ax, 0.5, 0.5, 'Signal Integrity AI Workbench', 'HorizontalAlignment', 'center', ...
    'Color', [0.9 0.92 0.95], 'FontSize', 16);
ax.Color = [0.1 0.11 0.12];
axis(ax, 'off');
exportgraphics(ax, outputPngPath, 'Resolution', 150);
close(f);
fprintf("Wrote placeholder image to %s\n", outputPngPath);
end
