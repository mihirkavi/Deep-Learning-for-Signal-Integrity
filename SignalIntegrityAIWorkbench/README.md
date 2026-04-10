# Signal Integrity AI Workbench

Production-style MATLAB desktop application for **surrogate modeling** of high-speed channel **eye height** and **eye width** from nine design parameters (TX/RX equalization, jitter, trace geometry, substrate). The workflow is inspired by Lu et al., *High-Speed Channel Modeling with Deep Neural Network for Signal Integrity Analysis*, and packaged as a **B2B-grade** dark dashboard.

## Requirements

- MATLAB R2021a or newer (tested patterns use `arguments` blocks and modern `uigridlayout`).
- **Deep Learning Toolbox** — for feedforward surrogate training (`trainNetwork`).
- **Statistics and Machine Learning Toolbox** — for boosted trees (`fitrensemble`) and optional GPR (`fitrgp`).
- Optional: **Parallel Computing Toolbox** (enable parallel training in `trainingOptions` if you extend the trainer), **MATLAB Report Generator** (HTML reports work without it; PDF upgrade path noted in code).

## Quick start

```matlab
cd SignalIntegrityAIWorkbench
startup_SignalIntegrityAIWorkbench
launchSignalIntegrityAIWorkbench
```

Or from any folder:

```matlab
run("/path/to/SignalIntegrityAIWorkbench/launchSignalIntegrityAIWorkbench.m")
```

First-time use:

1. Open **Dataset Manager** → **Load demo data** (creates `data/datasets/demo_dataset.csv` if needed).
2. Open **Model Training Lab** → choose **linear** for a fast sanity check, or **deep** for neural surrogate → **Train both targets**.
3. Use **Single Prediction**, **Parameter Sweep**, and **Compare Designs** with the trained bundle stored at `data/saved_models/default_bundle.mat`.

## Project layout

| Path | Purpose |
|------|---------|
| `app/SignalIntegrityAIWorkbenchApp.m` | Main `uifigure` app (App Designer–style class; see note below) |
| `src/models`, `src/preprocessing`, `src/analysis`, `src/reporting`, `src/utils` | Modular backend |
| `data/saved_models`, `data/datasets`, `data/exports`, `data/saved_studies` | Runtime artifacts (created on startup) |
| `tests/WorkbenchUnitTests.m` | `matlab.unittest` suite |
| `runWorkbenchTests.m` | Convenience test runner |
| `tools/captureWorkbenchScreenshotHelper.m` | Lightweight PNG placeholder for decks |

## App Designer (`.mlapp`)

Binary `.mlapp` files cannot be generated as plain text in version control. This project ships a **fully programmatic** app class (`SignalIntegrityAIWorkbenchApp.m`) that follows the same architecture App Designer exports (figure + `uigridlayout` + tabbed workflow). You can:

- Continue maintaining the `.m` class directly (recommended for Git-friendly review), or  
- Create a new App Designer app and **copy UI layout/callback ideas** from this class, or  
- Use **Application Compiler** on `launchSignalIntegrityAIWorkbench` / the app class entry point (see `DEPLOYMENT.md`).

## Tests

```matlab
cd SignalIntegrityAIWorkbench
results = runWorkbenchTests;
```

Or:

```matlab
runtests(fullfile(pwd, "SignalIntegrityAIWorkbench", "tests"))
```

## Feature columns (schema)

Nine predictors (CSV/MAT tables must include these names):

`tx_preemphasis_dB`, `tx_jitter_ps`, `trace_width_um`, `trace_spacing_um`, `substrate_thickness_mil`, `er`, `tan_delta`, `rx_eq_dB`, `rx_jitter_ps`

Targets: `eyeHeight_mV`, `eyeWidth_UI`

## Disclaimer

Surrogate models are **not** a substitute for full electromagnetic / link simulation for sign-off. Use **Validation / Metrics** and engineering judgment; the UI surfaces **extrapolation** warnings when inputs leave the training envelope.
