function displayName = getOptimizerDisplayName(optimizerName)
%GETOPTIMIZERDISPLAYNAME Return the human-readable optimizer label.

switch string(optimizerName)
    case "SGD"
        displayName = "Stochastic gradient descent";
    case "Momentum"
        displayName = "Stochastic gradient descent with momentum";
    case "RMSProp"
        displayName = "Root mean square propagation";
    otherwise
        displayName = string(optimizerName);
end
end
