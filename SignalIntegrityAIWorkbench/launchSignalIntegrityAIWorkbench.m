function launchSignalIntegrityAIWorkbench()
%LAUNCHSIGNALINTEGRITYAIWORKBENCH Start the Signal Integrity AI Workbench desktop app.

projectRoot = fileparts(mfilename('fullpath'));
startup_SignalIntegrityAIWorkbench(projectRoot);
SignalIntegrityAIWorkbenchApp(projectRoot);
end
