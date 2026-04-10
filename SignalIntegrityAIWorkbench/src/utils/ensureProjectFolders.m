function ensureProjectFolders(projectRoot)
%ENSUREPROJECTFOLDERS Create data subfolders under the workbench project root.

arguments
    projectRoot (1, :) char
end

cfg = getDefaultConfig();
subdirs = struct2cell(cfg.paths);
for k = 1:numel(subdirs)
    d = fullfile(projectRoot, 'data', subdirs{k});
    if ~isfolder(d)
        mkdir(d);
    end
end
end
