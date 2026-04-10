%% Template for signal_integrity_example_data.mat
% Replace the placeholder arrays below with real simulation data before
% running the example in reference-data mode.
%
% Required MAT-file layout:
%   eyeHeight.XTrain [N1 x Fh]
%   eyeHeight.yTrain [N1 x 1]
%   eyeHeight.XVal   [N2 x Fh]
%   eyeHeight.yVal   [N2 x 1]
%   eyeWidth.XTrain  [M1 x Fw]
%   eyeWidth.yTrain  [M1 x 1]
%   eyeWidth.XVal    [M2 x Fw]
%   eyeWidth.yVal    [M2 x 1]
%
% Reference sizes used by the cited workflow:
%   N1 = 717, N2 = 476 for eye height
%   M1 = 509, M2 = 203 for eye width

clear; clc;

Fh = 14;
Fw = 12;

eyeHeight = struct();
eyeHeight.XTrain = zeros(717, Fh);
eyeHeight.yTrain = zeros(717, 1);
eyeHeight.XVal   = zeros(476, Fh);
eyeHeight.yVal   = zeros(476, 1);

eyeWidth = struct();
eyeWidth.XTrain = zeros(509, Fw);
eyeWidth.yTrain = zeros(509, 1);
eyeWidth.XVal   = zeros(203, Fw);
eyeWidth.yVal   = zeros(203, 1);

save('signal_integrity_example_data.mat', 'eyeHeight', 'eyeWidth');
fprintf('Created signal_integrity_example_data.mat. Replace the zeros with real simulation data and save again.\n');
