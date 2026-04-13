function resolvedOptions = resolveWorkflowOptions(userOptions)
%RESOLVEWORKFLOWOPTIONS Normalize workflow options and fill in defaults.
%   RESOLVEDOPTIONS = signalIntegrity.resolveWorkflowOptions() returns the
%   default options used throughout the project.
%
%   RESOLVEDOPTIONS = signalIntegrity.resolveWorkflowOptions(USEROPTIONS)
%   accepts the current option names and a small set of legacy aliases from
%   earlier versions of this repository. When both a current name and a
%   legacy alias are provided, the current name takes precedence.

arguments
    userOptions struct = struct()
end

resolvedOptions = mapLegacyOptionNames(userOptions);

if ~isfield(resolvedOptions, "dataFile")
    resolvedOptions.dataFile = "signalIntegrityExampleData.mat";
end

if ~isfield(resolvedOptions, "dataMode") || strlength(string(resolvedOptions.dataMode)) == 0
    resolvedOptions.dataMode = "auto";
end

resolvedOptions.dataMode = validatestring( ...
    char(string(resolvedOptions.dataMode)), ...
    {'auto', 'real', 'synthetic'});
resolvedOptions.dataMode = string(resolvedOptions.dataMode);

if ~isfield(resolvedOptions, "baseLearningRate")
    resolvedOptions.baseLearningRate = 0.01;
end

if ~isfield(resolvedOptions, "momentumLearningRate")
    resolvedOptions.momentumLearningRate = [];
end

if ~isfield(resolvedOptions, "maxIterations")
    resolvedOptions.maxIterations = 4000;
end

if ~isfield(resolvedOptions, "optimizerNames")
    resolvedOptions.optimizerNames = ["SGD", "Momentum", "RMSProp"];
end

resolvedOptions.optimizerNames = unique( ...
    reshape(string(resolvedOptions.optimizerNames), 1, []), ...
    "stable");
supportedOptimizerNames = ["SGD", "Momentum", "RMSProp"];
if isempty(resolvedOptions.optimizerNames) || ...
        ~all(ismember(resolvedOptions.optimizerNames, supportedOptimizerNames))
    error("signalIntegrity:resolveWorkflowOptions:UnsupportedOptimizer", ...
        "optimizerNames must use only %s.", ...
        strjoin(cellstr(supportedOptimizerNames), ", "));
end

if ~isfield(resolvedOptions, "momentumFactor")
    resolvedOptions.momentumFactor = 0.90;
end

if ~isfield(resolvedOptions, "rmsDecayFactor")
    resolvedOptions.rmsDecayFactor = 0.90;
end

if ~isfield(resolvedOptions, "rmsEpsilon")
    resolvedOptions.rmsEpsilon = 1e-8;
end

if ~isfield(resolvedOptions, "l2Penalty")
    resolvedOptions.l2Penalty = 0;
end

if ~isfield(resolvedOptions, "gradientClipNorm")
    resolvedOptions.gradientClipNorm = 5.0;
end

if ~isfield(resolvedOptions, "rmseEvaluationStride")
    resolvedOptions.rmseEvaluationStride = 20;
end

if ~isfield(resolvedOptions, "predictionMiniBatchSize")
    resolvedOptions.predictionMiniBatchSize = 256;
end

if ~isfield(resolvedOptions, "saveFigures")
    resolvedOptions.saveFigures = false;
end

if ~isfield(resolvedOptions, "figureOutputFolder")
    resolvedOptions.figureOutputFolder = "signalIntegrityResults";
end

if ~isfield(resolvedOptions, "siWaveformSource") || strlength(string(resolvedOptions.siWaveformSource)) == 0
    resolvedOptions.siWaveformSource = "auto";
end

resolvedOptions.siWaveformSource = validatestring( ...
    char(string(resolvedOptions.siWaveformSource)), ...
    {'auto', 'demo', 'user', 'none'});
resolvedOptions.siWaveformSource = string(resolvedOptions.siWaveformSource);

if ~isfield(resolvedOptions, "siWaveformMatFile")
    resolvedOptions.siWaveformMatFile = "";
end
resolvedOptions.siWaveformMatFile = string(resolvedOptions.siWaveformMatFile);

if ~isfield(resolvedOptions, "siWaveformVariable")
    resolvedOptions.siWaveformVariable = "";
end
resolvedOptions.siWaveformVariable = string(resolvedOptions.siWaveformVariable);

if ~isfield(resolvedOptions, "siWaveformTimeVariable")
    resolvedOptions.siWaveformTimeVariable = "";
end
resolvedOptions.siWaveformTimeVariable = string(resolvedOptions.siWaveformTimeVariable);

if ~isfield(resolvedOptions, "siWaveformSampleInterval")
    resolvedOptions.siWaveformSampleInterval = [];
end

if ~isempty(resolvedOptions.siWaveformSampleInterval)
    validateattributes(resolvedOptions.siWaveformSampleInterval, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'siWaveformSampleInterval');
end

if ~isfield(resolvedOptions, "siWaveformSymbolTime")
    resolvedOptions.siWaveformSymbolTime = [];
end

if ~isempty(resolvedOptions.siWaveformSymbolTime)
    validateattributes(resolvedOptions.siWaveformSymbolTime, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'siWaveformSymbolTime');
end

if ~isfield(resolvedOptions, "siWaveformSamplesPerSymbol")
    resolvedOptions.siWaveformSamplesPerSymbol = 16;
end
validateattributes(resolvedOptions.siWaveformSamplesPerSymbol, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', '>=', 2}, ...
    mfilename, 'siWaveformSamplesPerSymbol');

if ~isfield(resolvedOptions, "showPlots")
    resolvedOptions.showPlots = usejava("desktop");
end

if ~isfield(resolvedOptions, "showProgress")
    resolvedOptions.showProgress = true;
end

quickModeFromEnvironment = isQuickModeEnabledInEnvironment();
if ~isfield(resolvedOptions, "quickMode")
    resolvedOptions.quickMode = quickModeFromEnvironment;
end

if ~isfield(resolvedOptions, "quickModeIterations")
    resolvedOptions.quickModeIterations = 300;
end

if resolvedOptions.quickMode
    resolvedOptions.maxIterations = resolvedOptions.quickModeIterations;
end
end

function normalizedOptions = mapLegacyOptionNames(userOptions)
normalizedOptions = userOptions;

legacyOptionMap = [ ...
    "learningRate", "baseLearningRate"; ...
    "learningRateMomentum", "momentumLearningRate"; ...
    "optimizers", "optimizerNames"; ...
    "momentum", "momentumFactor"; ...
    "rmsDecay", "rmsDecayFactor"; ...
    "l2Lambda", "l2Penalty"; ...
    "rmseEvalStride", "rmseEvaluationStride"; ...
    "predictionMiniBatch", "predictionMiniBatchSize"; ...
    "outputDir", "figureOutputFolder"; ...
    "makePlots", "showPlots"; ...
    "verbose", "showProgress"; ...
    "quickIterations", "quickModeIterations"];

for mapIndex = 1:size(legacyOptionMap, 1)
    legacyName = legacyOptionMap(mapIndex, 1);
    preferredName = legacyOptionMap(mapIndex, 2);
    if isfield(normalizedOptions, legacyName) && ~isfield(normalizedOptions, preferredName)
        normalizedOptions.(preferredName) = normalizedOptions.(legacyName);
    end
end
end

function isEnabled = isQuickModeEnabledInEnvironment()
quickModeSetting = lower(string(getenv("SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE")));
if strlength(quickModeSetting) == 0
    quickModeSetting = lower(string(getenv("SI_DNN_QUICK_MODE")));
end

isEnabled = any(quickModeSetting == ["1", "true", "yes", "on"]);
end
