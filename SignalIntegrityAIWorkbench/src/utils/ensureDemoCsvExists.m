function csvPath = ensureDemoCsvExists(projectRoot)
%ENSUREDEMOCSVEXISTS Create demo_dataset.csv if missing.

arguments
    projectRoot (1, :) char
end

csvPath = fullfile(projectRoot, 'data', 'datasets', 'demo_dataset.csv');
if ~isfile(csvPath)
    demoTable = createDemoDataset(220, 777);
    writetable(demoTable, csvPath);
end
end
