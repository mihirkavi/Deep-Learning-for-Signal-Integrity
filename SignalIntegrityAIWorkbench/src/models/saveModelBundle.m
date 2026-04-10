function saveModelBundle(modelBundle, filePath)
%SAVEMODELBUNDLE Persist trained eye height/width models and metadata.

arguments
    modelBundle struct
    filePath (1, :) char
end

bundle = modelBundle;
bundle.bundleVersion = "1";
bundle.savedAt = datetime('now');
save(filePath, 'bundle', '-v7.3');
end
