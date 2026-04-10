function [Xz, mu, sigma] = standardizeFeatures(X)
%STANDARDIZEFEATURES Z-score using column means and sample std (training only).
arguments
    X (:, :) double
end

mu = mean(X, 1);
sigma = std(X, 0, 1);
sigma(sigma < 1e-12) = 1;
Xz = (X - mu) ./ sigma;
end
