function PlotEuropeScalingTime(src)
% Computation time vs number of aircraft (RunEuropeScaling), one log-log
% panel in the style of the BREST study figures.
%
%   PlotEuropeScalingTime                              % seeds folder if present
%   PlotEuropeScalingTime('exp_europe_scaling_seeds')  % mean +- 95% CI over seeds
%   PlotEuropeScalingTime('exp_europe_scaling.mat')    % a single sample
%
% Solid lines / filled markers: total computation time (ours: all best
% responses; centralized: MILP build + solve).  Dashed lines / hollow
% markers: time per agent for ours (total / number of agents).  With several
% seeds (one flight sample each) the line is the mean and the band the 95%
% confidence interval of the mean (t distribution), clipped above zero for
% the log axis.

if nargin < 1 || isempty(src)
    if isfolder('exp_europe_scaling_seeds'), src = 'exp_europe_scaling_seeds';
    else, src = 'exp_europe_scaling.mat'; end
end
if isfolder(src)
    f = dir(fullfile(src, 'seed_*.mat'));
    files = fullfile({f.folder}, {f.name});
    outStem = 'EuropeScalingTime';
else
    files = {src};
    [~, stem] = fileparts(src);
    outStem = regexprep(stem, '^exp_europe_scaling', 'EuropeScalingTime');
end
S = numel(files);
R = load(files{1}); n = R.ns(:); nN = numel(n);
T = nan(S, nN, 5);                 % k0 total, k1 total, MILP, k0 per agent, k1 per agent
for s = 1:S
    R = load(files{s});
    T(s,:,:) = reshape([R.brTotal(:,1), R.brTotal(:,2), R.milpTime, ...
                        R.brTotal(:,1)./R.nAgents(:), R.brTotal(:,2)./R.nAgents(:)], 1, nN, 5);
end
mu = squeeze(mean(T, 1, 'omitnan'));                       % nN x 5
if S > 1
    half = tinv(0.975, S-1) * squeeze(std(T, 0, 1, 'omitnan')) / sqrt(S);
else
    half = zeros(size(mu));
end
lo = max(mu - half, mu/20); hi = mu + half;                % keep the band positive on log axes

cK0 = [0.70 0.81 0.93]*0.85; cK1 = [0.09 0.28 0.56]; cM = [0.30 0.30 0.28];
colors = [cK0; cK1; cM; cK0; cK1];
markers = {'o', 's', 'd', 'o', 's'};
styles = {'-', '-', '-', '--', '--'};
labels = {'$\kappa = 0$ (total)', '$\kappa = 1$ (total)', '$\mathrm{Centralized}$', ...
          '$\kappa = 0$ (per agent)', '$\kappa = 1$ (per agent)'};
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36]; gridInk = [0.88 0.88 0.86];

fig = figure('Color','w','Position',[10 10 760 520]);
ax = axes(fig); hold(ax, 'on');
set(ax, 'XScale','log', 'YScale','log');
if S > 1
    for k = 1:5
        fill(ax, [n; flipud(n)], [lo(:,k); flipud(hi(:,k))], colors(k,:), 'FaceAlpha', 0.15, ...
             'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end
h = gobjects(1,5);
for k = 1:5
    if k <= 3, face = colors(k,:); edge = 'w'; lw = 1.8; ms = 8;
    else, face = 'w'; edge = colors(k,:); lw = 1.6; ms = 7; end
    h(k) = plot(ax, n, mu(:,k), [styles{k} markers{k}], 'Color', colors(k,:), 'LineWidth', lw, ...
                'MarkerSize', ms, 'MarkerFaceColor', face, 'MarkerEdgeColor', edge);
end
set(ax, 'XTick', n, 'XTickLabel', compose('%d', n), ...
        'TickLabelInterpreter','latex', 'FontSize', 13, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, 'Box','off', 'TickDir','out', 'Layer','top');
ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridColor = gridInk; ax.GridAlpha = 1;
ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
xlim(ax, [n(1)/1.4, n(end)*1.4]);
yl = [min(lo(:)), max(hi(:))];
ylim(ax, [10^floor(log10(yl(1))), 10^ceil(log10(yl(2)))]);
xlabel(ax, 'Number of aircraft', 'FontSize', 14, 'Color', inkPrimary);
ylabel(ax, 'Computation time [s]', 'FontSize', 14, 'Color', inkPrimary);
legend(ax, h, labels, 'Interpreter','latex', 'Location','northwest', 'Box','off', 'FontSize', 12);

exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 12);
exportgraphics(fig, [outStem '.png'], 'Resolution', 300, 'Padding', 12);
fprintf('wrote %s.pdf / %s.png (%d sample(s))\n', outStem, outStem, S);
end
