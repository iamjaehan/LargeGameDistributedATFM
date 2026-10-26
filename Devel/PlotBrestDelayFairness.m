function PlotBrestDelayFairness(matFile)
% Total delay and inter-sector fairness for the BREST per-day study, in the
% same format as PlotBrestDays (box + every day as a dot, mean as a diamond).
%
%   PlotBrestDelayFairness                    % reads exp_brest_days_D7.mat
%   PlotBrestDelayFairness('other_study.mat')
%
% Needs delayVec / controlSector, which RunBrestDays records per day.
%
% (a) delay per aircraft: total departure delay of the day divided by the
%                     number of flights that day [min].
% (b) Gini index    : fairness among sectors (agents), as in Im et al., IEEE
%                     L-CSS 2024, Eq. (19):
%                         GI(c) = sum_{i,j} |c_i - c_j| / (2 n^2 AC(c)),
%                     with c_i the MEAN delay of the flights sector i controls
%                     (sectors controlling no flight are left out), n the
%                     number of those sectors and AC(c) the mean of c.  0 is
%                     perfectly even; a day where a method delays nobody has
%                     AC = 0 and no defined Gini, and is left out of (b).
%
% Delays of the centralized MILP and of our method are not optimised: both
% minimise overload only, so among equal-overload schedules the delays are
% whatever the solver returns.  Read (a) with that in mind.

if nargin < 1 || isempty(matFile), matFile = 'exp_brest_days_D7.mat'; end
S = load(matFile);
if ~isfield(S, 'delayVec')
    error('PlotBrestDelayFairness:noDelays', ...
          '%s has no per-flight delays - rerun RunBrestDays.', matFile);
end
[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_brest_days', 'BrestDelayFairness');

stepMin = 5;                                 % one action step = 5 min (Main.m timeunit)
[nD, nM] = size(S.delayVec);
nK = numel(S.kappas);

delayPerAc = nan(nD, nM); gini = nan(nD, nM);
for d = 1:nD
    ctrl = S.controlSector{d}(:);
    [sectors, ~, g] = unique(ctrl);
    for k = 1:nM
        x = S.delayVec{d,k};
        if isempty(x), continue; end
        delayMin = stepMin * x(:);
        delayPerAc(d,k) = mean(delayMin);   % over all flights of the day
        c = accumarray(g, delayMin, [numel(sectors) 1], @mean);   % mean delay per sector
        gini(d,k) = GiniIndex(c);
    end
end

% --- palette (as PlotBrestDays) ------------------------------------------
rampLo = [0.70 0.81 0.93]; rampHi = [0.09 0.28 0.56];
t = linspace(0, 1, nK)';
cK = rampLo + t.*(rampHi - rampLo);
cBase = repmat([0.62 0.62 0.60], nM-nK, 1);
isMilp = contains(S.labels(nK+1:end), 'MILP');
cBase(isMilp, :) = repmat([0.30 0.30 0.28], nnz(isMilp), 1);
colors = [cK; cBase];
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36];
gridInk = [0.88 0.88 0.86];

fig = figure('Color','w','Position',[10 10 1400 500]);
% Times for every non-LaTeX label (axis labels, legends, text, ticks); set on
% the figure before any axes exist so every child inherits it
set(fig, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', ...
         'DefaultLegendFontName', 'Times New Roman', 'DefaultColorbarFontName', 'Times New Roman');
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.98 1];   % right margin so the last (LaTeX) tick label is not clipped

ax1 = nexttile(tl);
BoxDots(ax1, delayPerAc, colors, inkPrimary, inkSecondary);
StyleAxis(ax1, S.labels, gridInk, inkPrimary, inkSecondary);
ylim(ax1, [0, max(delayPerAc(:), [], 'omitnan')*1.15]);   % headroom for the legend
ylabel(ax1, 'Average delay per aircraft [min]', 'FontSize', 14, 'Color', inkPrimary);

ax2 = nexttile(tl);
BoxDots(ax2, gini, colors, inkPrimary, inkSecondary);
StyleAxis(ax2, S.labels, gridInk, inkPrimary, inkSecondary);
ylim(ax2, [0, min(1, max(gini(:), [], 'omitnan')*1.15)]);
ylabel(ax2, 'Gini index', 'FontSize', 14, 'Color', inkPrimary);

exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 12);   % tight crop clips LaTeX tick labels
exportgraphics(fig, [outStem '.png'], 'Resolution', 300, 'Padding', 12);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);

% ---- table view ----------------------------------------------------------
fprintf('\n%-18s %14s %12s %12s %10s\n', 'method', 'med min/ac', 'med Gini', 'mean Gini', 'Gini days');
for k = 1:nM
    fprintf('%-18s %14.2f %12.3f %12.3f %10d\n', regexprep(S.labels{k}, '\\kappa', 'kappa'), ...
        median(delayPerAc(:,k),'omitnan'), median(gini(:,k),'omitnan'), ...
        mean(gini(:,k),'omitnan'), nnz(~isnan(gini(:,k))));
end
end

% -------------------------------------------------------------------------
function g = GiniIndex(c)
% Im et al. 2024, Eq. (19): sum_{i,j}|c_i - c_j| / (2 n^2 AC(c))
n = numel(c); ac = mean(c);
if ac <= 0, g = NaN; return; end
g = sum(abs(c - c.'), 'all') / (2 * n^2 * ac);
end

function BoxDots(ax, data, colors, inkPrimary, inkSecondary)
hold(ax, 'on');
nM = size(data, 2);
for k = 1:nM
    v = data(:,k); v = v(~isnan(v));
    if isempty(v), continue; end
    % days first, translucent box on top, so the box never hides a point
    jit = (rand(numel(v),1) - 0.5) * 0.26;
    scatter(ax, k + jit, v, 7, 'filled', ...
        'MarkerFaceColor', colors(k,:)*0.55, 'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
    boxchart(ax, repmat(k, numel(v), 1), v, ...
        'BoxFaceColor', colors(k,:), 'BoxFaceAlpha', 0.25, ...
        'WhiskerLineColor', colors(k,:)*0.7, 'LineWidth', 1.0, ...
        'MarkerStyle', 'none', 'BoxWidth', 0.56);
end
hMean = plot(ax, 1:nM, mean(data, 1, 'omitnan'), 'd', 'MarkerSize', 7, ...
    'MarkerFaceColor', 'w', 'MarkerEdgeColor', inkPrimary, 'LineWidth', 1.1, 'LineStyle', 'none');
hDay = scatter(ax, nan, nan, 16, 'filled', 'MarkerFaceColor', [0.45 0.45 0.45], ...
    'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
legend(ax, [hDay hMean], {'one day', 'mean'}, 'Location', 'northwest', 'Box','on', 'EdgeColor', [0.72 0.72 0.70], 'Color', 'w', ...
       'FontSize', 10.35, 'TextColor', inkSecondary);
end

function StyleAxis(ax, labels, gridInk, inkPrimary, inkSecondary)
% LaTeX tick labels.  A parenthetical goes onto a second line inside a
% centred array, so both lines are centred on the tick (with the tex
% interpreter the second line was left-aligned to the first).
set(ax, 'XTick', 1:numel(labels), 'XTickLabel', LatexTickLabels(labels), ...
        'TickLabelInterpreter','latex', 'FontSize', 13, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','off', 'TickDir','out', 'Layer','top');
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.GridColor = gridInk; ax.GridAlpha = 1; ax.GridLineStyle = '-';
ax.XTickLabelRotation = 0;
xlim(ax, [0.4 numel(labels)+0.75]);
hSep = xline(ax, 1.5:1:numel(labels)-0.5, '-', 'Color', [0.74 0.74 0.72], 'LineWidth', 0.9, 'HandleVisibility', 'off');
uistack(hSep, 'bottom');   % method separators behind the data   % extra room: the last LaTeX tick label was clipped
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
