function workflowResults = runSignalIntegrityWorkflow(workflowOptions)
%RUNSIGNALINTEGRITYWORKFLOW Train and compare the signal integrity models.
%   WORKFLOWRESULTS = RUNSIGNALINTEGRITYWORKFLOW() runs the workflow with
%   the default options. The workflow automatically uses populated
%   reference data when available and otherwise falls back to a
%   deterministic synthetic dataset.
%
%   WORKFLOWRESULTS = RUNSIGNALINTEGRITYWORKFLOW(WORKFLOWOPTIONS) applies
%   the supplied option overrides, trains the eye-height and eye-width
%   regressors, compares the configured optimizers, and returns the
%   comparison tables and diagnostics for each experiment.
%
%   Preferred option names include:
%     dataFile, dataMode, optimizerNames, quickMode, showPlots, showProgress
%
%   Legacy option names from earlier revisions of this repository are still
%   accepted for backward compatibility.

arguments
    workflowOptions struct = struct()
end

workflowResults = signalIntegrity.runWorkflow(workflowOptions);
end
