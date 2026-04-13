function siWaveform = resolveSiWaveformSource(workflowOptions)
%RESOLVESIWAVEFORMSOURCE Resolve an eye-diagram waveform for SI Toolbox plots.
%   SIWAVEFORM = signalIntegrity.resolveSiWaveformSource(WORKFLOWOPTIONS)
%   returns a struct with fields:
%     isAvailable, samples, sampleInterval, symbolTime, modulation,
%     sourceDescription, note.

arguments
    workflowOptions (1,1) struct
end

siWaveform = makeUnavailableWaveform("Signal Integrity Toolbox waveform source not resolved.");

if ~signalIntegrity.isSignalIntegrityToolboxAvailable()
    siWaveform.note = "Signal Integrity Toolbox is not installed.";
    return;
end

waveformSource = string(workflowOptions.siWaveformSource);
if waveformSource == "none"
    siWaveform.note = "Signal Integrity Toolbox eye diagram disabled by workflow option.";
    return;
end

if waveformSource == "auto" || waveformSource == "user"
    [userWaveform, userWasResolved] = tryResolveUserWaveform(workflowOptions);
    if userWasResolved
        siWaveform = userWaveform;
        return;
    end

    if waveformSource == "user"
        siWaveform.note = userWaveform.note;
        return;
    end
end

if waveformSource == "auto" || waveformSource == "demo"
    siWaveform = buildDemoWaveform(workflowOptions);
end
end

function [siWaveform, wasResolved] = tryResolveUserWaveform(workflowOptions)
siWaveform = makeUnavailableWaveform("No user waveform file was provided.");
wasResolved = false;

waveformFile = string(workflowOptions.siWaveformMatFile);
if strlength(waveformFile) == 0
    return;
end

if ~isfile(waveformFile)
    siWaveform.note = "Waveform file not found: " + waveformFile;
    return;
end

[~, ~, extension] = fileparts(char(waveformFile));
switch lower(extension)
    case ".mat"
        siWaveform = loadWaveformFromMat(workflowOptions, waveformFile);
    case ".csv"
        siWaveform = loadWaveformFromCsv(workflowOptions, waveformFile);
    otherwise
        siWaveform.note = "Unsupported waveform file type: " + string(extension);
        return;
end

wasResolved = siWaveform.isAvailable;
end

function siWaveform = loadWaveformFromMat(workflowOptions, waveformFile)
loadedData = load(waveformFile);

samples = findWaveformVector(loadedData, workflowOptions.siWaveformVariable, ...
    ["samples", "waveform", "signal", "rxWaveform", "waveformSamples"]);
if isempty(samples)
    siWaveform = makeUnavailableWaveform("No waveform vector was found in " + waveformFile + ".");
    return;
end

timeVector = findWaveformVector(loadedData, workflowOptions.siWaveformTimeVariable, ...
    ["time", "timeVector", "t"]);
sampleInterval = [];
if ~isempty(timeVector)
    sampleInterval = median(diff(double(timeVector(:))));
end

if isempty(sampleInterval)
    sampleInterval = findScalarMetadata(loadedData, ...
        ["sampleInterval", "dt", "Ts"], workflowOptions.siWaveformSampleInterval);
end

symbolTime = findScalarMetadata(loadedData, ...
    ["symbolTime", "ui", "unitInterval"], workflowOptions.siWaveformSymbolTime);

siWaveform = finalizeWaveformStruct( ...
    samples, sampleInterval, symbolTime, workflowOptions, ...
    "user waveform file: " + string(getFileName(waveformFile)));
end

function siWaveform = loadWaveformFromCsv(workflowOptions, waveformFile)
csvData = readmatrix(waveformFile);
if isempty(csvData) || ~isnumeric(csvData)
    siWaveform = makeUnavailableWaveform("CSV waveform file is empty or nonnumeric.");
    return;
end

if size(csvData, 2) >= 2
    timeVector = csvData(:, 1);
    samples = csvData(:, 2);
    sampleInterval = median(diff(timeVector));
else
    samples = csvData(:, 1);
    sampleInterval = workflowOptions.siWaveformSampleInterval;
end

symbolTime = workflowOptions.siWaveformSymbolTime;
siWaveform = finalizeWaveformStruct( ...
    samples, sampleInterval, symbolTime, workflowOptions, ...
    "user waveform CSV: " + string(getFileName(waveformFile)));
end

function siWaveform = finalizeWaveformStruct(samples, sampleInterval, symbolTime, workflowOptions, sourceDescription)
samples = double(samples(:));
samples = samples(isfinite(samples));

if numel(samples) < 32
    siWaveform = makeUnavailableWaveform("Waveform must contain at least 32 finite samples.");
    return;
end

if isempty(sampleInterval)
    siWaveform = makeUnavailableWaveform("Waveform sample interval is missing.");
    return;
end

if isempty(symbolTime)
    symbolTime = double(sampleInterval) * double(workflowOptions.siWaveformSamplesPerSymbol);
end

if symbolTime <= sampleInterval
    siWaveform = makeUnavailableWaveform("Waveform symbol time must exceed sample interval.");
    return;
end

siWaveform = struct( ...
    'isAvailable', true, ...
    'samples', samples, ...
    'sampleInterval', double(sampleInterval), ...
    'symbolTime', double(symbolTime), ...
    'modulation', 2, ...
    'sourceDescription', string(sourceDescription), ...
    'note', "");
end

function siWaveform = buildDemoWaveform(workflowOptions)
originalRandomState = rng;
cleanupObject = onCleanup(@() rng(originalRandomState));
rng(2718, "twister");

samplesPerSymbol = double(workflowOptions.siWaveformSamplesPerSymbol);
symbolTime = workflowOptions.siWaveformSymbolTime;
if isempty(symbolTime)
    symbolTime = 100e-12;
end

sampleInterval = workflowOptions.siWaveformSampleInterval;
if isempty(sampleInterval)
    sampleInterval = symbolTime / samplesPerSymbol;
else
    symbolTime = sampleInterval * samplesPerSymbol;
end

symbolCount = 2500;
symbols = 2 * randi([0 1], symbolCount, 1) - 1;
upsampled = repelem(symbols, samplesPerSymbol);
channelImpulse = exp(-(0:(4 * samplesPerSymbol))' / (0.75 * samplesPerSymbol));
channelImpulse = channelImpulse / sum(channelImpulse);
samples = conv(upsampled, channelImpulse, 'same');
samples = samples + 0.015 * randn(size(samples));

siWaveform = finalizeWaveformStruct( ...
    samples, sampleInterval, symbolTime, workflowOptions, ...
    "deterministic demo waveform for eyeDiagramSI");
siWaveform.note = "Using a deterministic built-in waveform so the walkthrough can render a native SI eye without requiring external exports.";

clear cleanupObject
end

function values = findWaveformVector(rawStruct, explicitFieldName, candidateFieldNames)
values = [];

if strlength(string(explicitFieldName)) > 0
    fieldName = char(explicitFieldName);
    if isfield(rawStruct, fieldName)
        candidateValue = rawStruct.(fieldName);
        if isnumeric(candidateValue) && isvector(candidateValue)
            values = candidateValue;
        end
    end
    return;
end

for fieldIndex = 1:numel(candidateFieldNames)
    fieldName = char(candidateFieldNames(fieldIndex));
    if isfield(rawStruct, fieldName)
        candidateValue = rawStruct.(fieldName);
        if isnumeric(candidateValue) && isvector(candidateValue)
            values = candidateValue;
            return;
        end
    end
end

rawFieldNames = fieldnames(rawStruct);
for fieldIndex = 1:numel(rawFieldNames)
    candidateValue = rawStruct.(rawFieldNames{fieldIndex});
    if isnumeric(candidateValue) && isvector(candidateValue) && numel(candidateValue) > 32
        values = candidateValue;
        return;
    end
end
end

function value = findScalarMetadata(rawStruct, candidateFieldNames, overrideValue)
value = overrideValue;
if ~isempty(value)
    return;
end

for fieldIndex = 1:numel(candidateFieldNames)
    fieldName = char(candidateFieldNames(fieldIndex));
    if isfield(rawStruct, fieldName)
        candidateValue = rawStruct.(fieldName);
        if isnumeric(candidateValue) && isscalar(candidateValue) && isfinite(candidateValue)
            value = double(candidateValue);
            return;
        end
    end
end

value = [];
end

function waveform = makeUnavailableWaveform(note)
waveform = struct( ...
    'isAvailable', false, ...
    'samples', [], ...
    'sampleInterval', [], ...
    'symbolTime', [], ...
    'modulation', 2, ...
    'sourceDescription', "", ...
    'note', string(note));
end

function fileName = getFileName(filePath)
[~, baseName, extension] = fileparts(char(filePath));
fileName = string([baseName extension]);
end
