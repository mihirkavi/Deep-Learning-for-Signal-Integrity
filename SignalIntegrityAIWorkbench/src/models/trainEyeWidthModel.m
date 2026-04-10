function trainedModel = trainEyeWidthModel(dataTable, trainingOptions)
%TRAINEYEWIDTHMODEL Train surrogate for eye width (UI).

arguments
    dataTable table
    trainingOptions struct
end

trainedModel = trainSurrogateForTarget(dataTable, "eyeWidth_UI", trainingOptions);
end
