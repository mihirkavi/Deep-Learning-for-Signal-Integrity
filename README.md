# Deep Learning for Signal Integrity

This repository turns a published signal-integrity modeling workflow into a
small MATLAB project that is easy to run, inspect, and extend. The current
cleanup emphasizes explicit naming over abbreviations so the code reads
like a walkthrough instead of a puzzle.

The project trains two regressors:

- `eyeHeight`: predicts eye height in mV
- `eyeWidth`: predicts eye width in unit intervals

It runs in two data modes:

- `real`: loads a populated `signalIntegrityExampleData.mat`
- `synthetic`: generates a deterministic fallback dataset so the full
  workflow still runs end to end

The tracked MAT-file in this repository is intentionally zero-filled, so
fresh clones automatically use synthetic mode until you replace the
template targets with real simulation data.

## Entry Points

- `runSignalIntegrityWorkflow.m`: public function entry point
- `signalIntegrityWorkflowExample.m`: guided walkthrough script
- `signalIntegrityWorkflowRunner.m`: minimal runner script
- `createSignalIntegrityDataTemplate.m`: recreates the placeholder MAT-file

## Naming Conventions

The repository now follows a simple naming scheme:

- top-level callable files use lowerCamelCase verb phrases
- internal helpers live in the `+signalIntegrity` package instead of the
  shorter but less descriptive `+si` abbreviation
- canonical data fields use descriptive names such as
  `trainingFeatures` and `validationTargets`
- workflow options prefer explicit names such as `optimizerNames`,
  `showPlots`, and `showProgress`

Legacy option names and legacy MAT-file field names remain supported so
older snippets continue to run while the project transitions to the clearer
vocabulary.

## Quick Start

Run the walkthrough:

```matlab
signalIntegrityWorkflowExample
```

Run the core workflow directly:

```matlab
workflowOptions = struct();
workflowOptions.quickMode = true;
workflowOptions.showPlots = false;
workflowOptions.showProgress = false;

workflowResults = runSignalIntegrityWorkflow(workflowOptions);
disp(workflowResults.summaryTable)
```

The quick-mode environment toggle is also supported:

```matlab
setenv("SIGNAL_INTEGRITY_EXAMPLE_QUICK_MODE", "1")
signalIntegrityWorkflowExample
```

## Repository Layout

- `+signalIntegrity/resolveWorkflowOptions.m`: option normalization and
  backward-compatible alias handling
- `+signalIntegrity/getExperimentCatalog.m`: experiment metadata from the
  reference paper
- `+signalIntegrity/loadWorkflowData.m`: canonical data loading and
  synthetic fallback generation
- `+signalIntegrity/trainExperimentModels.m`: per-experiment model
  training and evaluation
- `+signalIntegrity/runWorkflow.m`: internal orchestration layer
- `+signalIntegrity/plotExperimentDiagnostics.m`: per-experiment figures
- `+signalIntegrity/plotValidationSummary.m`: cross-experiment validation plot
- `+signalIntegrity/buildToolboxStatusTable.m`: toolbox summary table
- `tests/RunSignalIntegrityWorkflowTest.m`: MATLAB unit tests
- `docs/signalIntegrityToolboxDataset.md`: map SI Toolbox exports to this repo
- `signalIntegrityReferencePaper.pdf`: local copy of the cited paper

## Canonical Data Format

The preferred structure inside `signalIntegrityExampleData.mat` is:

```matlab
eyeHeight.trainingFeatures
eyeHeight.trainingTargets
eyeHeight.validationFeatures
eyeHeight.validationTargets

eyeWidth.trainingFeatures
eyeWidth.trainingTargets
eyeWidth.validationFeatures
eyeWidth.validationTargets
```

Each feature matrix is `[samples x features]` and each target vector is
`[samples x 1]`.

The loader also accepts the older field names:

```matlab
XTrain, yTrain, XVal, yVal
```

If the target arrays are still constant zero-filled placeholders, the
workflow treats the file as a template and falls back to synthetic mode.

## Preferred Workflow Options

`runSignalIntegrityWorkflow` accepts a struct of overrides. The preferred
field names are:

- `dataFile`
- `dataMode`
- `baseLearningRate`
- `momentumLearningRate`
- `optimizerNames`
- `momentumFactor`
- `rmsDecayFactor`
- `l2Penalty`
- `rmseEvaluationStride`
- `predictionMiniBatchSize`
- `showPlots`
- `showProgress`
- `figureOutputFolder`
- `quickMode`
- `quickModeIterations`

Example:

```matlab
workflowOptions = struct();
workflowOptions.dataMode = "synthetic";
workflowOptions.optimizerNames = ["RMSProp", "SGD"];
workflowOptions.quickMode = true;
workflowOptions.showPlots = false;

workflowResults = runSignalIntegrityWorkflow(workflowOptions);
```

Legacy aliases such as `optimizers`, `makePlots`, and `verbose` are still
accepted.

## Outputs

`runSignalIntegrityWorkflow` returns a struct with:

- `options`: resolved workflow options
- `experimentResults`: one result block per experiment
- `summaryTable`: cross-experiment summary
- `experimentOrder`: stable experiment key order

Each experiment result includes:

- `experimentSpec`
- `dataSource`
- `optimizerComparisonTable`
- `referenceOptimizerComparisonTable`
- `bestOptimizerName`
- `bestOptimizerResult`
- `normalizationStatistics`

## Dependencies

The repository itself requires:

- MATLAB
- Deep Learning Toolbox

Optional toolboxes are reported by `signalIntegrity.buildToolboxStatusTable`
for people who want to extend the project into broader signal-integrity
analysis workflows.

### Signal Integrity Toolbox (dataset generation)

To build **training data from MathWorks link simulations** (Serial Link
Designer, industry kits, exports) instead of the synthetic fallback, see
[`docs/signalIntegrityToolboxDataset.md`](docs/signalIntegrityToolboxDataset.md).
Use `signalIntegrity.buildExampleDataFromSiExport` to turn exported tables or
CSVs into `signalIntegrityExampleData.mat`. Listing or opening kits:
[`scripts/openSignalIntegrityKitWorkflow.m`](scripts/openSignalIntegrityKitWorkflow.m).
Hold-out validation notes: [`docs/signalIntegrityValidation.md`](docs/signalIntegrityValidation.md).

## Validation

Run the automated test suite:

```matlab
runtests("tests")
```

Inspect Code Analyzer issues:

```matlab
issues = codeIssues(["runSignalIntegrityWorkflow.m", "+signalIntegrity", "scripts", "tests"]);
disp(issues.Issues)
```

## Reference

Lu, Tianjian, Ken Wu, Zhiping Yang, and Ju Sun, "High-Speed Channel
Modeling with Deep Neural Network for Signal Integrity Analysis."
