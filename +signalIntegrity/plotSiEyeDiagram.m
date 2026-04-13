function [measurementSummary, wasRendered] = plotSiEyeDiagram(ax, siWaveform, panelTitle)
%PLOTSIEYEDIAGRAM Render a native Signal Integrity Toolbox eye diagram.

arguments
    ax (1,1) matlab.graphics.axis.Axes
    siWaveform (1,1) struct
    panelTitle (1,1) string = "Signal Integrity Toolbox eye"
end

measurementSummary = struct( ...
    'eyeHeight', NaN, ...
    'eyeWidth', NaN, ...
    'sourceDescription', string(siWaveform.sourceDescription), ...
    'note', string(siWaveform.note));
wasRendered = false;

cla(ax);

if ~signalIntegrity.isSignalIntegrityToolboxAvailable() || ~siWaveform.isAvailable
    showUnavailableMessage(ax, panelTitle, measurementSummary.note);
    return;
end

try
    eyeObject = eyeDiagramSI( ...
        'SampleInterval', siWaveform.sampleInterval, ...
        'SymbolTime', siWaveform.symbolTime, ...
        'Modulation', siWaveform.modulation);
    step(eyeObject, siWaveform.samples);

    axes(ax);
    plot(eyeObject);
    title(ax, {char(panelTitle), char(siWaveform.sourceDescription)});

    try
        measurementSummary.eyeHeight = double(eyeHeight(eyeObject));
    catch
    end

    try
        measurementSummary.eyeWidth = double(eyeWidth(eyeObject));
    catch
    end

    measurementSummary.note = buildMeasurementNote(measurementSummary);
    wasRendered = true;
catch ME
    measurementSummary.note = "Signal Integrity Toolbox plot failed: " + string(ME.message);
    showUnavailableMessage(ax, panelTitle, measurementSummary.note);
end
end

function note = buildMeasurementNote(measurementSummary)
parts = strings(0, 1);
if isfinite(measurementSummary.eyeHeight)
    parts(end + 1) = sprintf('eyeHeight = %.4g', measurementSummary.eyeHeight);
end
if isfinite(measurementSummary.eyeWidth)
    parts(end + 1) = sprintf('eyeWidth = %.4g s', measurementSummary.eyeWidth);
end

if isempty(parts)
    note = "Native SI eye rendered; toolbox measurements were unavailable for annotation.";
else
    note = strjoin(parts, " | ");
end
end

function showUnavailableMessage(ax, panelTitle, note)
axis(ax, [0 1 0 1]);
set(ax, 'XTick', [], 'YTick', []);
box(ax, 'on');
text(ax, 0.5, 0.62, panelTitle, ...
    'HorizontalAlignment', 'center', ...
    'FontWeight', 'bold');
text(ax, 0.5, 0.42, note, ...
    'HorizontalAlignment', 'center', ...
    'Interpreter', 'none');
end
