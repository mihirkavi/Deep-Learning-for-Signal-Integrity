%% Signal Integrity Modeling Runner
% Compact runner for the shared workflow. For the presentation-oriented
% version, open `signal_integrity_modeling_example.m`.

clear; clc; close all;

config = struct();
config.dataFile = "signal_integrity_example_data.mat";
config.makePlots = usejava("desktop");
config.verbose = true;

results = signal_integrity_modeling_core(config);
disp(results.summaryTable);
