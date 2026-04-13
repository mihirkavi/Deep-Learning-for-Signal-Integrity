function tf = isSignalIntegrityToolboxAvailable()
%ISSIGNALINTEGRITYTOOLBOXAVAILABLE True if Signal Integrity Toolbox is installed.

installedProductNames = {ver().Name};
tf = any(strcmp(installedProductNames, 'Signal Integrity Toolbox')) || ...
    ~isempty(which('eyeDiagramSI')) || ...
    ~isempty(which('openSignalIntegrityKit'));
end
