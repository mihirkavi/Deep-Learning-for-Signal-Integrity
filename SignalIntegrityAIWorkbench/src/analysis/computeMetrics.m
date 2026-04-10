function metrics = computeMetrics(yTrain, yPredTrain, yVal, yPredVal)
%COMPUTEMETRICS RMSE, MAE, max relative error, R² for train and validation.

metrics = struct();
metrics.train = computeBlock(yTrain, yPredTrain);
metrics.validation = computeBlock(yVal, yPredVal);
end

function b = computeBlock(y, yhat)
e = y(:) - yhat(:);
rmse = sqrt(mean(e.^2));
mae = mean(abs(e));
ref = max(abs(y(:)), 1e-9);
relPct = 100 * abs(e) ./ ref;
maxRel = max(relPct);
ssRes = sum(e.^2);
ssTot = sum((y(:) - mean(y(:))).^2);
if ssTot < 1e-18
    r2 = 1;
else
    r2 = 1 - ssRes / ssTot;
end
b = struct('rmse', rmse, 'mae', mae, 'maxRelativeErrorPct', maxRel, 'r2', r2);
end
