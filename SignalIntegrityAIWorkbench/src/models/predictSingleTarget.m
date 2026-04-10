function yhat = predictSingleTarget(model, Xrow)
%PREDICTSINGLETARGET One row prediction (N=1) for a trained surrogate model.
arguments
    model struct
    Xrow (1, :) double
end

switch model.type
    case "deep"
        yhat = predict(model.net, Xrow);
    case "linear"
        z = [1, Xrow(:)'];
        yhat = z * model.beta;
    case {"ensemble"}
        yhat = predict(model.Mdl, Xrow);
    case "gpr"
        yhat = predict(model.Mdl, Xrow);
        if size(yhat, 2) > 1
            yhat = yhat(:, 1);
        end
    otherwise
        error("siwb:predictSingleTarget:UnknownType", "Unknown model type.");
end

if numel(yhat) > 1
    yhat = yhat(1);
end
end
