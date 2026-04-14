%% Deep Learning for High-Speed Channel Modeling — Physics-Informed
%
% A neural network surrogate learns to predict eye height from SerDes
% design parameters.  Training is physics-informed: every gradient step
% calls the SerDes Toolbox as a live physics oracle — no pre-generated
% dataset needed.
%
% TX → Channel → RX pipeline
%   TX FFE  — Feed-Forward Equalizer              (SerDes Toolbox)
%   Channel — Frequency-dependent insertion loss   (SerDes Toolbox)
%   RX CTLE — Continuous-Time Linear Equalizer     (SerDes Toolbox)
%
% Toolboxes
%   SerDes Toolbox          — serdes.ChannelLoss, serdes.FFE, serdes.CTLE,
%                             impulse2pulse, optPulseMetric, pulse2stateye
%   Deep Learning Toolbox   — dlnetwork, dlfeval, dlgradient, adamupdate
%   Signal Processing Toolbox — freqz

%% Setup

clearvars; close all; clc;
rng(42, "twister");

%% SerDes System Constants

UI = 100e-12;          % symbol period  (10 Gbaud NRZ)
N  = 32;               % oversampling ratio (samples per UI)
dt = UI / N;           % sample interval
BER_TARGET = 1e-6;     % BER used by optPulseMetric

% Six design parameters — stored normalised to [0, 1] inside the network.
% Row layout: [physical_min, physical_max]
paramBounds = [
     5,  20;    % 1  channelLoss_dB        (dB)
    -0.2,  0;   % 2  ffePre                (tap weight)
     0.6,  0.9; % 3  ffeMain               (tap weight)
   -15,    0;   % 4  ctleDCGain            (dB)
     0,   12;   % 5  ctlePeakGain          (dB)
     4,   10];  % 6  ctlePeakFreq_GHz      (GHz)

nFeat = size(paramBounds, 1);

%% Build Neural Network  (Deep Learning Toolbox)
% 6 inputs → [64 → 128 → 64] → 1 output (eye height in mV)

net = dlnetwork([
    featureInputLayer(nFeat, Normalization="none")
    fullyConnectedLayer(64)
    tanhLayer
    fullyConnectedLayer(128)
    tanhLayer
    fullyConnectedLayer(64)
    tanhLayer
    fullyConnectedLayer(1)]);

%% Pre-generate Validation Set  (SerDes Toolbox)
% 40 random designs — each evaluated once up front for ground-truth labels.

nVal = 40;
fprintf('Generating %d validation samples via SerDes simulation...\n', nVal);
XVal = rand(nVal, nFeat);
YVal = zeros(nVal, 1);
for i = 1:nVal
    [~, YVal(i)] = runSerDes(XVal(i,:), paramBounds, UI, N, dt, BER_TARGET);
    if mod(i, 10) == 0
        fprintf('  %d/%d  (range so far: %.0f–%.0f mV)\n', ...
            i, nVal, min(YVal(1:i)), max(YVal(1:i)));
    end
end
fprintf('Done.  Eye-height range: %.0f – %.0f mV\n\n', min(YVal), max(YVal));

%% Physics-Informed Training  (Deep Learning Toolbox + SerDes Toolbox)
%
% At each iteration:
%   1. Sample a random mini-batch of design parameters
%   2. Call SerDes Toolbox to evaluate eye height (physics oracle)
%   3. Compute MSE gradient through the network and apply Adam update
%
% The SerDes simulation IS the cost function — the network learns the
% physics without ever seeing a pre-built dataset.

batchSize = 4;
snapIters = [0, 10, 25, 50, 100];   % 0 = before any training
learnRate = 0.005;

avgGrad   = [];
avgSqGrad = [];
itersDone = 0;

% Track the median-quality validation design across snapshots
[~, trackIdx] = min(abs(YVal - median(YVal)));
trueH = YVal(trackIdx);

%% Figure 1 — Eye Diagram + Frequency Response During Training

fig1 = figure(Color="w", Name="PINN Training Progress");
tl1  = tiledlayout(fig1, 2, numel(snapIters), ...
    TileSpacing="compact", Padding="compact");
title(tl1, "Physics-Informed Neural Network: TX → Channel → RX Evolution", ...
    FontSize=11, FontWeight="bold");
subtitle(tl1, sprintf( ...
    "Tracking design (true eye height = %.0f mV) | SerDes oracle at every gradient step", ...
    trueH), FontSize=9);

for si = 1:numel(snapIters)

    % ── Train incrementally to this milestone ────────────────────────────
    while itersDone < snapIters(si)
        Xb = rand(batchSize, nFeat);
        Yb = zeros(batchSize, 1);
        for j = 1:batchSize
            [~, Yb(j)] = runSerDes(Xb(j,:), paramBounds, UI, N, dt, BER_TARGET);
        end

        Xdl = dlarray(single(Xb'), "CB");
        Ydl = dlarray(single(Yb'), "CB");
        [~, grads] = dlfeval(@modelLoss, net, Xdl, Ydl);

        itersDone = itersDone + 1;
        [net.Learnables, avgGrad, avgSqGrad] = adamupdate( ...
            net.Learnables, grads, avgGrad, avgSqGrad, itersDone, learnRate);
    end

    % ── Snapshot: predict + run SerDes for the tracked design ────────────
    predH = double(extractdata( ...
        forward(net, dlarray(single(XVal(trackIdx,:)'), "CB"))));
    [impSnap, ~] = runSerDes(XVal(trackIdx,:), paramBounds, UI, N, dt, BER_TARGET);

    if snapIters(si) == 0
        panelLabel = sprintf("Before Training\nPred: %.0f mV", predH);
    else
        panelLabel = sprintf("Iter %d\nPred: %.0f mV", snapIters(si), predH);
    end

    % Top row: TX→Ch→RX frequency response
    ax_f = nexttile(tl1, si);
    plotFreqResp(ax_f, impSnap, dt);
    title(ax_f, panelLabel, FontSize=8);

    % Bottom row: eye diagram from SerDes pulse
    ax_e = nexttile(tl1, numel(snapIters) + si);
    plotEyeDiagram(ax_e, impSnap, N, dt);
end

%% Figure 2 — SerDes Link Setup: Before and After Design Optimisation
% The trained surrogate ranks all validation designs by predicted eye height.
% Worst prediction → unoptimised design.  Best prediction → optimised design.

allPred = zeros(nVal, 1);
for i = 1:nVal
    allPred(i) = double(extractdata( ...
        forward(net, dlarray(single(XVal(i,:)'), "CB"))));
end
[~, iLo] = min(allPred);
[~, iHi] = max(allPred);

% Resolve physical parameters for both designs
lo_b = paramBounds(:,1)'; hi_b = paramBounds(:,2)';
pLo  = XVal(iLo,:) .* (hi_b - lo_b) + lo_b;
pHi  = XVal(iHi,:) .* (hi_b - lo_b) + lo_b;
[impLo, eyeLo] = runSerDes(XVal(iLo,:), paramBounds, UI, N, dt, BER_TARGET);
[impHi, eyeHi] = runSerDes(XVal(iHi,:), paramBounds, UI, N, dt, BER_TARGET);

fig2 = figure(Color="w", Name="SerDes Link: Before and After Optimisation", ...
    Position=[100 100 1100 620]);
tl2  = tiledlayout(fig2, 3, 2, TileSpacing="loose", Padding="compact");
title(tl2, "TX → Channel → RX Link: Before and After Design Optimisation", ...
    FontSize=11, FontWeight="bold");

% Row 1: SerDes link block diagram for each design
for col = 1:2
    p   = [pLo; pHi];  p = p(col,:);
    lbl = ["Before Optimisation", "After Optimisation"];
    eyeH_show = [eyeLo eyeHi];

    ax = nexttile(tl2, col);
    plotLinkDiagram(ax, p, eyeH_show(col));
    title(ax, lbl(col), FontSize=10, FontWeight="bold");
end

% Row 2: Frequency response (cascaded TX→Ch→RX)
nexttile(tl2, 3);
plotFreqResp(gca, impLo, dt);
title("Frequency Response — Before", FontSize=9);

nexttile(tl2, 4);
plotFreqResp(gca, impHi, dt);
title("Frequency Response — After", FontSize=9);

% Row 3: Eye diagram
nexttile(tl2, 5);
plotEyeDiagram(gca, impLo, N, dt);
title(sprintf("Eye Diagram — Before  (%.0f mV)", eyeLo), FontSize=9);

nexttile(tl2, 6);
plotEyeDiagram(gca, impHi, N, dt);
title(sprintf("Eye Diagram — After  (%.0f mV)", eyeHi), FontSize=9);

%% ── Local Functions ──────────────────────────────────────────────────────────

function plotLinkDiagram(ax, p, eyeH_mV)
%plotLinkDiagram  Draw the TX→Channel→RX block diagram annotated with
%   the physical parameter values for one design point.
%
%   p = [chanLoss_dB, ffePre, ffeMain, ctleDCGain_dB, ctlePeakGain_dB, ctlePeakFreq_GHz]

    cla(ax); axis(ax, "off");
    hold(ax, "on");

    % Layout: blocks at x = 0.05, 0.38, 0.72  width=0.22  height=0.38
    bx = [0.05, 0.38, 0.72];
    bw = 0.22;  bh = 0.38;  by = 0.31;
    colors = {[0.18 0.55 0.34], [0.16 0.44 0.70], [0.80 0.36 0.12]};
    labels = {"TX FFE", "Channel", "RX CTLE"};

    % Parameter text under each block
    paramText = {
        sprintf("Pre  = %.2f\nMain = %.2f\nPost = %.2f", ...
            p(2), p(3), max(0, 1 - p(3) - abs(p(2))))
        sprintf("Loss = %.0f dB\n@ Nyquist", p(1))
        sprintf("DC  = %.0f dB\nPeak = %.0f dB\n@ %.0f GHz", p(4), p(5), p(6))
    };

    for k = 1:3
        % Block rectangle
        rectangle(ax, "Position", [bx(k), by, bw, bh], ...
            "FaceColor", colors{k}, "EdgeColor", "none", "Curvature", 0.15);
        % Block label (white, bold)
        text(ax, bx(k)+bw/2, by+bh/2, labels{k}, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "middle", ...
            "Color", "w", "FontSize", 10, "FontWeight", "bold");
        % Parameter annotation below block
        text(ax, bx(k)+bw/2, by-0.08, paramText{k}, ...
            "HorizontalAlignment", "center", "VerticalAlignment", "top", ...
            "FontSize", 7.5, "Color", [0.2 0.2 0.2], "Interpreter", "none");
    end

    % Arrows between blocks
    arrowY = by + bh/2;
    arrowX = [bx(1)+bw, bx(2); bx(2)+bw, bx(3)];
    for k = 1:2
        plot(ax, arrowX(k,:), [arrowY arrowY], "k-", "LineWidth", 1.5);
        plot(ax, arrowX(k,2), arrowY, "k>", "MarkerSize", 6, "MarkerFaceColor", "k");
    end

    % Source (left) and sink (right) labels
    text(ax, bx(1)-0.04, arrowY, "NRZ\nBits", ...
        "HorizontalAlignment", "center", "FontSize", 8, "Color", [0.4 0.4 0.4]);
    text(ax, bx(3)+bw+0.05, arrowY, sprintf("Eye\n%.0f mV", eyeH_mV), ...
        "HorizontalAlignment", "center", "FontSize", 8, "FontWeight", "bold", ...
        "Color", [0.6 0.1 0.1]);

    % Left and right stub lines
    plot(ax, [bx(1)-0.07 bx(1)], [arrowY arrowY], "k-", "LineWidth", 1.5);
    plot(ax, [bx(3)+bw bx(3)+bw+0.07], [arrowY arrowY], "k-", "LineWidth", 1.5);

    xlim(ax, [0 1]);  ylim(ax, [0 1]);
    hold(ax, "off");
end


function [imp, eyeH_mV] = runSerDes(params01, bounds, UI, N, dt, ber)
%runSerDes  Simulate TX FFE → Channel → RX CTLE using SerDes Toolbox.
%
%   params01  — 1×6 row, each element in [0,1]
%   bounds    — 6×2 [min max] in physical units
%   Returns combined impulse response and eye height (mV).

    lo = bounds(:,1)'; hi = bounds(:,2)';
    p  = params01 .* (hi - lo) + lo;     % physical units

    % FFE tap design: pre + main + post, normalised to unit gain
    ffePre  = p(2);
    ffeMain = p(3);
    ffePost = max(0, 1 - ffeMain - abs(ffePre));
    s       = abs(ffePre) + ffeMain + ffePost;
    ffeTaps = [ffePre ffeMain ffePost] / s;

    % Channel insertion loss  (SerDes Toolbox)
    ch  = serdes.ChannelLoss('Loss', p(1), 'dt', dt, ...
                              'TargetFrequency', 1/(2*UI));

    % TX Feed-Forward Equalizer  (SerDes Toolbox)
    ffe = serdes.FFE('Mode', 1, 'WaveType', 'Impulse', ...
                     'TapWeights', ffeTaps, ...
                     'SymbolTime', UI, 'SampleInterval', dt);

    % RX Continuous-Time Linear Equalizer  (SerDes Toolbox)
    ctle = serdes.CTLE('Mode', 2, 'WaveType', 'Impulse', ...
                       'DCGain', p(4), 'PeakingGain', p(5), ...
                       'PeakingFrequency', p(6)*1e9, ...
                       'SymbolTime', UI, 'SampleInterval', dt);

    % Cascade: Channel → TX FFE → RX CTLE
    imp = ch.impulse;
    imp = ffe(imp);
    [imp, ~] = ctle(imp);

    % Eye-height metric  (SerDes Toolbox)
    pulse   = impulse2pulse(imp, N, dt);
    metrics = optPulseMetric(pulse, N, dt, ber);
    eyeH_mV = max(0, metrics.maxEyeHeight * 1000);   % V → mV
end

% ─────────────────────────────────────────────────────────────────────────────

function [loss, gradients] = modelLoss(net, X, T)
%modelLoss  MSE loss and gradients w.r.t. network learnables.
    Y         = forward(net, X);
    loss      = mean((Y - T).^2, "all");
    gradients = dlgradient(loss, net.Learnables);
end

% ─────────────────────────────────────────────────────────────────────────────

function plotFreqResp(ax, imp, dt)
%plotFreqResp  Magnitude response of the cascaded TX→Ch→RX impulse.
%   Uses Signal Processing Toolbox freqz.
    [H, f] = freqz(imp, 1, 512, 1/dt);
    f_GHz  = f / 1e9;
    fMax   = min(20, 1/(2*dt*1e9));   % cap at 20 GHz for readability
    plot(ax, f_GHz, 20*log10(abs(H) + eps), "LineWidth", 1.2, "Color", [0.09 0.47 0.70]);
    xlabel(ax, "Frequency (GHz)");
    ylabel(ax, "|H| (dB)");
    xlim(ax, [0, fMax]);
    ylim(ax, [-60, 5]);
    grid(ax, "on");
    box(ax, "on");
end

% ─────────────────────────────────────────────────────────────────────────────

function plotEyeDiagram(ax, imp, N, dt)
%plotEyeDiagram  Render eye diagram density from pulse2stateye.
%   Uses SerDes Toolbox pulse2stateye for the statistical eye.
    pulse        = impulse2pulse(imp, N, dt);
    [se, vh, th] = pulse2stateye(pulse, N, 2);
    imagesc(ax, th, vh * 1000, se);
    set(ax, "YDir", "normal");
    colormap(ax, flipud(bone));
    xlabel(ax, "Unit Interval (UI)");
    ylabel(ax, "Amplitude (mV)");
    xlim(ax, [0.5 1.5]);   % show central eye (pulse2stateye spans 2 UI)
end
