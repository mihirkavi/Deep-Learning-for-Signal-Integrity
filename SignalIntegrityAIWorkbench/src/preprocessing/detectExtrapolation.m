function result = detectExtrapolation(featureRow, trainingBounds)
%DETECTEXTRAPOLATION Classify input relative to training min/max envelopes.
arguments
    featureRow (1, :) double
    trainingBounds struct % .minRow (1xF), .maxRow (1xF)
end

lo = trainingBounds.minRow;
hi = trainingBounds.maxRow;
margin = 0.05 * (hi - lo);
margin(~isfinite(margin) | margin < 1e-9) = 1e-6;

inRange = true;
nearBoundary = false;
for k = 1:numel(featureRow)
    if featureRow(k) < lo(k) || featureRow(k) > hi(k)
        inRange = false;
    elseif featureRow(k) < lo(k) + margin(k) || featureRow(k) > hi(k) - margin(k)
        nearBoundary = true;
    end
end

if inRange
    if nearBoundary
        cls = "NearBoundary";
        resultDisplay = "Near boundary";
    else
        cls = "InRange";
        resultDisplay = "In range";
    end
else
    cls = "Extrapolated";
    resultDisplay = "Extrapolated (OOD)";
end

result = struct('class', cls, 'display', resultDisplay, 'inRange', inRange);
end
