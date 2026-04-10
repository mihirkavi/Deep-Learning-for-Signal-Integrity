function trainedModel = trainEyeHeightModel(dataTable, trainingOptions)
%TRAINEYEHEIGHTMODEL Train surrogate for eye height (mV).

arguments
    dataTable table
    trainingOptions struct
end

trainedModel = trainSurrogateForTarget(dataTable, "eyeHeight_mV", trainingOptions);
end
