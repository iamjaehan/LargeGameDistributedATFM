function PlotEuropeScalingTime(matFile)
% Computation time vs number of aircraft (RunEuropeScaling), one log-log
% panel in the style of the BREST study figures: kappa ramp end points for
% ours, dark grey for the centralized MILP, LaTeX ticks, light grid, no title.
% Ours: total time of all best responses (solid) and that total divided by the
% number of agents (dashed, computation per agent).  Centralized: MILP build + solve.
% One deterministic run per n, so no error bars.
%
%   PlotEuropeScalingTime                     % reads exp_europe_scaling.mat

if nargin < 1 || isempty(matFile), matFile = 'exp_europe_scaling.mat'; end
R = load(matFile);
n = R.ns(:);
T = [R.brTotal(:,1), R.brTotal(:,2), R.milpTime];
Tagent = [R.brTotal(:,1), R.brTotal(:,2)] ./ R.nAgents(:);   % ours: computation per agent

cK0 = [0.70 0.81 0.93]*0.85; cK1 = [0.09 0.28 0.56]; cM = [0.30 0.30 0.28];
colors = [cK0; cK1; cM];
markers = {'o', 's', 'd'};
labels = {'$\kappa = 0$ (total)', '$\kappa = 1$ (total)', '$\mathrm{Centralized}$', ...
          '$\kappa = 0$ (per agent)', '$\kappa = 1$ (per agent)'};
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36]; gridInk = [0.88 0.88 0.86];

fig = figure('Color','w','Position',[10 10 760 520]);
ax = axes(fig); hold(ax, 'on');
h = gobjects(1,5);
for k = 1:3
    h(k) = plot(ax, n, T(:,k), ['-' markers{k}], 'Color', colors(k,:), 'LineWidth', 1.8, ...
                'MarkerSize', 8, 'MarkerFaceColor', colors(k,:), 'MarkerEdgeColor', 'w');
end
for k = 1:2      % dashed, hollow markers: time per agent (total / number of agents)
    h(3+k) = plot(ax, n, Tagent(:,k), ['--' markers{k}], 'Color', colors(k,:), 'LineWidth', 1.6, ...
                  'MarkerSize', 7, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors(k,:));
end
set(ax, 'XScale','log', 'YScale','log', 'XTick', n, 'XTickLabel', compose('%d', n), ...
        'TickLabelInterpreter','latex', 'FontSize', 13, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, 'Box','off', 'TickDir','out', 'Layer','top');
ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridColor = gridInk; ax.GridAlpha = 1;
ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
xlim(ax, [n(1)/1.4, n(end)*1.4]);
yl = [min([T(:); Tagent(:)]), max(T(:))];
ylim(ax, [10^floor(log10(yl(1))), 10^ceil(log10(yl(2)))]);
xlabel(ax, 'Number of aircraft', 'FontSize', 14, 'Color', inkPrimary);
ylabel(ax, 'Computation time [s]', 'FontSize', 14, 'Color', inkPrimary);
legend(ax, h, labels, 'Interpreter','latex', 'Location','northwest', 'Box','off', 'FontSize', 13);

[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_europe_scaling', 'EuropeScalingTime');
exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 12);
exportgraphics(fig, [outStem '.png'], 'Resolution', 300, 'Padding', 12);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);
end
