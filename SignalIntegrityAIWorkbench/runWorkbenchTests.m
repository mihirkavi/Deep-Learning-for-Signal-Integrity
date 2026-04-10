function results = runWorkbenchTests()
%RUNWORKBENCHTESTS Run all Signal Integrity AI Workbench unit tests.

projectRoot = fileparts(mfilename('fullpath'));
run(fullfile(projectRoot, 'startup_SignalIntegrityAIWorkbench.m'));
results = runtests(fullfile(projectRoot, 'tests'), 'ReportCoverage', false);
end
