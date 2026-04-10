function report = validateDatasetSchema(dataTable, requiredTargets)
%VALIDATEDATASETSCHEMA Check required feature and target columns exist.
arguments
    dataTable table
    requiredTargets (1, :) string = ["eyeHeight_mV", "eyeWidth_UI"]
end

cfg = getDefaultConfig();
requiredFeatures = string(cfg.featureNames);
missingFeatures = requiredFeatures(~ismember(requiredFeatures, string(dataTable.Properties.VariableNames)));
missingTargets = requiredTargets(~ismember(requiredTargets, string(dataTable.Properties.VariableNames)));

report = struct();
report.ok = isempty(missingFeatures) && isempty(missingTargets);
report.missingFeatures = missingFeatures;
report.missingTargets = missingTargets;
report.numRows = height(dataTable);
report.numNumericIssues = 0;

if report.ok
    sub = dataTable(:, [cellstr(requiredFeatures), cellstr(requiredTargets)]);
    vn = sub.Properties.VariableNames;
    for k = 1:numel(vn)
        v = sub.(vn{k});
        if ~isnumeric(v) || any(isnan(v(:))) || any(isinf(v(:)))
            report.numNumericIssues = report.numNumericIssues + sum(isnan(v(:)) | isinf(v(:)));
        end
    end
end
end
