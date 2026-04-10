classdef WorkbenchUnitTests < matlab.unittest.TestCase

    methods (TestClassSetup)
        function setupPath(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            run(fullfile(root, 'startup_SignalIntegrityAIWorkbench.m'));
        end
    end

    methods (Test)
        function testDatasetSchemaValidation(testCase)
            t = createDemoDataset(50, 1);
            r = validateDatasetSchema(t);
            testCase.verifyTrue(r.ok);
        end

        function testPreprocessingStandardization(testCase)
            X = randn(40, 9);
            [Xz, mu, sig] = standardizeFeatures(X);
            X2 = applyStandardization(X, mu, sig);
            testCase.verifySize(Xz, size(X));
            testCase.verifyEqual(Xz, X2, AbsTol=1e-12);
        end

        function testExtrapolationDetection(testCase)
            b = struct('minRow', zeros(1, 9), 'maxRow', ones(1, 9));
            r = detectExtrapolation(0.5 * ones(1, 9), b);
            testCase.verifyEqual(r.class, "InRange");
            r2 = detectExtrapolation(2 * ones(1, 9), b);
            testCase.verifyEqual(r2.class, "Extrapolated");
        end

        function testPredictionPipelineLinear(testCase)
            ds = createDemoDataset(120, 99);
            opts = struct('modelType', "linear", 'maxEpochs', 5, 'miniBatchSize', 16, ...
                'learningRate', 0.01, 'activation', 'relu', 'trainValSplit', 0.2, ...
                'randomSeed', 3, 'hiddenLayerSizes', [8 4]);
            mh = trainEyeHeightModel(ds, opts);
            mw = trainEyeWidthModel(ds, opts);
            bundle = struct('eyeHeight', mh, 'eyeWidth', mw);
            cfg = getDefaultConfig();
            out = predictMetrics(bundle, cfg.featureDefaults');
            testCase.verifyGreaterThan(out.eyeHeight_mV, 0);
            testCase.verifyGreaterThan(out.eyeWidth_UI, 0);
        end

        function testParameterSweep(testCase)
            ds = createDemoDataset(120, 7);
            opts = struct('modelType', "linear", 'maxEpochs', 5, 'miniBatchSize', 16, ...
                'learningRate', 0.01, 'activation', 'relu', 'trainValSplit', 0.2, ...
                'randomSeed', 3, 'hiddenLayerSizes', [8 4]);
            bundle = struct('eyeHeight', trainEyeHeightModel(ds, opts), ...
                'eyeWidth', trainEyeWidthModel(ds, opts));
            cfg = getDefaultConfig();
            req = struct('paramIndex', 1, 'pMin', 0.5, 'pMax', 8, 'numPoints', 12, ...
                'targetMetric', "eyeHeight", 'baselineRow', cfg.featureDefaults');
            sw = runParameterSweep(bundle, req);
            testCase.verifyEqual(numel(sw.predictions), 12);
        end

        function testCompareDesigns(testCase)
            ds = createDemoDataset(120, 8);
            opts = struct('modelType', "linear", 'maxEpochs', 5, 'miniBatchSize', 16, ...
                'learningRate', 0.01, 'activation', 'relu', 'trainValSplit', 0.2, ...
                'randomSeed', 3, 'hiddenLayerSizes', [8 4]);
            bundle = struct('eyeHeight', trainEyeHeightModel(ds, opts), ...
                'eyeWidth', trainEyeWidthModel(ds, opts));
            cfg = getDefaultConfig();
            s1 = cat(2, {'baseline'}, num2cell(cfg.featureDefaults(:)'));
            v = cfg.featureDefaults(:)';
            v(1) = v(1) + 2;
            s2 = cat(2, {'alt'}, num2cell(v));
            T = cell2table([s1; s2], 'VariableNames', [{'Scenario'} cfg.featureNames(:)']);
            res = compareDesigns(bundle, T, "baseline", "eyeHeight");
            testCase.verifyGreaterThan(height(res.table), 1);
        end
    end
end
