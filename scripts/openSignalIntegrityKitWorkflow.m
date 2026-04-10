function openSignalIntegrityKitWorkflow(kitName)
%OPENSIGNALINTEGRITYKITWORKFLOW List or download MathWorks Signal Integrity kits.
%
%   openSignalIntegrityKitWorkflow() lists available kits (requires Signal
%   Integrity Toolbox). See openSignalIntegrityKit documentation.
%
%   openSignalIntegrityKitWorkflow("PCIe_Gen5_NVMe") downloads/opens an example kit.
%
%   Add the repository root to the MATLAB path, then run from any folder:
%     addpath(genpath(fullfile(pwd,"scripts")));

arguments
    kitName (1,1) string = ""
end

if strlength(kitName) == 0
    kitList = openSignalIntegrityKit;
    disp(kitList);
    fprintf("\nExample: openSignalIntegrityKitWorkflow(""PCIe_Gen5_NVMe"")\n");
else
    projectFolder = openSignalIntegrityKit(kitName);
    disp(projectFolder);
end
end
