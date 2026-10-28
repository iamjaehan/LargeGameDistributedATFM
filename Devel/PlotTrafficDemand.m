function PlotTrafficDemand(dataset, day, outPdf)
% Traffic demand profile (manuscript Sec. 6.1): occupancy of every agent over
% the day for the unregulated schedule, one panel, one line per agent.
%
%   PlotTrafficDemand('europe')                   % 12 country-level groups
%   PlotTrafficDemand('brest', '230730')          % the sectors active on one date
%   PlotTrafficDemand('brest', '230730', '../Analysis/revised figure/TDP_BREST.pdf')
%
% The occupancy is counted at 1 s, as in Main.m.  BREST uses the sector
% colours of PlotBrestQualitative, so the same day reads alike in both figures.

if nargin < 2, day = ''; end
[flights, as] = LoadDataset(dataset, day);
n = numel(flights); sid = [];
for i = 1:n
    sm = as(flights(i)); sid = [sid; sm(:,1)]; %#ok<AGROW>
end
sector_ids = unique(sid); m = numel(sector_ids);

% occupancy over the day in 1 s bins; difference array, then cumsum
T = 24*3600;
dOcc = zeros(m, T + 1);
for i = 1:n
    sm = as(flights(i));
    for j = 1:size(sm,1)
        a = min(max(round(sm(j,2)) + 1, 1), T); b = min(max(round(sm(j,3)) + 1, 1), T);
        k = find(sector_ids == sm(j,1));
        dOcc(k, a) = dOcc(k, a) + 1; dOcc(k, b+1) = dOcc(k, b+1) - 1;
    end
end
occ = cumsum(dOcc(:, 1:T), 2);
hours = (0:T-1) / 3600;

colors = SectorColors(m);
inkPrimary = [0.11 0.11 0.11]; inkSecondary = [0.38 0.38 0.36];

fig = figure('Color','w','Units','pixels','Position',[10 10 1150 340]);
set(fig, 'DefaultAxesFontName', 'Times New Roman', 'DefaultTextFontName', 'Times New Roman', ...
         'DefaultLegendFontName', 'Times New Roman');
ax = axes(fig); hold(ax, 'on');
for s = 1:m
    o = occ(s, :);
    keep = [true, diff(o) ~= 0];          % change points only: small vector output
    x = hours(keep); y = o(keep);
    xs = reshape([x; [x(2:end), 24]], 1, []);
    ys = reshape([y; y], 1, []);
    plot(ax, xs, ys, '-', 'Color', colors(s,:), 'LineWidth', 0.7);
end
ymax = max(occ(:));
if ymax > 100, yStep = 500; else, yStep = 4; end
set(ax, 'XLim', [0 24], 'YLim', [0 ceil(ymax*1.05/yStep)*yStep], 'XTick', 0:2:24, ...
        'XTickLabel', compose('%02d:00', 0:2:24), 'XTickLabelRotation', 0, 'YTick', 0:yStep:ceil(ymax*1.05/yStep)*yStep, ...
        'FontSize', 14, 'XColor', inkSecondary, 'YColor', inkSecondary, ...
        'Box','on', 'TickDir','in', 'TickLength', [0.006 0.006], 'Layer','top');
ax.XGrid = 'on'; ax.YGrid = 'on'; ax.GridColor = [0.88 0.88 0.86]; ax.GridAlpha = 1;
xlabel(ax, 'Time of day', 'FontSize', 17, 'Color', inkPrimary);
ylabel(ax, 'Number of aircraft', 'FontSize', 17, 'Color', inkPrimary);

if nargin < 3 || isempty(outPdf)
    outPdf = ['TDP_' TdpName(dataset) regexprep(['_' day], '_$', '') '.pdf'];
end
exportgraphics(fig, outPdf, 'ContentType','vector', 'Padding', 10);
fprintf('wrote %s (%d agents, %d flights, peak %d)\n', outPdf, m, n, ymax);
end

function c = SectorColors(m)
% as PlotBrestQualitative: distinct, mid-lightness colours, fixed per sector
base = [0.122 0.467 0.706; 1.000 0.498 0.055; 0.173 0.627 0.173; 0.839 0.153 0.157;
        0.580 0.404 0.741; 0.549 0.337 0.294; 0.890 0.467 0.761; 0.498 0.498 0.498;
        0.737 0.741 0.133; 0.090 0.745 0.812];
c = zeros(m, 3);
for s = 1:m
    shade = 1 - 0.25*floor((s-1)/size(base,1));      % darker cycle after every 10
    c(s,:) = base(mod(s-1, size(base,1)) + 1, :) * shade;
end
end

function s = TdpName(dataset)
% file-name form: 'brest' -> 'BREST', 'europe' -> 'Europe'
if strcmpi(dataset, 'brest'), s = 'BREST'; else, s = [upper(dataset(1)) lower(dataset(2:end))]; end
end
