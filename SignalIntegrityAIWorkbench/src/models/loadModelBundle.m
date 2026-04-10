function modelBundle = loadModelBundle(filePath)
%LOADMODELBUNDLE Load model bundle saved by saveModelBundle.

arguments
    filePath (1, :) char
end

S = load(filePath);
if isfield(S, 'bundle')
    modelBundle = S.bundle;
else
    modelBundle = S.modelBundle;
end

if ~isfield(modelBundle, 'eyeHeight') || ~isfield(modelBundle, 'eyeWidth')
    error("siwb:loadModelBundle:InvalidFile", "File does not contain a valid model bundle.");
end
end
