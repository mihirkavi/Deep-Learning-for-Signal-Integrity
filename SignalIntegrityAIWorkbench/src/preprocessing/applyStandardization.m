function Xz = applyStandardization(X, mu, sigma)
%APPLYSTANDARDIZATION Apply training-time mu/sigma to new rows.
arguments
    X (:, :) double
    mu (1, :) double
    sigma (1, :) double
end

s = sigma;
s(s < 1e-12) = 1;
Xz = (X - mu) ./ s;
end
