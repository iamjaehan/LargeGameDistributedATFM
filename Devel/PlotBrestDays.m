function PlotBrestDays(matFile, outDir, splitStems)
% Per-day distributions for the BREST study: one run per traffic day, so the
% spread is real instance variation, not solver noise.
%
%   PlotBrestDays                              % combined, next to the data
%   PlotBrestDays(f, dir)                      % combined, into dir
%   PlotBrestDays(f, dir, {'Cost','Time'})     % one file per panel, into dir
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
if nargin < 2, outDir = ''; end
if nargin < 3, splitStems = {}; end
S = load(matFile);
[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_brest_days', 'BrestDays');
split = ~isempty(splitStems);
if ~isempty(outDir) && ~isfolder(outDir), mkdir(outDir); end

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
cRef  = [0.84 0.15 0.15];   % the threshold line and its label, in red

inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36];
gridInk = [0.79 0.79 0.77];   % ~10% darker than the MATLAB-ish default grey

if split
    [figA, ax1] = NewPanelFigure();
    [figB, ax2] = NewPanelFigure();
else
    [fig, tl] = NewCombinedFigure(); %#ok<ASGLU>
    ax1 = nexttile(tl); ax2 = nexttile(tl);
end

% ===================== (a) overload cost =================================
% Normalised by each day's OWN initial overload, so day difficulty divides
% out and the boxes compare methods rather than traffic volume.  1.0 is the
% untouched schedule, 0 is overload fully resolved.
dataA   = S.overload ./ S.initialOverload(:);
labelsA = S.labels;
colorsA = [cK; cBase];
nA      = numel(labelsA);

hold(ax1,'on');
yline(ax1, 1, '--', 'Initial overload', 'FontName', 'Times New Roman', 'Color', cRef, 'LineWidth', 1.1, ...
      'FontSize', 14.4, 'LabelHorizontalAlignment','center', ...
      'LabelVerticalAlignment','top');

for k = 1:nA
    v = dataA(:,k); v = v(~isnan(v));
    if isempty(v), continue; end
    % days first, translucent box on top, so the box never hides a point
    % every day as a dot, jittered so overlapping days stay countable
    jit = (rand(numel(v),1) - 0.5) * 0.26;
    scatter(ax1, k + jit, v, 7, 'filled', ...
        'MarkerFaceColor', colorsA(k,:)*0.55, 'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
    boxchart(ax1, repmat(k, numel(v), 1), v, ...
        'BoxFaceColor', colorsA(k,:), 'BoxFaceAlpha', 0.25, ...
        'WhiskerLineColor', colorsA(k,:)*0.7, 'LineWidth', 1.0, ...
        'MarkerStyle', 'none', 'BoxWidth', 0.56);
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
ylim(ax1, [0, max(1.18, max(dataA(:),[],'omitnan')*1.06)]);   % room for the legend above the 'no reduction' line
legend(ax1, [hDay hMeanA], {'one day', 'mean'}, 'Location','northwest', ...
       'Box','on', 'EdgeColor', [0.72 0.72 0.70], 'Color', 'w', 'FontSize', 13, 'TextColor', inkSecondary);
ylabel(ax1, 'Normalized overload cost', 'FontSize', 17, 'Color', inkPrimary);

% ===================== (b) computation time ==============================
hold(ax2,'on');
colorsB = [cK; cBase];

for k = 1:nM
    v = S.comptime(:,k); v = v(~isnan(v));
    if isempty(v), continue; end
    % days first, translucent box on top, so the box never hides a point
    % every day as a dot, as in (a), so days beyond the whiskers stay visible
    jit = (rand(numel(v),1) - 0.5) * 0.26;
    scatter(ax2, k + jit, v, 7, 'filled', ...
        'MarkerFaceColor', colorsB(k,:)*0.55, 'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
    boxchart(ax2, repmat(k, numel(v), 1), v, ...
        'BoxFaceColor', colorsB(k,:), 'BoxFaceAlpha', 0.25, ...
        'WhiskerLineColor', colorsB(k,:)*0.7, 'LineWidth', 1.0, ...
        'MarkerStyle', 'none', 'BoxWidth', 0.56);
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
ylabel(ax2, 'Computation time [s]', 'FontSize', 17, 'Color', inkPrimary);
hDayB = scatter(ax2, nan, nan, 16, 'filled', ...
    'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerFaceAlpha', 0.55, ...
    'MarkerEdgeColor','w', 'LineWidth', 0.3);
legend(ax2, [hDayB hMean], {'one day', 'mean'}, 'Location','northwest', 'Box','on', 'EdgeColor', [0.72 0.72 0.70], 'Color', 'w', ...
       'FontSize', 13, 'TextColor', inkSecondary);

if split
    ExportPanel(figA, fullfile(outDir, splitStems{1}));
    ExportPanel(figB, fullfile(outDir, splitStems{2}));
else
    ExportPanel(fig, fullfile(outDir, outStem));
end

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
function [fig, tl] = NewCombinedFigure()
fig = figure('Color','w','Position',[10 10 1400 500]);
SetTimes(fig);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.98 1];   % right margin so the last (LaTeX) tick label is not clipped
end

function [fig, ax] = NewPanelFigure()
% one panel on its own: half the combined width, same height, so the box
% widths and font sizes land where they do in the two-panel version
fig = figure('Color','w','Position',[10 10 720 500]);
SetTimes(fig);
tl = tiledlayout(fig, 1, 1, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.97 1];
ax = nexttile(tl);
end

function SetTimes(fig)
% Times for every non-LaTeX label (axis labels, legends, text, ticks); set on
% the figure before any axes exist so every child inherits it
set(fig, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', ...
         'DefaultLegendFontName', 'Times New Roman', 'DefaultColorbarFontName', 'Times New Roman');
end

function ExportPanel(fig, stem)
exportgraphics(fig, [stem '.pdf'], 'ContentType','vector', 'Padding', 12);   % tight crop clips LaTeX tick labels
fprintf('wrote %s.pdf\n', stem);
end

function StyleAxis(ax, labels, gridInk, inkPrimary, inkSecondary, subSize)
% subSize: font size for the parenthetical second line, drawn as its own text
% so it is not locked to 70% of the tick size by \scriptstyle
if nargin < 6, subSize = 12.3; end
% LaTeX tick labels.  A parenthetical goes onto a second line inside a
% centred array, so both lines are centred on the tick (with the tex
% interpreter the second line was left-aligned to the first).
set(ax, 'XTick', 1:numel(labels), 'XTickLabel', LatexTickLabels(labels, subSize), ...
        'TickLabelInterpreter','latex', 'FontSize', 16, ...   % 17+ makes the kappa labels collide
        'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','on', 'LineWidth', 0.9, 'TickDir','out', 'Layer','top');   % full frame, as in the original paper figures
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.YMinorGrid = 'on';   % the faint lines between the labelled ticks
ax.MinorGridAlpha = 0.275;
ax.GridColor = gridInk; ax.GridAlpha = 1; ax.GridLineStyle = '-';
ax.XTickLabelRotation = 0;
xlim(ax, [0.45 numel(labels)+0.5]);   % CENT needs less right margin than 'Centralized' did
hSep = xline(ax, 1.5:1:numel(labels)-0.5, '-', 'Color', [0.74 0.74 0.72], 'LineWidth', 0.9, 'HandleVisibility', 'off');
uistack(hSep, 'bottom');   % method separators behind the data   % extra room: the last LaTeX tick label was clipped
ax.XLabel.Color = inkPrimary;
AddSubLabels(ax, labels, subSize, inkSecondary);
end

function AddSubLabels(ax, labels, subSize, ink)
% "FCFS (reactive)" -> "(reactive)" under the tick, in normalized axes units so
% it sits correctly on a log y axis too
if subSize <= 0, return; end
xl = xlim(ax);
for k = 1:numel(labels)
    tok = regexp(strtrim(regexprep(labels{k}, 'MILP', '')), '^(.*?)\s*\((.*)\)$', 'tokens', 'once');
    if isempty(tok), continue; end
    text(ax, (k - xl(1))/diff(xl), -0.085, ['(' tok{2} ')'], 'Units', 'normalized', ...
         'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
         'FontName', 'Times New Roman', 'FontSize', subSize, 'Color', ink, 'Clipping', 'off');
end
end

function out = LatexTickLabels(labels, subSize)
if nargin < 2, subSize = 0; end
out = cell(size(labels));
for k = 1:numel(labels)
    % "Centralized MILP" is abbreviated to CENT, on one line and without a
    % parenthetical: spelled out it is the widest tick and runs into the FCFS
    % label beside it at this panel width
    s = regexprep(labels{k}, '^Centralized\s+MILP$', 'CENT');
    if contains(s, '\kappa')
        out{k} = ['$' s '$'];
    else
        tok = regexp(s, '^(.*?)\s*\((.*)\)$', 'tokens', 'once');
        if isempty(tok)
            out{k} = s;
        elseif subSize > 0
            out{k} = ['$\mathrm{' tok{1} '}$'];   % parenthetical drawn by AddSubLabels
        else
            % \scriptstyle, not \footnotesize: MATLAB's latex interpreter
            % silently drops the text-mode size commands
            out{k} = ['$\begin{array}{c}\mathrm{' tok{1} '}\\\scriptstyle\mathrm{(' tok{2} ')}\end{array}$'];
        end
    end
end
end

function PanelTitle(ax, s, ink)
title(ax, s, 'FontSize', 12, 'FontWeight','bold', 'Color', ink, ...
      'HorizontalAlignment','left');
ax.Title.Units = 'normalized'; ax.Title.Position(1) = 0;
end
