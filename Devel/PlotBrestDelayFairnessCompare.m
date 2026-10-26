function PlotBrestDelayFairnessCompare(beforeFile, afterFile, outStem)
% Delay per aircraft and inter-sector Gini, without vs with the delay
% tie-break, in one figure: per method a hollow box (without) and a filled
% box (with) side by side, every day as a dot, mean as a diamond.  Methods
% whose schedules the tie-break does not touch (the FCFS baselines) get one
% centred box.  Metrics as in PlotBrestDelayFairness.
%
%   PlotBrestDelayFairnessCompare('exp_brest_days_D7.mat', ...
%                                 'exp_brest_days_D7_tiebreak.mat')

if nargin < 1 || isempty(beforeFile), beforeFile = 'exp_brest_days_D7.mat'; end
if nargin < 2 || isempty(afterFile),  afterFile  = 'exp_brest_days_D7_tiebreak.mat'; end
if nargin < 3 || isempty(outStem),    outStem    = 'BrestDelayFairnessCompare_D7'; end
A = load(beforeFile); B = load(afterFile);
assert(isequal(A.days, B.days) && isequal(A.labels, B.labels), 'files do not match');
[dA, gA] = Metrics(A); [dB, gB] = Metrics(B);
nM = numel(A.labels); nK = numel(A.kappas);
touched = false(1, nM);
for k = 1:nM
    touched(k) = ~all(cellfun(@isequal, A.delayVec(:,k), B.delayVec(:,k)));
end

rampLo = [0.70 0.81 0.93]; rampHi = [0.09 0.28 0.56];
cK = rampLo + linspace(0,1,nK)'.*(rampHi - rampLo);
cBase = repmat([0.62 0.62 0.60], nM-nK, 1);
isMilp = contains(A.labels(nK+1:end), 'MILP');
cBase(isMilp, :) = repmat([0.30 0.30 0.28], nnz(isMilp), 1);
colors = [cK; cBase];
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36]; gridInk = [0.88 0.88 0.86];

fig = figure('Color','w','Position',[10 10 1400 500]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');
tl.OuterPosition = [0 0 0.98 1];   % right margin so the last (LaTeX) tick label is not clipped
ax1 = nexttile(tl); ax2 = nexttile(tl);
StyleAxis(ax1, A.labels, gridInk, inkPrimary, inkSecondary);
StyleAxis(ax2, A.labels, gridInk, inkPrimary, inkSecondary);
ylim(ax1, [0, max([dA(:); dB(:)], [], 'omitnan')*1.18]);
ylim(ax2, [0, 1]);
ylabel(ax1, 'Average delay per aircraft [min]', 'FontSize', 14, 'Color', inkPrimary);
ylabel(ax2, 'Gini index of mean delay per sector [-]', 'FontSize', 14, 'Color', inkPrimary);
drawnow;                          % final axes geometry, needed for 45-degree hatching
PairedBoxes(ax1, dA, dB, touched, colors, inkPrimary);
PairedBoxes(ax2, gA, gB, touched, colors, inkPrimary);
KeyBox(ax1, inkPrimary, inkSecondary);

exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 12);   % tight crop clips LaTeX tick labels
exportgraphics(fig, [outStem '.png'], 'Resolution', 300, 'Padding', 12);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);
end

% -------------------------------------------------------------------------
function [delayPerAc, gini] = Metrics(S)
stepMin = 5;
[nD, nM] = size(S.delayVec);
delayPerAc = nan(nD, nM); gini = nan(nD, nM);
for d = 1:nD
    [sectors, ~, g] = unique(S.controlSector{d}(:));
    for k = 1:nM
        x = S.delayVec{d,k}; if isempty(x), continue; end
        dm = stepMin * x(:);
        delayPerAc(d,k) = mean(dm);
        c = accumarray(g, dm, [numel(sectors) 1], @mean);
        if mean(c) > 0
            gini(d,k) = sum(abs(c - c.'), 'all') / (2 * numel(c)^2 * mean(c));
        end
    end
end
end

function PairedBoxes(ax, before, after, touched, colors, inkPrimary)
hold(ax, 'on');
off = 0.19; bw = 0.32; nM = size(before, 2);
% separators between methods, drawn first so they sit behind the boxes
xline(ax, 1.5:1:nM-0.5, '-', 'Color', [0.74 0.74 0.72], 'LineWidth', 0.9, 'HandleVisibility', 'off');
for k = 1:nM
    if touched(k)
        Box1(ax, k - off, before(:,k), colors(k,:), 'filled',  bw, inkPrimary);
        Box1(ax, k + off, after(:,k),  colors(k,:), 'hatched', bw, inkPrimary);
    else            % not subject to the tie-break: plain filled box
        Box1(ax, k, after(:,k), colors(k,:), 'filled', bw, inkPrimary);
    end
end
end

function Box1(ax, x, v, c, style, bw, inkPrimary)
% 'filled' = without tie-break (and the FCFS baselines, which it does not
% apply to), 'hatched' = with tie-break: no fill, hatching only
v = v(~isnan(v)); if isempty(v), return; end
edge = c*0.7;
q = quantile(v, [0.25 0.5 0.75]); iqr_ = q(3) - q(1);
lo = min(v(v >= q(1) - 1.5*iqr_)); hi = max(v(v <= q(3) + 1.5*iqr_));
xL = x - bw/2; xR = x + bw/2;
% days first, then a translucent box on top, so the box never hides a point
jit = (rand(numel(v),1) - 0.5) * bw * 0.7;
scatter(ax, x + jit, v, 7, 'filled', 'MarkerFaceColor', c*0.55, 'MarkerFaceAlpha', 0.7, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 0.3);
if strcmp(style, 'filled')
    patch(ax, [xL xR xR xL], [q(1) q(1) q(3) q(3)], c, 'FaceAlpha', 0.25, 'EdgeColor', 'none');
end
if strcmp(style, 'hatched')
    Hatch(ax, xL, xR, q(1), q(3), edge);
end
patch(ax, [xL xR xR xL], [q(1) q(1) q(3) q(3)], 'w', 'FaceColor', 'none', 'EdgeColor', edge, 'LineWidth', 1.2);
plot(ax, [xL xR], q(2)*[1 1], '-', 'Color', edge, 'LineWidth', 1.4);
plot(ax, [x x], [q(3) hi], '-', 'Color', edge, 'LineWidth', 1.2);
plot(ax, [x x], [lo q(1)], '-', 'Color', edge, 'LineWidth', 1.2);
plot(ax, x + bw/4*[-1 1], hi*[1 1], '-', 'Color', edge, 'LineWidth', 1.2);
plot(ax, x + bw/4*[-1 1], lo*[1 1], '-', 'Color', edge, 'LineWidth', 1.2);
plot(ax, x, mean(v), 'd', 'MarkerSize', 6, 'MarkerFaceColor', 'w', ...
     'MarkerEdgeColor', inkPrimary, 'LineWidth', 1.0);
end

function Hatch(ax, xL, xR, yB, yT, col)
% 45-degree lines (on screen) clipped to the rectangle [xL,xR] x [yB,yT]
if yT <= yB, return; end
old = ax.Units; ax.Units = 'pixels'; pos = ax.Position; ax.Units = old;
xl = xlim(ax); yl = ylim(ax);
s = (diff(yl)/pos(4)) / (diff(xl)/pos(3));     % data-y per data-x for a 45-degree line
gap = 7 * diff(xl)/pos(3);                     % ~7 px between lines, along x
for c = (yB - s*(xR - xL)) : s*gap : yT
    x1 = max(xL, xL + (yB - c)/s); x2 = min(xR, xL + (yT - c)/s);
    if x2 > x1
        plot(ax, [x1 x2], c + s*([x1 x2] - xL), '-', 'Color', col, 'LineWidth', 0.7);
    end
end
end

function KeyBox(ax, inkPrimary, inkSecondary)
% hand-made key (a legend cannot show hatching), top-left of the axes
xl = xlim(ax); yl = ylim(ax); X = @(f) xl(1) + f*diff(xl); Y = @(f) yl(1) + f*diff(yl);
g = [0.55 0.55 0.53]; w = 0.035*diff(xl); h = 0.035*diff(yl);
x0 = X(0.03); y1 = Y(0.94); y2 = Y(0.875);
patch(ax, x0 + [0 w w 0], y1 + [0 0 h h] - h/2, g, 'FaceAlpha', 0.25, 'EdgeColor', g, 'LineWidth', 1.2);
text(ax, x0 + 1.4*w, y1, 'without tie-break', 'FontSize', 9, 'Color', inkSecondary);
Hatch(ax, x0, x0 + w, y2 - h/2, y2 + h/2, g*0.7);
patch(ax, x0 + [0 w w 0], y2 + [0 0 h h] - h/2, 'w', 'FaceColor', 'none', 'EdgeColor', g, 'LineWidth', 1.2);
text(ax, x0 + 1.4*w, y2, 'with tie-break', 'FontSize', 9, 'Color', inkSecondary);
x1 = X(0.30);
scatter(ax, x1 + w/2, y1, 14, 'filled', 'MarkerFaceColor', [0.45 0.45 0.45], 'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'w');
text(ax, x1 + 1.4*w, y1, 'one day', 'FontSize', 9, 'Color', inkSecondary);
plot(ax, x1 + w/2, y2, 'd', 'MarkerSize', 6, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', inkPrimary, 'LineWidth', 1.0);
text(ax, x1 + 1.4*w, y2, 'mean', 'FontSize', 9, 'Color', inkSecondary);
end

function StyleAxis(ax, labels, gridInk, inkPrimary, inkSecondary)
set(ax, 'XTick', 1:numel(labels), 'XTickLabel', LatexTickLabels(labels), ...
        'TickLabelInterpreter','latex', 'FontSize', 13, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','off', 'TickDir','out', 'Layer','top');
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.GridColor = gridInk; ax.GridAlpha = 1; ax.GridLineStyle = '-';
ax.XTickLabelRotation = 0;
xlim(ax, [0.4 numel(labels)+0.75]);   % extra room: the last LaTeX tick label was clipped
ax.XLabel.Color = inkPrimary;
end

function out = LatexTickLabels(labels)
out = cell(size(labels));
for k = 1:numel(labels)
    s = strtrim(regexprep(labels{k}, 'MILP', ''));
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
