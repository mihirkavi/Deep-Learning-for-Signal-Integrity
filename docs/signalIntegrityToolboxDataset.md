# Signal Integrity Toolbox: dataset generation for this repository

This document ties **MathWorks Signal Integrity Toolbox** (Serial Link Designer, industry kits, exports) to the **fixed tensor layout** expected by [`+signalIntegrity/loadWorkflowData.m`](../+signalIntegrity/loadWorkflowData.m).

## Paper vs. bundled PDF

The cited paper is Lu, Wu, Yang, and Sun, *High-Speed Channel Modeling with Deep Neural Network for Signal Integrity Analysis* (EPEPS / IEEE TEMC). The models use:

- **Eye height:** 717 training and 476 validation samples; **14** input design parameters; target eye height in **mV** (paper range roughly 148–253 mV).
- **Eye width:** 509 training and 203 validation samples; **12** input design parameters; target eye width in **UI**.

The local `signalIntegrityReferencePaper.pdf` is a **short conference extract**. **Figure 1(b)** lists the physical design parameters, but the names appear **inside the figure graphic**, not as extractable text. For an authoritative list of parameter labels, use a full-text PDF of the paper or your own channel documentation.

Use [`signalIntegrity.paperFeatureReference`](../+signalIntegrity/paperFeatureReference.m) in MATLAB for counts, citation text, and **canonical column names** (`height_p01` … `height_p14`, `width_p01` … `width_p12`) that you can map to Serial Link Designer / kit sweep variables.

## Suggested mapping to Signal Integrity Toolbox (not from the paper text)

Until you transcribe Fig. 1(b), treat the 14 and 12 inputs as **ordered design vectors** and map them to quantities your kit exposes, for example:

| Index band | Typical serial-link meaning (Serial Link Designer / kits) |
|------------|------------------------------------------------------------|
| TX emphasis / de-emphasis | FIR or analog EQ taps, swing, slew |
| RX CTLE / DFE | Peaking, continuous-time zero/pole, DFE taps |
| Channel | Length, loss, via count, impedance offset, package models |
| Reference / jitter | Optional PJ/RJ placeholders if swept |

The exact physics must match **your** kit and rate; this table is only a **workflow hint**.

## Phase 1 — Operator workflow (minimal automation)

1. Open or create a **serial** project using [Get Started with Serial Link Designer](https://www.mathworks.com/help/signal-integrity/gs/get-started-with-serial-link-designer.html) or open a kit via [`openSignalIntegrityKit`](https://www.mathworks.com/help/signal-integrity/ref/opensignalintegritykit.html) (see [`scripts/openSignalIntegrityKitWorkflow.m`](../scripts/openSignalIntegrityKitWorkflow.m)).
2. Define a **design of experiments** (sweep) that varies the parameters you assign to the 14 (height) and 12 (width) columns. The height and width models in the paper use **different** sample counts; you may run **two sweeps** or one sweep with both targets if your flow exports both eye metrics per case.
3. Export results to **CSV** or MATLAB **table** with:
   - **Eye height file:** columns `height_p01` … `height_p14` plus `eyeHeight_mV` (or the names you pass into `buildExampleDataFromSiExport`).
   - **Eye width file:** columns `width_p01` … `width_p12` plus `eyeWidth_UI`.
4. Run [`signalIntegrity.buildExampleDataFromSiExport`](../+signalIntegrity/buildExampleDataFromSiExport.m) to produce `signalIntegrityExampleData.mat` in the canonical layout.

## Phase 2 — Scripted bridge

- **Kit download / open:** `openSignalIntegrityKit` (see script above).
- **MAT builder:** `signalIntegrity.buildExampleDataFromSiExport` — reads CSV/tables, applies a **reproducible shuffle + split** to match [`getExperimentCatalog`](../+signalIntegrity/getExperimentCatalog.m) train/validation counts.

## Waveform inputs for native SI eye diagrams

The DNN in this repository trains on **tabular feature vectors** and scalar targets, but the walkthrough can also show a **native Signal Integrity Toolbox eye diagram**. That eye figure uses a separate waveform source resolved by workflow options:

- `siWaveformSource`: `"auto"` (default), `"demo"`, `"user"`, or `"none"`.
- `siWaveformMatFile`: MAT or CSV file containing waveform samples when you want the eye plot to follow your own link export.
- `siWaveformVariable`: optional MAT variable name for the waveform vector.
- `siWaveformTimeVariable`: optional MAT variable name for the time vector.
- `siWaveformSampleInterval`: optional override when the file does not contain a time vector or sample interval.
- `siWaveformSymbolTime`: optional override for the unit interval / symbol time.
- `siWaveformSamplesPerSymbol`: default `16`; used when the walkthrough builds its deterministic demo waveform.

### Preferred MAT layout

Use a MAT-file with any of the following patterns:

1. `samples` plus `time`
2. `samples` plus `sampleInterval` and `symbolTime`
3. Your own variable names, together with `siWaveformVariable` and `siWaveformTimeVariable`

Example:

```matlab
samples = rxWaveform(:);
time = (0:numel(samples)-1)' * 2e-12;
symbolTime = 32e-12;
save("myEyeWaveform.mat", "samples", "time", "symbolTime");
```

Then in the walkthrough:

```matlab
workflowOptions = signalIntegrity.resolveWorkflowOptions();
workflowOptions.siWaveformMatFile = "myEyeWaveform.mat";
workflowOptions.siWaveformVariable = "samples";
workflowOptions.siWaveformTimeVariable = "time";
```

### CSV layout

- One column: waveform samples only, together with `siWaveformSampleInterval` and `siWaveformSymbolTime`
- Two columns: time in column 1, samples in column 2

If you do **not** provide a waveform file, the walkthrough falls back to a **deterministic demo waveform** so `eyeDiagramSI` can still render a native SI eye without requiring an external export.

## Dependencies

- **Training the DNN in this repo:** MATLAB + Deep Learning Toolbox only (see `signalIntegrity.buildToolboxStatusTable`).
- **Building datasets from MathWorks link simulations:** Signal Integrity Toolbox (and optionally SerDes / RF PCB depending on your flow) — see the toolbox status table for the current machine.

## Validating DNN predictions against SI Toolbox (hold-out)

See [signalIntegrityValidation.md](signalIntegrityValidation.md) for a short procedure: reserve rows, train on the rest, compare predicted eye metrics to simulation ground truth.
