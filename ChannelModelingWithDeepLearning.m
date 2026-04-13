%% Deep Learning for High-Speed Channel Modeling
% This example trains a neural network to predict eye height from channel
% design parameters, then visualizes how the eye diagram evolves as the
% network learns — and compares the worst and best channel designs.
%
% Toolboxes used:
%   Deep Learning Toolbox    — trainnet, trainingOptions, dlnetwork
%   Communications Toolbox   — comm.RaisedCosineTransmitFilter, awgn
%   Signal Processing Toolbox — fir1, filter

%% Setup

clearvars; close all; clc;
rng(46433, "twister");

%% Generate Synthetic Channel Dataset  (Deep Learning Toolbox)
% Reproduces the sample counts and target range from Lu et al.:
%   717 training samples, 476 validation samples, 14 design parameters,
%   eye height range 148–253 mV.

[XTrain, YTrain, XVal, YVal] = generateSyntheticData( ...
    717, 476, 14, [148 253], [32 24 16], 46433, 2.8);

[XTrain_n, mu, sigma] = normalize(XTrain);
XVal_n = (XVal - mu) ./ sigma;

%% Build Network  (Deep Learning Toolbox)
% Feedforward network: 14 inputs → [100 → 300 → 200] → 1 output (tanh activations)

net = dlnetwork([
    featureInputLayer(14, Normalization="none")
    fullyConnectedLayer(100)
    tanhLayer
    fullyConnectedLayer(300)
    tanhLayer
    fullyConnectedLayer(200)
    tanhLayer
    fullyConnectedLayer(1)]);

%% Pre-generate Base NRZ Waveform  (Communications Toolbox + Signal Processing Toolbox)
% All eye diagrams use the same underlying symbol sequence so that the only
% thing that changes across training snapshots is the predicted noise level.

sps      = 32;        % samples per symbol
nSymbols = 4000;      % waveform length in symbols

txFilt   = comm.RaisedCosineTransmitFilter( ...
    RolloffFactor=0.3, FilterSpanInSymbols=8, ...
    OutputSamplesPerSymbol=sps, Gain=1);
delay    = txFilt.FilterSpanInSymbols / 2 * sps;

rawBits  = 2*randi([0 1], nSymbols + txFilt.FilterSpanInSymbols, 1) - 1;
baseSig  = txFilt(rawBits);
baseSig  = baseSig(delay+1 : delay+nSymbols*sps);

% Apply bandwidth-limiting channel (Signal Processing Toolbox)
chanFilter = fir1(32, 0.4);
baseSig    = filter(chanFilter, 1, baseSig);
baseSig    = baseSig ./ max(abs(baseSig));   % normalize to ±1

%% Figure 1 — Eye Diagram Evolving During Training
% Train in cumulative stages. At each snapshot, use the network's current
% prediction to set the SNR of the synthesized waveform. As the prediction
% converges to the true eye height, the eye diagram converges too.

snapEpochs = [0, 2, 10, 50, 200];           % cumulative epoch milestones

% Track a representative design (median eye height in validation set)
[~, ord] = sort(YVal);
trackIdx  = ord(round(numel(YVal)/2));
trueH     = YVal(trackIdx);

fig1 = figure(Color="w", Name="Eye Diagram: Training Progress");
tl1  = tiledlayout(fig1, 1, numel(snapEpochs), ...
    TileSpacing="compact", Padding="compact");
title(tl1, "Predicted Eye Diagram Across Training Epochs", FontSize=11, FontWeight="bold");
subtitle(tl1, sprintf("Tracking design with true eye height = %.0f mV", trueH), FontSize=9);

for k = 1:numel(snapEpochs)

    % Train for the incremental epochs at this stage
    if k > 1
        nEpochs = snapEpochs(k) - snapEpochs(k-1);
        opts = trainingOptions("adam", ...
            MaxEpochs           = nEpochs, ...
            MiniBatchSize       = 25, ...
            InitialLearnRate    = 0.001, ...
            GradientThreshold   = 5, ...
            GradientThresholdMethod = "l2norm", ...
            Shuffle             = "every-epoch", ...
            Plots               = "none", ...
            Verbose             = false);
        net = trainnet(XTrain_n, YTrain, net, "mse", opts);
    end

    % Predict eye height for tracked design, synthesize waveform
    predH = double(minibatchpredict(net, XVal_n(trackIdx, :)));
    wave  = applyNoise(baseSig, predH, [148 253]);

    % Plot eye diagram
    ax = nexttile(tl1);
    plotEye(ax, wave, sps);
    if k == 1
        title(ax, sprintf("Before Training\nPred: %.0f mV", predH), FontSize=9);
    else
        title(ax, sprintf("Epoch %d\nPred: %.0f mV", snapEpochs(k), predH), FontSize=9);
    end
end

%% Figure 2 — Channel Before and After Design Optimization
% The trained network ranks all validation designs by predicted eye height.
% The worst design (lowest predicted height) represents an unoptimized channel.
% The best design (highest predicted height) shows the result after using
% the surrogate model to guide design selection.

allPred  = double(minibatchpredict(net, XVal_n));
[~, iLo] = min(allPred);
[~, iHi] = max(allPred);

fig2 = figure(Color="w", Name="Channel: Before and After Optimization");
tl2  = tiledlayout(fig2, 1, 2, TileSpacing="loose", Padding="compact");
title(tl2, "High-Speed Channel: Before and After Design Optimization", ...
    FontSize=11, FontWeight="bold");

nexttile(tl2);
plotEye(gca, applyNoise(baseSig, YVal(iLo), [148 253]), sps);
title(sprintf("Before Optimization\nEye Height = %.0f mV", YVal(iLo)), FontSize=10);

nexttile(tl2);
plotEye(gca, applyNoise(baseSig, YVal(iHi), [148 253]), sps);
title(sprintf("After Optimization\nEye Height = %.0f mV", YVal(iHi)), FontSize=10);

%% Local Functions

function wave = applyNoise(baseSig, eyeHeight_mV, heightRange)
%applyNoise  Add AWGN scaled to reflect the predicted eye height.
%   Higher eye height → higher SNR → wider eye opening.
%   Uses awgn from Communications Toolbox.
    alpha = max(0.02, min(0.98, ...
        (eyeHeight_mV - heightRange(1)) / diff(heightRange)));
    snrDb = 4 + 24 * alpha;          % 4 dB at min height → 28 dB at max
    wave  = awgn(baseSig, snrDb, "measured");
end

function plotEye(ax, wave, sps)
%plotEye  Overlay symbol-period traces to render an eye diagram.
    nT     = floor(numel(wave) / sps);
    traces = reshape(wave(1:nT*sps), sps, nT);
    t_ui   = linspace(0, 1, sps);
    cla(ax);
    plot(ax, t_ui, traces, Color=[0.09 0.47 0.70 0.07], LineWidth=0.6);
    xlim(ax, [0 1]);  ylim(ax, [-1.5 1.5]);
    xlabel(ax, "Unit Interval (UI)");  ylabel(ax, "Amplitude");
    grid(ax, "on");   box(ax, "on");
end

function [XTrain, YTrain, XVal, YVal] = generateSyntheticData( ...
        nTrain, nVal, nFeat, targetRange, teacherSizes, seed, noiseStd)
%generateSyntheticData  Deterministic synthetic regression dataset.

    XTrain = randn(nTrain, nFeat);
    XVal   = randn(nVal,   nFeat);

    saved = rng(seed, "twister");
    cl    = onCleanup(@() rng(saved));
    ls    = [nFeat, teacherSizes, 1];
    W = cell(numel(ls)-1, 1);
    b = cell(numel(ls)-1, 1);
    for k = 1:numel(W)
        W{k} = (0.25/sqrt(ls(k))) * randn(ls(k), ls(k+1));
        b{k} = 0.02 * randn(1, ls(k+1));
    end
    clear cl;

    YTrain = teacherFwd(XTrain, W, b);
    YVal   = teacherFwd(XVal,   W, b);
    allY   = rescale([YTrain; YVal], targetRange(1), targetRange(2));
    allY   = min(max(allY + noiseStd*randn(size(allY)), ...
                 targetRange(1)), targetRange(2));
    YTrain = allY(1:nTrain);
    YVal   = allY(nTrain+1:end);
end

function Y = teacherFwd(X, W, b)
    A = X;
    for k = 1:numel(W)-1
        A = tanh(A * W{k} + b{k});
    end
    Y = A * W{end} + b{end};
end
