function PlotBrestSweep(matFile)
% Bar plots of the BREST kappa sweep and the two FCFS baselines.
%
%   PlotBrestSweep                      % reads exp_brest_sweep.mat
%   PlotBrestSweep('other_sweep.mat')
%
% Two panels, never one with two y-axes: overload cost and computation time
% are different measures on different scales, so they get their own axes.
%
% Colour carries meaning, not decoration: the kappa runs are one ordered
% family, so they take a single-hue sequential ramp that darkens with kappa;
% the FCFS baselines are a different kind of thing and take a neutral grey.
% Identity is therefore never colour-alone -- every bar is labelled on the
% category axis and carries its value.

if nargin < 1 || isempty(matFile), matFile = 'exp_brest_sweep.mat'; end
S = load(matFile);
[~, stem] = fileparts(matFile);
outStem = regexprep(stem, '^exp_brest_sweep', 'BrestSweep');

nK  = numel(S.kappas);
nAll = numel(S.labels);

% --- palette -------------------------------------------------------------
% sequential blue ramp, light -> dark with increasing kappa
rampLo = [0.70 0.81 0.93];
rampHi = [0.09 0.28 0.56];
t = linspace(0, 1, nK)';
colors = rampLo + t.*(rampHi - rampLo);
colors = [colors; repmat([0.62 0.62 0.60], nAll-nK, 1)];   % FCFS: neutral grey

inkPrimary   = [0.11 0.11 0.11];
inkSecondary = [0.38 0.38 0.36];
gridInk      = [0.88 0.88 0.86];
refInk       = [0.78 0.25 0.22];

fig = figure('Color','w','Position',[100 100 1180 460]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing','compact', 'Padding','compact');

% ===================== (a) overload cost =================================
ax1 = nexttile(tl);
hold(ax1,'on');
scaleK = max([S.overload(:); S.initialOverload]) >= 1e4;
if scaleK, sc = 1e-3; else, sc = 1; end
for k = 1:nAll
    bar(ax1, k, S.overload(k)*sc, 0.68, 'FaceColor', colors(k,:), ...
        'EdgeColor','none');
end

yline(ax1, S.initialOverload*sc, '--', 'Initial overload', ...
      'Color', refInk, 'LineWidth', 1.2, 'FontSize', 10, ...
      'LabelHorizontalAlignment','left', 'LabelVerticalAlignment','bottom');

% value on each bar: 8 bars, so labelling all of them is still selective
top = max([S.overload(:); S.initialOverload])*sc;
for k = 1:nAll
    text(ax1, k, S.overload(k)*sc + 0.022*top, FormatCount(S.overload(k)), ...
         'HorizontalAlignment','center', 'FontSize', 9, 'Color', inkSecondary);
end

StyleAxis(ax1, S.labels, gridInk, inkPrimary, inkSecondary);
ylim(ax1, [0 top*1.14]);
ax1.YAxis.Exponent = 0;
if scaleK
    ylabel(ax1, 'Overload cost [10^3 aircraft\cdotmin]', 'FontSize', 11, 'Color', inkPrimary);
else
    ylabel(ax1, 'Overload cost [aircraft\cdotmin]', 'FontSize', 11, 'Color', inkPrimary);
end
title(ax1, '(a)  Final overload cost', 'FontSize', 12, 'FontWeight','bold', ...
      'Color', inkPrimary, 'HorizontalAlignment','left');
ax1.Title.Units = 'normalized'; ax1.Title.Position(1) = 0;

% ===================== (b) computation time ==============================
ax2 = nexttile(tl);
hold(ax2,'on');
for k = 1:nAll
    bar(ax2, k, S.comptime(k), 0.68, 'FaceColor', colors(k,:), 'EdgeColor','none');
end

% times span orders of magnitude between the MILP rounds and FCFS, so log
useLog = max(S.comptime)/max(min(S.comptime), eps) > 50;
if useLog
    set(ax2, 'YScale', 'log');
    lo = 10^floor(log10(max(min(S.comptime), 1e-3)));
    ylim(ax2, [lo, 10^ceil(log10(max(S.comptime)))*1.6]);
    for k = 1:nAll
        text(ax2, k, S.comptime(k)*1.18, FormatTime(S.comptime(k)), ...
             'HorizontalAlignment','center', 'FontSize', 9, 'Color', inkSecondary);
    end
else
    topT = max(S.comptime);
    ylim(ax2, [0 topT*1.14]);
    for k = 1:nAll
        text(ax2, k, S.comptime(k) + 0.022*topT, FormatTime(S.comptime(k)), ...
             'HorizontalAlignment','center', 'FontSize', 9, 'Color', inkSecondary);
    end
end

StyleAxis(ax2, S.labels, gridInk, inkPrimary, inkSecondary);
ylabel(ax2, 'Computation time [s]', 'FontSize', 11, 'Color', inkPrimary);
title(ax2, '(b)  Computation time', 'FontSize', 12, 'FontWeight','bold', ...
      'Color', inkPrimary, 'HorizontalAlignment','left');
ax2.Title.Units = 'normalized'; ax2.Title.Position(1) = 0;

subtitle = sprintf(['BREST FIR, %s  |  %d flights, %d sectors, D = %d  |  ' ...
                    'exact best responses (intlinprog)'], ...
                   FormatDay(S.dayUsed), S.nFlights, S.nSectors, S.capacityUsed);
tl.Subtitle.String = subtitle;
tl.Subtitle.FontSize = 10;
tl.Subtitle.Color = inkSecondary;

exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector');
exportgraphics(fig, [outStem '.png'], 'Resolution', 300);
fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);

% ---- table view, so the figure is never the only way to read the numbers
fprintf('\n%-18s %12s %10s %10s\n','method','overload','reduce %','time (s)');
for k = 1:nAll
    fprintf('%-18s %12.6g %9.1f%% %10.2f\n', ...
        regexprep(S.labels{k}, '\\kappa', 'kappa'), S.overload(k), ...
        100*(1 - S.overload(k)/S.initialOverload), S.comptime(k));
end
end

% -------------------------------------------------------------------------
function StyleAxis(ax, labels, gridInk, inkPrimary, inkSecondary)
set(ax, 'XTick', 1:numel(labels), 'XTickLabel', labels, ...
        'TickLabelInterpreter','tex', 'FontSize', 10, ...
        'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','off', 'TickDir','out', 'Layer','top');
ax.XAxis.FontSize = 10;
ax.YGrid = 'on'; ax.XGrid = 'off';
ax.GridColor = gridInk; ax.GridAlpha = 1; ax.GridLineStyle = '-';
xlim(ax, [0.4 numel(labels)+0.6]);
ax.XLabel.Color = inkPrimary;
end

function s = FormatCount(v)
if v == 0,            s = '0';
elseif v >= 10000,    s = sprintf('%.1fk', v/1000);
elseif v >= 1000,     s = sprintf('%.0f', v);
else,                 s = sprintf('%.0f', v);
end
end

function s = FormatTime(v)
if v >= 100,     s = sprintf('%.0f s', v);
elseif v >= 10,  s = sprintf('%.1f s', v);
elseif v >= 1,   s = sprintf('%.2f s', v);
else,            s = sprintf('%.0f ms', v*1000);
end
end

function s = FormatDay(d)
s = sprintf('20%s-%s-%s', d(1:2), d(3:4), d(5:6));
end
