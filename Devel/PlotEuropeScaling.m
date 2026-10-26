function PlotEuropeScaling(matFile)
% Scalability study on the European dataset (RunEuropeScaling).
%
%   PlotEuropeScaling                       % reads exp_europe_scaling.mat
%
% (a) final overload / initial overload vs number of aircraft.  Normalised
%     like the BREST study, so 1 is "no reduction"; n with no initial
%     overload (n = 10) has no ratio and is left out.
% (b) computation time vs number of aircraft, log-log.  Ours: total time of
%     all best responses (the parallel time, slowest sector per round, is
%     nearly the same here and is in the .mat).  MILP: build + solve.
% Colours as in the BREST figures (kappa ramp end points, dark grey for the
% centralized MILP); every series also has its own marker.

if nargin < 1 || isempty(matFile), matFile = 'exp_europe_scaling.mat'; end
R = load(matFile);
n = R.ns(:);
ratio = R.overload ./ R.initialOverload;          % n x 3 (kappa 0, kappa 1, MILP)
ratio(R.initialOverload == 0, :) = NaN;
time = [R.brTotal(:,1), R.brTotal(:,2), R.milpTime];

cK0 = [0.70 0.81 0.93]; cK1 = [0.09 0.28 0.56]; cM = [0.30 0.30 0.28];
colors = [cK0*0.85; cK1; cM];                      % kappa 0 darkened a touch for line contrast
markers = {'o', 's', 'd'};
labels = {'$\kappa = 0$', '$\kappa = 1$', '$\mathrm{Centralized}$'};
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36]; gridInk = [0.88 0.88 0.86];
cInit = [0.84 0.47 0.44];

fig = figure('Color','w','Position',[10 10 1400 500]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.98 1];

ax1 = nexttile(tl); hold(ax1, 'on');
yline(ax1, 1, '--', 'no reduction', 'Color', cInit, 'LineWidth', 1.1, 'FontSize', 11, ...
      'LabelHorizontalAlignment','right', 'LabelVerticalAlignment','bottom', 'HandleVisibility','off');
h1 = DrawSeries(ax1, n, ratio, colors, markers);
set(ax1, 'XScale', 'log'); ylim(ax1, [-0.06 1.4]);   % headroom for the legend
ylabel(ax1, 'Overload cost / initial  [-]', 'FontSize', 14, 'Color', inkPrimary);
Style(ax1, n, gridInk, inkPrimary, inkSecondary);
legend(ax1, h1, labels, 'Interpreter','latex', 'Location','northwest', 'Box','off', 'FontSize', 12);

ax2 = nexttile(tl); hold(ax2, 'on');
h2 = DrawSeries(ax2, n, time, colors, markers);
set(ax2, 'XScale', 'log', 'YScale', 'log');
ylabel(ax2, 'Computation time [s]', 'FontSize', 14, 'Color', inkPrimary);
Style(ax2, n, gridInk, inkPrimary, inkSecondary);
legend(ax2, h2, labels, 'Interpreter','latex', 'Location','northwest', 'Box','off', 'FontSize', 12);

[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_europe_scaling', 'EuropeScaling');
exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 12);
exportgraphics(fig, [outStem '.png'], 'Resolution', 300, 'Padding', 12);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);

fprintf('\n%8s %10s %10s %10s | %9s %9s %9s\n', 'n', 'ratio k0', 'ratio k1', 'ratio MILP', 't k0', 't k1', 't MILP');
for i = 1:numel(n)
    fprintf('%8d %10.3f %10.3f %10.3f | %9.2f %9.2f %9.1f\n', n(i), ratio(i,:), time(i,:));
end
end

function h = DrawSeries(ax, n, Y, colors, markers)
% centralized first, as a large hollow diamond, so the kappa = 1 series drawn
% on top stays visible where the two coincide (both reach zero overload)
h = gobjects(1,3);
h(3) = plot(ax, n, Y(:,3), ['-' markers{3}], 'Color', colors(3,:), 'LineWidth', 3.2, ...
            'MarkerSize', 13, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', colors(3,:));
for k = 1:2
    h(k) = plot(ax, n, Y(:,k), ['-' markers{k}], 'Color', colors(k,:), 'LineWidth', 1.6, ...
                'MarkerSize', 7, 'MarkerFaceColor', colors(k,:), 'MarkerEdgeColor', 'w');
end
end

function Style(ax, n, gridInk, inkPrimary, inkSecondary)
set(ax, 'XTick', n, 'XTickLabel', compose('%d', n), 'TickLabelInterpreter','latex', ...
        'FontSize', 13, 'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','off', 'TickDir','out', 'Layer','top');
ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridColor = gridInk; ax.GridAlpha = 1;
ax.XMinorGrid = 'off'; ax.YMinorGrid = 'off';
xlim(ax, [n(1)/1.5, n(end)*1.5]);
xlabel(ax, 'Number of aircraft', 'FontSize', 14, 'Color', inkPrimary);
end
