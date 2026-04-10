# Hold-out validation: DNN vs Signal Integrity Toolbox ground truth

Use this **after** you have a MAT-file built from SI Toolbox exports (`signalIntegrity.buildExampleDataFromSiExport`).

## Idea

1. Split simulation rows into **train + validation** using the same counts as [`getExperimentCatalog.m`](../+signalIntegrity/getExperimentCatalog.m) (717/476 for eye height, 509/203 for eye width), with a **fixed random seed** so splits are reproducible.
2. Run `runSignalIntegrityWorkflow` with `dataMode = "real"` and `dataFile` pointing at that MAT-file.
3. Compare `workflowResults.experimentResults.<key>.comparisonTable` (DNN RMSE on the validation split) against:
   - the **reference paper** table (only meaningful if your features and targets match the paper), and/or
   - a **direct residual check**: for each validation row, compute `predictedTarget - siToolboxTarget` using the trained model’s predictions on `validationFeatures` (advanced: extend plotting in `plotExperimentDiagnostics`).

## Regression coverage

`tests/RunSignalIntegrityWorkflowTest.m` includes `testBuildExampleDataFromSiExportProducesLoadableDataset`, which builds a MAT-file from synthetic tables (no Signal Integrity Toolbox license required) and runs `runSignalIntegrityWorkflow` in `real` mode.

For full SI-in-the-loop testing on your machine, run Serial Link Designer / kit exports manually and point `dataFile` at the generated MAT-file.
