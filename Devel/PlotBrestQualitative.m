function PlotBrestQualitative(day, matFile, methods, outPdf)
% One-day qualitative figure (manuscript Fig. 3): sector occupancy over the
% day for the initial schedule and the solution of each method, one page.
%
%   PlotBrestQualitative                          % 230730, D = 10
%   PlotBrestQualitative('230730', 'exp_brest_days_D10.mat')
%   PlotBrestQualitative([], [], [], '../Analysis/revised figure/Qualitative_D10.pdf')
%                       % paper copy: that PDF only (ExportPaperFigures does this)
%
% The schedules come from the saved per-flight delays of the 28-day study
% (RunBrestDays: delayVec, controlSector), so nothing is re-solved; the
% occupancy is rebuilt with the simulator and checked against the saved
% overload.  Layout: the initial schedule across the top, the four
% solutions in two columns below.  Each sector is one thin line; the band
% above the capacity is shaded so overload reads at a glance.  Side boxes:
% total overload [aircraft-min] and maximum occupancy [aircraft].

if nargin < 1 || isempty(day), day = '230730'; end
if nargin < 2 || isempty(matFile), matFile = 'exp_brest_days_D10.mat'; end
if nargin < 3 || isempty(methods)
    methods = {'\kappa = 0', '\kappa = 1', 'Centralized MILP', 'FCFS (reactive)'};
end
panelNames = {'$\kappa = 0$', '$\kappa = 1$', '\texttt{CENT}', '\texttt{FCFS} \textmd{(reactive)}'};   % method names as in the text

S = load(matFile);
d = find(strcmp(S.days, day)); assert(~isempty(d), 'day %s not in %s', day, matFile);
D = S.capacityUsed; timeunit = 300;

% ---- rebuild the occupancy exactly as Main.m does ---------------------------
[flights, as] = LoadDataset('brest', day);
n = numel(flights); earliest = inf; latest = 0; sid = [];
for i = 1:n
    sm = as(flights(i)); sid = [sid; sm(:,1)]; %#ok<AGROW>
    earliest = min(earliest, sm(1,2)); latest = max(latest, sm(end,3));
end
earliest = earliest - 2*timeunit; latest = latest + 12*timeunit;
sector_ids = unique(sid); m = numel(sector_ids); T = numel(earliest:latest);
occ0 = zeros(m, T);
for i = 1:n
    sm = as(flights(i));
    for j = 1:size(sm,1)
        a = round(sm(j,2) - earliest + 1); b = round(sm(j,3) - earliest + 1);
        k = find(sector_ids == sm(j,1)); occ0(k, a:b) = occ0(k, a:b) + 1;
    end
end
assert(abs(ComputeSystemCost(m, occ0, D) - S.initialOverload(d)) < 1e-6, 'initial overload mismatch');

occ = cell(1, 1 + numel(methods)); occ{1} = occ0;
for q = 1:numel(methods)
    k = find(strcmp(S.labels, methods{q})); assert(numel(k) == 1, 'method %s not found', methods{q});
    occ{1+q} = UpdateOccupancyMatrix_Centralized(n, occ0, as, sector_ids, S.delayVec{d,k}(:), flights, earliest, timeunit);
    assert(abs(ComputeSystemCost(m, occ{1+q}, D) - S.overload(d,k)) < 1e-6, 'overload mismatch for %s', methods{q});
end

% ---- figure -------------------------------------------------------------------
hours = (earliest + (0:T-1)) / 3600;
ymax = max(cellfun(@(o) max(o(:)), occ)) + 1;
colors = SectorColors(m);
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36];
capColor = [0.85 0.25 0.22];

fig = figure('Color','w','Units','pixels','Position',[10 10 1150 1250]);
set(fig, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', ...
         'DefaultLegendFontName', 'Times New Roman');
tl = tiledlayout(fig, 3, 2, 'TileSpacing','compact', 'Padding','compact');
% bold panel titles; \boldmath makes the kappa bold as well
titles = [{'\textbf{(a) Initial}'}, ...
          arrayfun(@(q) sprintf('\\textbf{(%s) }{\\boldmath%s}', char('a'+q), BoldTitle(panelNames{q})), ...
                   1:numel(methods), 'UniformOutput', false)];
for p = 1:numel(occ)
    if p == 1
        ax = nexttile(tl, 1, [1 2]);          % initial schedule across the top
    else
        ax = nexttile(tl, p + 1);
    end
    DrawPanel(ax, hours, occ{p}, D, ymax, colors, capColor, inkPrimary, inkSecondary, 2 + 2*(p > 1));
    text(ax, 0.012 + 0.012*(p > 1), 0.965, titles{p}, 'Units','normalized', 'Interpreter','latex', ...
         'FontSize', 17, 'VerticalAlignment','top', 'BackgroundColor','w', 'EdgeColor', [0.72 0.72 0.70], 'Margin', 3);
    ov = ComputeSystemCost(m, occ{p}, D) / 60;
    % half-width panels: inset the box a little more, so it does not hug the edge
    boxX = 0.988 - 0.012*(p > 1);
    text(ax, boxX, 0.965, sprintf('Overload: \\textbf{%s}\nMax. occu.: \\textbf{%d}', ...
         FormatOverload(ov), max(occ{p}(:))), 'Units','normalized', 'Interpreter','latex', ...
         'FontSize', 15, 'HorizontalAlignment','right', 'VerticalAlignment','top', ...
         'BackgroundColor','w', 'EdgeColor', [0.72 0.72 0.70], 'Margin', 3);
    if p == 1
        text(ax, 1.0, D + 0.3, '  Capacity', 'Color', capColor, 'FontSize', 15, 'VerticalAlignment','bottom');
    end
end
xlabel(tl, 'Time of day', 'FontSize', 17, 'FontName', 'Times New Roman', 'Color', inkPrimary);
ylabel(tl, 'Number of aircraft', 'FontSize', 17, 'FontName', 'Times New Roman', 'Color', inkPrimary);

if nargin >= 4 && ~isempty(outPdf)
    exportgraphics(fig, outPdf, 'ContentType','vector', 'Padding', 10);
    fprintf('wrote %s\n', outPdf);
else
    outStem = sprintf('BrestQualitative_D%d_%s', D, day);
    exportgraphics(fig, [outStem '.pdf'], 'ContentType','vector', 'Padding', 10);
    exportgraphics(fig, [outStem '.png'], 'Resolution', 200, 'Padding', 10);
    fprintf('wrote %s.pdf / %s.png\n', outStem, outStem);
end
end

% -------------------------------------------------------------------------
function DrawPanel(ax, hours, occ, D, ymax, colors, capColor, inkPrimary, inkSecondary, tickStep)
hold(ax, 'on');
m = size(occ, 1);
for s = 1:m
    o = occ(s, :);
    keep = [true, diff(o) ~= 0];          % change points only: small vector output
    x = hours(keep); y = o(keep);
    % staircase: level y(i) from x(i) to x(i+1)
    xs = reshape([x; [x(2:end), hours(end)]], 1, []);
    ys = reshape([y; y], 1, []);
    plot(ax, xs, ys, '-', 'Color', colors(s,:), 'LineWidth', 0.6);
end
yline(ax, D, '--', 'Color', capColor, 'LineWidth', 1.3);
% 2 h ticks on the full-width panel, 4 h on the half-width ones (kept upright)
set(ax, 'XLim', [0 24], 'YLim', [0 ymax], 'XTick', 0:tickStep:24, ...
        'XTickLabel', compose('%02d:00', 0:tickStep:24), 'XTickLabelRotation', 0, 'YTick', 0:2:ymax, ...
        'FontSize', 12, 'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','on', 'TickDir','in', 'TickLength', [0.006 0.006], 'Layer','top');   % ticks inside, as in the original figure: none stick out of the top/right edges
ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridColor = [0.88 0.88 0.86]; ax.GridAlpha = 1;
end

function c = SectorColors(m)
% distinct, mid-lightness colours, fixed per sector across panels
base = [0.122 0.467 0.706; 1.000 0.498 0.055; 0.173 0.627 0.173; 0.839 0.153 0.157;
        0.580 0.404 0.741; 0.549 0.337 0.294; 0.890 0.467 0.761; 0.498 0.498 0.498;
        0.737 0.741 0.133; 0.090 0.745 0.812];
c = zeros(m, 3);
for s = 1:m
    shade = 1 - 0.25*floor((s-1)/size(base,1));      % darker cycle after every 10
    c(s,:) = base(mod(s-1, size(base,1)) + 1, :) * shade;
end
end

function t = BoldTitle(name)
% text names ('\texttt{CENT}') go in \textbf; kappa labels stay math
if startsWith(name, '$'), t = name; else, t = ['\textbf{' name '}']; end
end

function s = FormatOverload(v)
if v == 0, s = '0'; else, s = sprintf('%.1f', v); end
end
