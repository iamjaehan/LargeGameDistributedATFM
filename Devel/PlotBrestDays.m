function PlotBrestDays(matFile)
% Per-day distributions for the BREST study: one run per traffic day, so the
% spread is real instance variation, not solver noise.
%
%   PlotBrestDays                        % reads exp_brest_days_D7.mat
%   PlotBrestDays('other_study.mat')
%
% (a) overload cost  : box + the individual days as jittered dots, so the
%                      reader sees the distribution AND every observation.
%                      The initial overload is its own box, because it now
%                      varies by day and a single reference line would lie.
% (b) computation time: box + the individual days as jittered dots, with the
%                      mean marked alongside the median.
%
% Two panels rather than one with two y-axes: different measures, different
% scales.  Colour encodes the ordered kappa family as one sequential ramp and
% the baselines as neutral grey; every box is labelled on the category axis,
% so identity never rests on colour alone.

if nargin < 1 || isempty(matFile), matFile = 'exp_brest_days_D7.mat'; end
S = load(matFile);
[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_brest_days', 'BrestDays');

nK = numel(S.kappas);
nM = numel(S.labels);
nD = size(S.overload, 1); %#ok<NASGU>

% --- palette -------------------------------------------------------------
rampLo = [0.70 0.81 0.93]; rampHi = [0.09 0.28 0.56];
t = linspace(0, 1, nK)';
cK = rampLo + t.*(rampHi - rampLo);
cBase = repmat([0.62 0.62 0.60], nM-nK, 1);
% the centralized MILP is the optimum reference, not another heuristic:
% darker neutral so it reads apart from the FCFS boxes
cBase(contains(S.labels(nK+1:end), 'MILP'), :) = repmat([0.30 0.30 0.28], nnz(contains(S.labels(nK+1:end), 'MILP')), 1);
cInit = [0.84 0.47 0.44];

inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36];
gridInk = [0.88 0.88 0.86];

fig = figure('Color','w','Position',[80 80 1240 480]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');

% ===================== (a) overload cost =================================
% Normalised by each day's OWN initial overload, so day difficulty divides
% out and the boxes compare methods rather than traffic volume.  1.0 is the
% untouched schedule, 0 is overload fully resolved.
dataA   = S.overload ./ S.initialOverload(:);
labelsA = S.labels;
colorsA = [cK; cBase];
nA      = numel(labelsA);

ax1 = nexttile(tl); hold(ax1,'on');
yline(ax1, 1, '--', 'no reduction', 'Color', cInit, 'LineWidth', 1.1, ...
      'FontSize', 9, 'LabelHorizontalAlignment','right', ...
      'LabelVerticalAlignment','bottom');

for k = 1:nA
    v = dataA(:,k); v = v(~isnan(v));
    if isempty(v), continue; end
    boxchart(ax1, repmat(k, numel(v), 1), v, ...
        'BoxFaceColor', colorsA(k,:), 'BoxFaceAlpha', 0.55, ...
        'WhiskerLineColor', colorsA(k,:)*0.7, 'LineWidth', 1.0, ...
        'MarkerStyle', 'none', 'BoxWidth', 0.56);
    % every day as a dot, jittered so overlapping days stay countable
    jit = (rand(numel(v),1) - 0.5) * 0.26;
    scatter(ax1, k + jit, v, 16, 'filled', ...
        'MarkerFaceColor', colorsA(k,:)*0.55, 'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
end

% mean alongside the median line the box already draws
muA = mean(dataA, 1, 'omitnan');
hMeanA = plot(ax1, 1:nA, muA, 'd', 'MarkerSize', 7, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', inkPrimary, 'LineWidth', 1.1, ...
    'LineStyle','none');
hDay = scatter(ax1, nan, nan, 16, 'filled', ...
    'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerFaceAlpha', 0.55, ...
    'MarkerEdgeColor','w', 'LineWidth', 0.3);

StyleAxis(ax1, labelsA, gridInk, inkPrimary, inkSecondary);
ylim(ax1, [0, max(1.06, max(dataA(:),[],'omitnan')*1.06)]);
legend(ax1, [hDay hMeanA], {'one day', 'mean'}, 'Location','northwest', ...
       'Box','off', 'FontSize', 9, 'TextColor', inkSecondary);
ylabel(ax1, 'Overload cost / initial  [-]', 'FontSize', 11, 'Color', inkPrimary);

% ===================== (b) computation time ==============================
ax2 = nexttile(tl); hold(ax2,'on');
colorsB = [cK; cBase];

for k = 1:nM
    v = S.comptime(:,k); v = v(~isnan(v));
    if isempty(v), continue; end
    boxchart(ax2, repmat(k, numel(v), 1), v, ...
        'BoxFaceColor', colorsB(k,:), 'BoxFaceAlpha', 0.55, ...
        'WhiskerLineColor', colorsB(k,:)*0.7, 'LineWidth', 1.0, ...
        'MarkerStyle', 'none', 'BoxWidth', 0.56);
    % every day as a dot, as in (a), so days beyond the whiskers stay visible
    jit = (rand(numel(v),1) - 0.5) * 0.26;
    scatter(ax2, k + jit, v, 16, 'filled', ...
        'MarkerFaceColor', colorsB(k,:)*0.55, 'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
end

% mean alongside the median (boxchart draws the median line itself)
mu = mean(S.comptime, 1, 'omitnan');
hMean = plot(ax2, 1:nM, mu, 'd', 'MarkerSize', 7, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', inkPrimary, 'LineWidth', 1.1, ...
    'LineStyle','none');

allT = S.comptime(~isnan(S.comptime));
if max(allT)/max(min(allT), eps) > 50
    set(ax2, 'YScale', 'log');
    ylim(ax2, [10^floor(log10(max(min(allT),1e-3))), 10^ceil(log10(max(allT)))]);
end

StyleAxis(ax2, S.labels, gridInk, inkPrimary, inkSecondary);
ylabel(ax2, 'Computation time [s]', 'FontSize', 11, 'Color', inkPrimary);
hDayB = scatter(ax2, nan, nan, 16, 'filled', ...
    'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerFaceAlpha', 0.55, ...
    'MarkerEdgeColor','w', 'LineWidth', 0.3);
legend(ax2, [hDayB hMean], {'one day', 'mean'}, 'Location','northwest', 'Box','off', ...
       'FontSize', 9, 'TextColor', inkSecondary);

exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector');
exportgraphics(fig, [outStem '.png'], 'Resolution', 300);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);

% ---- table view so the figure is never the only way to read the numbers
red = 100*(1 - S.overload ./ S.initialOverload);
fprintf('\n%-18s %10s %10s %10s %10s %10s\n', ...
        'method','med ovl','med red%','min red%','max red%','med time');
for k = 1:nM
    fprintf('%-18s %10.0f %9.1f%% %9.1f%% %9.1f%% %9.2fs\n', ...
        regexprep(S.labels{k}, '\\kappa', 'kappa'), ...
        median(S.overload(:,k),'omitnan'), median(red(:,k),'omitnan'), ...
        min(red(:,k),[],'omitnan'), max(red(:,k),[],'omitnan'), ...
        median(S.comptime(:,k),'omitnan'));
end
end

% -------------------------------------------------------------------------
function StyleAxis(ax, labels, gridInk, inkPrimary, inkSecondary)
% LaTeX tick labels.  A parenthetical goes onto a second line inside a
% centred array, so both lines are centred on the tick (with the tex
% interpreter the second line was left-aligned to the first).
set(ax, 'XTick', 1:numel(labels), 'XTickLabel', LatexTickLabels(labels), ...
        'TickLabelInterpreter','latex', 'FontSize', 11, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','off', 'TickDir','out', 'Layer','top');
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.GridColor = gridInk; ax.GridAlpha = 1; ax.GridLineStyle = '-';
ax.XTickLabelRotation = 0;
xlim(ax, [0.4 numel(labels)+0.6]);
ax.XLabel.Color = inkPrimary;
end

function out = LatexTickLabels(labels)
out = cell(size(labels));
for k = 1:numel(labels)
    s = strtrim(regexprep(labels{k}, 'MILP', ''));     % "Centralized MILP" -> "Centralized"
    if contains(s, '\kappa')
        out{k} = ['$' s '$'];
    else
        tok = regexp(s, '^(.*?)\s*\((.*)\)$', 'tokens', 'once');
        if isempty(tok)
            out{k} = s;
        else
            out{k} = ['$\begin{array}{c}\mathrm{' tok{1} '}\\\mathrm{(' tok{2} ')}\end{array}$'];
        end
    end
end
end

function PanelTitle(ax, s, ink)
title(ax, s, 'FontSize', 12, 'FontWeight','bold', 'Color', ink, ...
      'HorizontalAlignment','left');
ax.Title.Units = 'normalized'; ax.Title.Position(1) = 0;
end
