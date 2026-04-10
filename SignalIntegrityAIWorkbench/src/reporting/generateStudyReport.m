function reportPath = generateStudyReport(reportSpec, exportFolder)
%GENERATESTUDYREPORT Write HTML report (PDF if Report Generator is licensed).
arguments
    reportSpec struct
    exportFolder (1, :) char
end

if ~isfolder(exportFolder)
    mkdir(exportFolder);
end

stamp = datestr(now, 'yyyymmdd_HHMMSS');
reportPath = fullfile(exportFolder, "SI_Workbench_Report_" + stamp + ".html");

fid = fopen(char(reportPath), 'w');
if fid < 0
    error("siwb:generateStudyReport:WriteFailed", "Could not open %s for writing.", reportPath);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '<!DOCTYPE html><html><head><meta charset="utf-8"><title>%s</title>\n', reportSpec.title);
fprintf(fid, '<style>body{font-family:Segoe UI,Helvetica,Arial;background:#12141a;color:#e8eaed;padding:32px;}\n');
fprintf(fid, 'h1{color:#8ab4f8;} table{border-collapse:collapse;width:100%%;margin:16px 0;}\n');
fprintf(fid, 'th,td{border:1px solid #3c4043;padding:8px;text-align:left;} th{background:#202124;}\n');
fprintf(fid, '.muted{color:#9aa0a6;font-size:12px;} .ok{color:#81c995;} .warn{color:#fdd663;}</style></head><body>\n');

fprintf(fid, '<h1>%s</h1><p class="muted">Signal Integrity AI Workbench · %s</p>\n', ...
    reportSpec.title, reportSpec.generatedTime);

if isfield(reportSpec, 'summaryHtml')
    fprintf(fid, '%s\n', reportSpec.summaryHtml);
end

if isfield(reportSpec, 'metricsHtml')
    fprintf(fid, '<h2>Validation metrics</h2>%s\n', reportSpec.metricsHtml);
end

if isfield(reportSpec, 'warnings') && strlength(reportSpec.warnings) > 0
    fprintf(fid, '<h2>Warnings</h2><p class="warn">%s</p>\n', reportSpec.warnings);
end

fprintf(fid, '</body></html>\n');
end
