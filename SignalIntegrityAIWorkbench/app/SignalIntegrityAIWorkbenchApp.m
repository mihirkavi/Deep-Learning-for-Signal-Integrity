classdef SignalIntegrityAIWorkbenchApp < handle
    %SIGNALINTEGRITYAIWORKBENCHAPP Premium surrogate-model workbench for SI analysis.

    properties (Access = public)
        ProjectRoot char = ''
    end

    properties (Access = private)
        UIFigure matlab.ui.Figure
        ModelBundle struct = struct()
        CurrentDataset table = table()
        Studies cell = {}
        UI struct
    end

    methods (Access = public)
        function app = SignalIntegrityAIWorkbenchApp(projectRoot)
            if nargin < 1 || strlength(string(projectRoot)) == 0
                projectRoot = fileparts(fileparts(mfilename('fullpath')));
            end
            app.ProjectRoot = char(projectRoot);
            startup_SignalIntegrityAIWorkbench(app.ProjectRoot);

            defaultBundle = fullfile(app.ProjectRoot, 'data', 'saved_models', 'default_bundle.mat');
            if isfile(defaultBundle)
                try
                    app.ModelBundle = loadModelBundle(defaultBundle);
                catch
                    app.ModelBundle = struct();
                end
            end

            createUserInterface(app);
            refreshAllPanels(app);

            if nargout == 0
                clear app
            end
        end
    end

    methods (Access = private)
        function createUserInterface(app)
            theme = struct( ...
                'bg', [0.102 0.109 0.118], ...
                'panel', [0.145 0.153 0.165], ...
                'accent', [0.22 0.56 0.98], ...
                'text', [0.92 0.93 0.94], ...
                'muted', [0.58 0.60 0.63]);

            app.UIFigure = uifigure( ...
                'Name', 'Signal Integrity AI Workbench', ...
                'Position', [40 40 1280 780], ...
                'Color', theme.bg, ...
                'Icon', '');

            mainGrid = uigridlayout(app.UIFigure, [3 1]);
            mainGrid.RowHeight = {64, '1x', 22};
            mainGrid.Padding = [16 16 16 8];
            mainGrid.BackgroundColor = theme.bg;

            header = uigridlayout(mainGrid, [2 2]);
            header.Layout.Row = 1;
            header.RowHeight = {'fit', 'fit'};
            header.ColumnWidth = {'1x', 'fit'};
            header.BackgroundColor = theme.bg;

            uilabel(header, ...
                'Text', 'Signal Integrity AI Workbench', ...
                'FontSize', 22, ...
                'FontWeight', 'bold', ...
                'FontColor', theme.text, ...
                'Layout', [1 1]);

            uilabel(header, ...
                'Text', 'Surrogate channel models · inspired by Lu et al. DNN SI workflow', ...
                'FontSize', 11, ...
                'FontColor', theme.muted, ...
                'Layout', [2 1]);

            uilabel(header, 'Text', "v" + getAppVersion(), 'FontColor', theme.muted, 'Layout', [1 2]);

            tabGroup = uitabgroup(mainGrid, 'SelectionChangedFcn', @(~,~) refreshAllPanels(app));
            tabGroup.Layout.Row = 2;
            app.UI.TabGroup = tabGroup;

            buildDashboardTab(app, tabGroup, theme);
            buildSinglePredictionTab(app, tabGroup, theme);
            buildSweepTab(app, tabGroup, theme);
            buildCompareTab(app, tabGroup, theme);
            buildDatasetTab(app, tabGroup, theme);
            buildTrainingTab(app, tabGroup, theme);
            buildValidationTab(app, tabGroup, theme);
            buildReportsTab(app, tabGroup, theme);
            buildSettingsTab(app, tabGroup, theme);

            foot = uilabel(mainGrid, ...
                'Text', 'B2B engineering UI · MATLAB only · models are surrogates — validate critical designs with full SI simulation.', ...
                'FontColor', theme.muted, ...
                'FontSize', 10);
            foot.Layout.Row = 3;
        end

        function buildDashboardTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Dashboard');
            grid = uigridlayout(tab, [2 1]);
            grid.RowHeight = {'fit', '1x'};
            grid.Padding = 12;
            grid.BackgroundColor = theme.bg;

            cardGrid = uigridlayout(grid, [2 3]);
            cardGrid.RowHeight = {'fit', 'fit'};
            cardGrid.ColumnWidth = {'1x', '1x', '1x'};
            cardGrid.BackgroundColor = theme.bg;

            app.UI.Dash.ModelCard = makeCard(app, cardGrid, theme, 1, 1, "Active model", "None loaded");
            app.UI.Dash.RmseCard = makeCard(app, cardGrid, theme, 1, 2, "Validation RMSE", "—");
            app.UI.Dash.DataCard = makeCard(app, cardGrid, theme, 1, 3, "Dataset", "demo_dataset.csv");
            app.UI.Dash.StudiesCard = makeCard(app, cardGrid, theme, 2, 1, "Saved studies", "0");
            app.UI.Dash.HealthCard = makeCard(app, cardGrid, theme, 2, 2, "Confidence health", "Unknown");
            app.UI.Dash.QuickCard = uipanel(cardGrid, 'BackgroundColor', theme.panel, 'BorderType', 'none');
            app.UI.Dash.QuickCard.Layout.Row = 2;
            app.UI.Dash.QuickCard.Layout.Column = 3;
            uilabel(app.UI.Dash.QuickCard, 'Position', [12 40 400 22], 'Text', 'Quick actions', 'FontColor', theme.text, 'FontWeight', 'bold');
            uibutton(app.UI.Dash.QuickCard, 'Position', [12 8 120 28], 'Text', 'New prediction', ...
                'BackgroundColor', theme.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) selectTab(app, 2));
            uibutton(app.UI.Dash.QuickCard, 'Position', [140 8 120 28], 'Text', 'Run sweep', ...
                'BackgroundColor', theme.panel, 'FontColor', theme.text, ...
                'ButtonPushedFcn', @(~,~) selectTab(app, 3));

            recent = uitable(grid, 'ColumnName', {'Study', 'Eye H (mV)', 'Eye W (UI)', 'Confidence'}, ...
                'BackgroundColor', theme.panel, 'ForegroundColor', theme.text);
            recent.Layout.Row = 2;
            recent.ColumnWidth = {'auto', 'auto', 'auto', '1x'};
            app.UI.Dash.RecentTable = recent;
        end

        function c = makeCard(~, parent, theme, row, col, title, value)
            p = uipanel(parent, 'BackgroundColor', theme.panel, 'BorderType', 'line', 'HighlightColor', [0.3 0.32 0.36]);
            p.Layout.Row = row;
            p.Layout.Column = col;
            uilabel(p, 'Position', [12 52 280 18], 'Text', title, 'FontColor', [0.7 0.72 0.75], 'FontSize', 11);
            c = uilabel(p, 'Position', [12 16 280 30], 'Text', value, 'FontColor', [0.95 0.96 0.98], 'FontSize', 18, 'FontWeight', 'bold');
        end

        function selectTab(app, index)
            ch = app.UI.TabGroup.Children;
            if index >= 1 && index <= numel(ch)
                app.UI.TabGroup.SelectedTab = ch(index);
            end
        end

        function buildSinglePredictionTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Single Prediction');
            g = uigridlayout(tab, [3 2]);
            g.ColumnWidth = {'2x', '1x'};
            g.RowHeight = {'1x', 'fit', 'fit'};
            g.Padding = 12;
            g.BackgroundColor = theme.bg;

            form = uipanel(g, 'Title', 'Channel parameters', 'FontColor', theme.text, ...
                'BackgroundColor', theme.panel, 'ForegroundColor', [0.4 0.42 0.45]);
            form.Layout.Row = 1;
            form.Layout.Column = 1;
            fg = uigridlayout(form, [9 3]);
            fg.ColumnWidth = {160, '1x', 56};
            fg.Padding = [12 12 12 12];
            fg.BackgroundColor = theme.panel;

            cfg = getDefaultConfig();
            app.UI.Pred.Edits = gobjects(9, 1);
            for k = 1:9
                uilabel(fg, 'Text', cfg.featureDisplayNames{k}, 'FontColor', theme.text, 'Layout', [k 1]);
                app.UI.Pred.Edits(k) = uieditfield(fg, 'numeric', 'Value', cfg.featureDefaults(k), ...
                    'Limits', [cfg.featureLimits(k,1), cfg.featureLimits(k,2)], ...
                    'Tooltip', cfg.featureNames{k}, ...
                    'Layout', [k 2]);
                uilabel(fg, 'Text', cfg.featureUnits{k}, 'FontColor', theme.muted, 'Layout', [k 3]);
            end

            side = uigridlayout(g, [6 1]);
            side.Layout.Row = 1;
            side.Layout.Column = 2;
            side.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit', 'fit'};
            side.BackgroundColor = theme.bg;

            app.UI.Pred.EyeH = uilabel(side, 'Text', '— mV', 'FontSize', 26, 'FontColor', theme.accent, 'FontWeight', 'bold', 'Layout', [1 1]);
            app.UI.Pred.EyeW = uilabel(side, 'Text', '— UI', 'FontSize', 26, 'FontColor', theme.accent, 'FontWeight', 'bold', 'Layout', [2 1]);
            app.UI.Pred.Conf = uilabel(side, 'Text', 'Confidence: —', 'FontColor', theme.text, 'Layout', [3 1]);
            app.UI.Pred.Warn = uitextarea(side, 'Editable', 'off', 'Value', {'Warnings and spec evaluation appear here.'}, ...
                'BackgroundColor', [0.1 0.11 0.12], 'FontColor', theme.muted, 'Layout', [4 1]);

            uibutton(side, 'Text', 'Run prediction', 'BackgroundColor', theme.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) onPredict(app), 'Layout', [5 1]);

            spec = uigridlayout(g, [2 4]);
            spec.Layout.Row = 2;
            spec.Layout.Column = [1 2];
            spec.ColumnWidth = {'fit', '1x', 'fit', '1x'};
            spec.BackgroundColor = theme.bg;
            uilabel(spec, 'Text', 'Spec eye height ≥ (mV)');
            app.UI.Pred.SpecH = uieditfield(spec, 'numeric', 'Value', getDefaultConfig().thresholds.eyeHeightPass_mV);
            uilabel(spec, 'Text', 'Spec eye width ≥ (UI)');
            app.UI.Pred.SpecW = uieditfield(spec, 'numeric', 'Value', getDefaultConfig().thresholds.eyeWidthPass_UI);

            actions = uigridlayout(g, [1 3]);
            actions.Layout.Row = 3;
            actions.Layout.Column = [1 2];
            actions.BackgroundColor = theme.bg;
            uibutton(actions, 'Text', 'Save study', 'ButtonPushedFcn', @(~,~) onSaveStudy(app));
            uibutton(actions, 'Text', 'Export JSON', 'ButtonPushedFcn', @(~,~) onExportStudyJson(app));
        end

        function buildSweepTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Parameter Sweep');
            g = uigridlayout(tab, [2 2]);
            g.RowHeight = {'fit', '1x'};
            g.ColumnWidth = {'1x', '1x'};
            g.BackgroundColor = theme.bg;

            cfg = getDefaultConfig();
            left = uipanel(g, 'Title', 'Sweep setup', 'FontColor', theme.text, 'BackgroundColor', theme.panel);
            left.Layout.Row = 1;
            left.Layout.Column = 1;
            lg = uigridlayout(left, [7 2]);
            uilabel(lg, 'Text', 'Parameter');
            app.UI.Sweep.ParamDrop = uidropdown(lg, 'Items', cfg.featureDisplayNames, 'Value', cfg.featureDisplayNames{1});
            uilabel(lg, 'Text', 'Min'); app.UI.Sweep.PMin = uieditfield(lg, 'numeric', 'Value', cfg.featureLimits(1,1));
            uilabel(lg, 'Text', 'Max'); app.UI.Sweep.PMax = uieditfield(lg, 'numeric', 'Value', cfg.featureLimits(1,2));
            uilabel(lg, 'Text', 'Points'); app.UI.Sweep.NPts = uieditfield(lg, 'numeric', 'Value', 25, 'RoundFractionalValues', 'on');
            uilabel(lg, 'Text', 'Target metric');
            app.UI.Sweep.Metric = uidropdown(lg, 'Items', {'eyeHeight', 'eyeWidth'}, 'Value', 'eyeHeight');
            uibutton(lg, 'Text', 'Run sweep', 'BackgroundColor', theme.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) onSweep(app));

            app.UI.Sweep.Summary = uitextarea(g, 'Editable', 'off', ...
                'BackgroundColor', [0.1 0.11 0.12], 'FontColor', theme.text);
            app.UI.Sweep.Summary.Layout.Row = 1;
            app.UI.Sweep.Summary.Layout.Column = 2;

            ax = uiaxes(g);
            ax.Layout.Row = 2;
            ax.Layout.Column = [1 2];
            ax.Color = [0.08 0.09 0.1];
            ax.XColor = theme.muted;
            ax.YColor = theme.muted;
            grid(ax, 'on');
            title(ax, 'Sweep result', 'Color', theme.text);
            app.UI.Sweep.Axes = ax;
        end

        function buildCompareTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Compare Designs');
            g = uigridlayout(tab, [2 1]);
            g.RowHeight = {'fit', '1x'};
            g.BackgroundColor = theme.bg;
            uilabel(g, 'Text', 'Define scenarios in Dataset Manager or paste rows — use Scenario column.', 'FontColor', theme.muted);
            app.UI.Cmp.Table = uitable(g, 'ColumnEditable', true);
            cfg = getDefaultConfig();
            app.UI.Cmp.Table.ColumnName = [{'Scenario'} cfg.featureNames'];
            uibutton(g, 'Text', 'Run comparison', 'BackgroundColor', theme.accent, ...
                'ButtonPushedFcn', @(~,~) onCompare(app));
        end

        function buildDatasetTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Dataset Manager');
            g = uigridlayout(tab, [3 1]);
            g.RowHeight = {'fit', '1x', 'fit'};
            g.BackgroundColor = theme.bg;
            top = uigridlayout(g, [1 4]);
            uibutton(top, 'Text', 'Load CSV/MAT', 'ButtonPushedFcn', @(~,~) onLoadDataset(app));
            uibutton(top, 'Text', 'Load demo data', 'ButtonPushedFcn', @(~,~) onLoadDemo(app));
            uibutton(top, 'Text', 'Validate schema', 'ButtonPushedFcn', @(~,~) onValidateDataset(app));
            uibutton(top, 'Text', 'Save to datasets folder', 'ButtonPushedFcn', @(~,~) onSaveDataset(app));
            app.UI.Data.Preview = uitable(g);
            app.UI.Data.Summary = uitextarea(g, 'Editable', 'off');
        end

        function buildTrainingTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Model Training Lab');
            g = uigridlayout(tab, [2 1]);
            g.RowHeight = {'fit', '1x'};
            g.BackgroundColor = theme.bg;
            opts = uigridlayout(g, [8 4]);
            opts.Layout.Row = 1;
            opts.BackgroundColor = theme.bg;
            uilabel(opts, 'Text', 'Model type');
            app.UI.Train.Type = uidropdown(opts, 'Items', {'deep', 'ensemble', 'linear', 'gpr'});
            uilabel(opts, 'Text', 'Epochs'); app.UI.Train.Epochs = uieditfield(opts, 'numeric', 'Value', 80);
            uilabel(opts, 'Text', 'Batch'); app.UI.Train.Batch = uieditfield(opts, 'numeric', 'Value', 32);
            uilabel(opts, 'Text', 'Learn rate'); app.UI.Train.LR = uieditfield(opts, 'numeric', 'Value', 0.01);
            uilabel(opts, 'Text', 'Hidden (deep)'); app.UI.Train.Hidden = uieditfield(opts, 'text', 'Value', '64 32');
            uilabel(opts, 'Text', 'Train/val split'); app.UI.Train.Split = uieditfield(opts, 'numeric', 'Value', 0.15);
            uibutton(opts, 'Text', 'Train both targets', 'BackgroundColor', theme.accent, 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) onTrain(app));
            app.UI.Train.Log = uitextarea(g, 'Editable', 'off', 'FontName', 'Consolas', ...
                'BackgroundColor', [0.09 0.1 0.11]);
            app.UI.Train.Log.Layout.Row = 2;
        end

        function buildValidationTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Validation / Metrics');
            g = uigridlayout(tab, [2 2]);
            g.RowHeight = {'1x', '1x'};
            g.ColumnWidth = {'1x', '1x'};
            g.BackgroundColor = theme.bg;
            app.UI.Val.MetricsText = uitextarea(g, 'Editable', 'off');
            app.UI.Val.ScatterAx = uiaxes(g);
            app.UI.Val.ScatterAx.Layout.Column = 2;
            app.UI.Val.ResidAx = uiaxes(g);
            app.UI.Val.ResidAx.Layout.Row = 2;
        end

        function buildReportsTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Reports / Export');
            g = uigridlayout(tab, [2 1]);
            g.BackgroundColor = theme.bg;
            uibutton(g, 'Text', 'Generate HTML report', 'BackgroundColor', theme.accent, ...
                'ButtonPushedFcn', @(~,~) onReport(app));
            app.UI.Rep.Status = uilabel(g, 'Text', '', 'FontColor', theme.text);
        end

        function buildSettingsTab(app, tabGroup, theme)
            tab = uitab(tabGroup, 'Title', 'Settings / About');
            g = uigridlayout(tab, [4 1]);
            g.BackgroundColor = theme.bg;
            app.UI.Set.Root = uilabel(g, 'Text', '', 'FontColor', theme.text);
            uilabel(g, 'Text', 'Default thresholds and storage live under data/. See README for deployment.', ...
                'FontColor', [0.65 0.67 0.7]);
            uibutton(g, 'Text', 'Open exports folder', 'ButtonPushedFcn', @(~,~) winopen(fullfile(app.ProjectRoot, 'data', 'exports')));
        end

        function refreshAllPanels(app)
            app.UI.Set.Root.Text = "Project: " + app.ProjectRoot;

            if isempty(fieldnames(app.ModelBundle))
                app.UI.Dash.ModelCard.Text = "None — train in Model Lab";
                app.UI.Dash.RmseCard.Text = "—";
                app.UI.Dash.HealthCard.Text = "No model";
            else
                app.UI.Dash.ModelCard.Text = "default_bundle.mat";
                vh = app.ModelBundle.eyeHeight.metrics.validation.rmse;
                vw = app.ModelBundle.eyeWidth.metrics.validation.rmse;
                app.UI.Dash.RmseCard.Text = sprintf('H:%.3f mV  W:%.4f UI', vh, vw);
                app.UI.Dash.HealthCard.Text = "Trained surrogate";
                refreshValidationPlots(app);
            end

            app.UI.Dash.StudiesCard.Text = sprintf('%d', numel(app.Studies));
            if ~isempty(app.CurrentDataset)
                app.UI.Dash.DataCard.Text = "In memory";
            else
                app.UI.Dash.DataCard.Text = "demo_dataset.csv";
            end
        end

        function refreshValidationPlots(app)
            if isempty(fieldnames(app.ModelBundle))
                return;
            end
            m = app.ModelBundle.eyeHeight.metrics;
            txt = sprintf([ ...
                'Eye height — Train RMSE: %.4f  MAE: %.4f  Max rel %%: %.2f  R²: %.4f\n' ...
                'Eye height — Val   RMSE: %.4f  MAE: %.4f  Max rel %%: %.2f  R²: %.4f\n\n'], ...
                m.train.rmse, m.train.mae, m.train.maxRelativeErrorPct, m.train.r2, ...
                m.validation.rmse, m.validation.mae, m.validation.maxRelativeErrorPct, m.validation.r2);
            m2 = app.ModelBundle.eyeWidth.metrics;
            txt = [txt sprintf([ ...
                'Eye width — Train RMSE: %.5f  MAE: %.5f  Max rel %%: %.2f  R²: %.4f\n' ...
                'Eye width — Val   RMSE: %.5f  MAE: %.5f  Max rel %%: %.2f  R²: %.4f\n'], ...
                m2.train.rmse, m2.train.mae, m2.train.maxRelativeErrorPct, m2.train.r2, ...
                m2.validation.rmse, m2.validation.mae, m2.validation.maxRelativeErrorPct, m2.validation.r2)];
            app.UI.Val.MetricsText.Value = {txt};
            cla(app.UI.Val.ScatterAx);
            title(app.UI.Val.ScatterAx, 'Metrics loaded (retrain for fresh scatter data)', 'Color', 'w');
        end

        function fv = gatherFeatureVector(app)
            v = zeros(1, 9);
            for k = 1:9
                v(k) = app.UI.Pred.Edits(k).Value;
            end
            fv = v;
        end

        function onPredict(app)
            if isempty(fieldnames(app.ModelBundle))
                app.UI.Pred.Warn.Value = {'Train or load a model first.'};
                return;
            end
            out = predictMetrics(app.ModelBundle, gatherFeatureVector(app));
            app.UI.Pred.EyeH.Text = sprintf('%.2f mV', out.eyeHeight_mV);
            app.UI.Pred.EyeW.Text = sprintf('%.4f UI', out.eyeWidth_UI);
            app.UI.Pred.Conf.Text = "Confidence: " + string(out.confidenceDisplay);
            passH = out.eyeHeight_mV >= app.UI.Pred.SpecH.Value;
            passW = out.eyeWidth_UI >= app.UI.Pred.SpecW.Value;
            app.UI.Pred.Warn.Value = {sprintf('Spec pass H:%d W:%d · %s', passH, passW, char(out.confidenceDisplay))};
        end

        function onSaveStudy(app)
            if isempty(fieldnames(app.ModelBundle))
                return;
            end
            out = predictMetrics(app.ModelBundle, gatherFeatureVector(app));
            app.Studies{end+1} = out;
            refreshAllPanels(app);
        end

        function onExportStudyJson(app)
            if isempty(app.Studies)
                return;
            end
            p = fullfile(app.ProjectRoot, 'data', 'exports', 'last_study.json');
            fid = fopen(p, 'w');
            fprintf(fid, '%s', jsonencode(app.Studies{end}));
            fclose(fid);
        end

        function onSweep(app)
            if isempty(fieldnames(app.ModelBundle))
                return;
            end
            cfg = getDefaultConfig();
            idx = find(strcmp(cfg.featureDisplayNames, app.UI.Sweep.ParamDrop.Value), 1);
            req = struct( ...
                'paramIndex', idx, ...
                'pMin', app.UI.Sweep.PMin.Value, ...
                'pMax', app.UI.Sweep.PMax.Value, ...
                'numPoints', round(app.UI.Sweep.NPts.Value), ...
                'targetMetric', string(app.UI.Sweep.Metric.Value), ...
                'baselineRow', gatherFeatureVector(app));
            sw = runParameterSweep(app.ModelBundle, req);
            cla(app.UI.Sweep.Axes);
            hold(app.UI.Sweep.Axes, 'on');
            plot(app.UI.Sweep.Axes, sw.pValues, sw.predictions, 'Color', [0.35 0.65 1], 'LineWidth', 1.8);
            hold(app.UI.Sweep.Axes, 'off');
            grid(app.UI.Sweep.Axes, 'on');
            app.UI.Sweep.Summary.Value = {sprintf('Optimum at %s = %.4g, metric = %.5g', ...
                sw.parameterName, sw.bestParameterValue, sw.bestMetricValue)};
            exportFolder = fullfile(app.ProjectRoot, 'data', 'exports');
            exportSweepResults(sw, exportFolder, 'last_sweep');
        end

        function onCompare(app)
            if isempty(fieldnames(app.ModelBundle)) || isempty(app.UI.Cmp.Table.Data)
                return;
            end
            T = cell2table(app.UI.Cmp.Table.Data, 'VariableNames', app.UI.Cmp.Table.ColumnName);
            res = compareDesigns(app.ModelBundle, T, "baseline", "eyeHeight");
            uialert(app.UIFigure, sprintf('Best scenario row %d', res.bestRowIndex), 'Comparison');
        end

        function onLoadDataset(app)
            [f, p] = uigetfile({'*.csv;*.mat'});
            if isequal(f, 0)
                return;
            end
            fp = fullfile(p, f);
            if endsWith(f, '.csv', 'IgnoreCase', true)
                app.CurrentDataset = readtable(fp);
            else
                S = load(fp);
                fn = fieldnames(S);
                app.CurrentDataset = S.(fn{1});
            end
            app.UI.Data.Preview.Data = head(app.CurrentDataset, 40);
            app.UI.Data.Summary.Value = {evalc('disp(summary(app.CurrentDataset))')};
        end

        function onLoadDemo(app)
            p = ensureDemoCsvExists(app.ProjectRoot);
            app.CurrentDataset = readtable(p);
            app.UI.Data.Preview.Data = head(app.CurrentDataset, 40);
            cfg = getDefaultConfig();
            s1 = cat(2, {'baseline'}, num2cell(cfg.featureDefaults(:)'));
            v = cfg.featureDefaults(:)';
            v(1) = v(1) + 1.5;
            s2 = cat(2, {'candidate_A'}, num2cell(v));
            app.UI.Cmp.Table.Data = [s1; s2];
        end

        function onValidateDataset(app)
            if isempty(app.CurrentDataset)
                uialert(app.UIFigure, 'Load a dataset first.', 'Dataset');
                return;
            end
            r = validateDatasetSchema(app.CurrentDataset);
            if r.ok
                uialert(app.UIFigure, 'Schema OK.', 'Dataset');
            else
                uialert(app.UIFigure, 'Missing columns.', 'Dataset');
            end
        end

        function onSaveDataset(app)
            if isempty(app.CurrentDataset)
                return;
            end
            p = fullfile(app.ProjectRoot, 'data', 'datasets', 'user_dataset.csv');
            writetable(app.CurrentDataset, p);
        end

        function onTrain(app)
            if isempty(app.CurrentDataset)
                onLoadDemo(app);
            end
            r = validateDatasetSchema(app.CurrentDataset);
            if ~r.ok
                uialert(app.UIFigure, 'Fix dataset columns first.', 'Training');
                return;
            end
            to = struct( ...
                'modelType', app.UI.Train.Type.Value, ...
                'maxEpochs', app.UI.Train.Epochs.Value, ...
                'miniBatchSize', app.UI.Train.Batch.Value, ...
                'learningRate', app.UI.Train.LR.Value, ...
                'activation', 'relu', ...
                'trainValSplit', app.UI.Train.Split.Value, ...
                'randomSeed', 42);
            hs = sscanf(app.UI.Train.Hidden.Value, '%f');
            if isempty(hs)
                hs = [64; 32];
            end
            to.hiddenLayerSizes = hs(:)';
            try
                mh = trainEyeHeightModel(app.CurrentDataset, to);
                mw = trainEyeWidthModel(app.CurrentDataset, to);
                bundle = struct('eyeHeight', mh, 'eyeWidth', mw, 'bundleVersion', '1');
                app.ModelBundle = bundle;
                p = fullfile(app.ProjectRoot, 'data', 'saved_models', 'default_bundle.mat');
                saveModelBundle(bundle, p);
                app.UI.Train.Log.Value = {'Training complete. Saved default_bundle.mat'};
                refreshAllPanels(app);
            catch ME
                app.UI.Train.Log.Value = {ME.message};
            end
        end

        function onReport(app)
            rep = struct('title', "SI Workbench study", 'generatedTime', string(datetime('now')));
            rep.summaryHtml = "<p>Model bundle and studies export from workspace.</p>";
            rep.metricsHtml = "<p>See Validation tab for numeric metrics.</p>";
            p = generateStudyReport(rep, fullfile(app.ProjectRoot, 'data', 'exports'));
            app.UI.Rep.Status.Text = "Saved: " + p;
        end
    end
end
