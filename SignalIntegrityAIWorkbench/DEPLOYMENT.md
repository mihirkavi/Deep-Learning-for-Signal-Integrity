# Deployment notes — Signal Integrity AI Workbench

## MATLAB Compiler (desktop)

1. Open **Application Compiler** (`applicationCompiler`).
2. Add a main file: `launchSignalIntegrityAIWorkbench.m` **or** a small wrapper that only calls `SignalIntegrityAIWorkbenchApp(projectRoot)`.
3. Include **Additional files/folders**:
   - Entire `SignalIntegrityAIWorkbench` tree (so `src/` and `data/` resolve next to the runtime).
4. Set the **Splash screen / icon** via the compiler UI (place assets under `resources/` if you add branding files).
5. Build — the installer bundles the MATLAB Runtime.

**Path resolution:** The app resolves `projectRoot` from `SignalIntegrityAIWorkbenchApp`’s location. For compiled apps, ensure the deployed folder layout mirrors development (keep `data/` writable next to the executable).

## MATLAB Web App Server

- Web apps expect a single entry function without blocking `uifigure` in unsupported configurations. Test your target release: `uifigure`-based apps are supported for **local desktop** first; Web App Server packaging may require refactoring the entry to a function `function out = siWorkbenchWeb()` that instantiates the app and returns the figure handle per MathWorks docs for your release.
- Avoid `uigetfile` in fully automated server contexts; replace with fixed paths or upload APIs.

## `.mlappinstall` (MATLAB App Installer)

1. In MATLAB **Apps** tab → **Package App**.
2. Select the main file (`SignalIntegrityAIWorkbenchApp.m` or launcher).
3. Fill metadata and install locally for smoke testing.

## Toolbox manifest for IT

Minimum for full functionality:

- MATLAB  
- Deep Learning Toolbox  
- Statistics and Machine Learning Toolbox  

Optional: Parallel Computing Toolbox, MATLAB Report Generator.

## Security / data

Training data and exports are **local** under `data/`. Do not commit customer CSVs to Git; add paths to `.gitignore` if you mirror production datasets into the tree.
