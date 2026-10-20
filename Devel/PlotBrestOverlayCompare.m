function PlotBrestOverlayCompare(geo, runs, varargin)
% Side-by-side map overlay of BREST sector overload for several runs (e.g.
% kappa = 0 vs kappa = 1), stepping through the best-response dynamics.
%
%   PlotBrestOverlayCompare(geo, runs, ...
%       'Gif', path, 'Mp4', path, 'Filmstrip', path, 'Basemap', 'streets-light', 'Title', str)
%
%   runs(r).label      panel title, e.g. '\kappa = 0'
%   runs(r).L          numel(geo) x nFrames daily overload [aircraft-min]
%                      (initial, then each accepted best response), NaN = no
%                      traffic; see BrestRunFromHistory
%   runs(r).steps      cell of step labels, one per frame
%   runs(r).highlight  geo id of the sector updating in each frame (0 = none)
%
% Each overloaded sector is drawn in translucent red over the basemap; the
% opacity grows with its daily cumulative overload (one scale for all runs
% and frames), sectors without overload are left unfilled.  Vertically
% stacked sectors share a footprint, so their reds add up over that area.
% The sector updating in a frame is outlined in blue.  Every sector carries
% its name and current overload (0 when none).  A run that converged
% earlier holds its last frame.

opt = inputParser;
addParameter(opt, 'Gif', '');
addParameter(opt, 'Mp4', '');
addParameter(opt, 'Filmstrip', '');
addParameter(opt, 'Basemap', 'streets-light');
addParameter(opt, 'Title', '');
parse(opt, varargin{:});
opt = opt.Results;

nR = numel(runs);
Lmax = max(arrayfun(@(x) max(x.L(:)), runs));
nF = max(arrayfun(@(x) size(x.L,2), runs));
% every sector is labelled with its current overload (0 when none), so all
% panels list the same sectors
labelled = true(numel(geo), 1);
[bx, by] = boundingbox(union([geo.shape]));
latlim = by + [-0.35 0.35]; lonlim = bx + [-0.5 0.5];
zoomOut = 1.2;                                   % show 20% more area around the FIR
latlim = mean(latlim) + zoomOut*(latlim - mean(latlim));
lonlim = mean(lonlim) + zoomOut*(lonlim - mean(lonlim));
% Basemap fetched once and drawn as an image in Web Mercator; sectors are
% projected polyshapes on ordinary axes (geoaxes did not render
% translucent polygon fills reliably).
bm = loadBasemap(opt.Basemap, latlim, lonlim);
geoShapes = arrayfun(@(g) project(bm.crs, g.shape), geo, 'UniformOutput', false);

% ---- animation ----------------------------------------------------------------
if ~isempty(opt.Gif) || ~isempty(opt.Mp4)
    images = cell(1, nF);
    for f = 1:nF
        fig = figure('Color','w','Units','pixels','Position',[50 50 1500 760],'Visible','off');
        t = tiledlayout(fig, 1, nR, 'TileSpacing','compact', 'Padding','compact');
        t.OuterPosition = [0 0.08 1 0.92];
        if ~isempty(opt.Title), title(t, opt.Title, 'FontSize', 16, 'FontWeight', 'bold'); end
        for r = 1:nR
            [fr, held] = frameOf(runs(r), f);
            gx = nexttile(t, r);
            drawPanel(gx, geo, geoShapes, runs(r).L(:,fr), labelled, Lmax, ...
                      runs(r).highlight(fr)*~held, bm, 8.5);
            title(gx, sprintf('%s  |  %s', runs(r).label, stepName(fr)), 'FontSize', 14, 'FontWeight', 'bold');
            totalBox(gx, sum(runs(r).L(:,fr), 'omitnan'), 12);
        end
        drawLegend(fig, Lmax);
        tmp = [tempname '.png'];
        exportgraphics(fig, tmp, 'Resolution', 100);
        images{f} = imread(tmp); delete(tmp);
        close(fig);
    end
    writeAnimation(images, opt.Gif, opt.Mp4);
end

% ---- filmstrip: rows = steps, columns = runs ----------------------------------
if ~isempty(opt.Filmstrip)
    fig = figure('Color','w','Units','pixels','Position',[50 50 360*nR+40 70+300*nF],'Visible','off');
    t = tiledlayout(fig, nF, nR, 'TileSpacing','tight', 'Padding','compact');
    t.OuterPosition = [0 0.03 1 0.97];
    if ~isempty(opt.Title), title(t, opt.Title, 'FontSize', 12, 'FontWeight', 'bold'); end
    for f = 1:nF
        for r = 1:nR
            [fr, held] = frameOf(runs(r), f);
            gx = nexttile(t, (f-1)*nR + r);
            drawPanel(gx, geo, geoShapes, runs(r).L(:,fr), labelled, Lmax, ...
                      runs(r).highlight(fr)*~held, bm, 6);
            title(gx, sprintf('%s  |  %s', runs(r).label, stepName(fr)), 'FontSize', 10, 'FontWeight', 'bold');
            totalBox(gx, sum(runs(r).L(:,fr), 'omitnan'), 8);
        end
    end
    drawLegend(fig, Lmax, [0.25 0.005 0.5 0.02]);
    exportgraphics(fig, opt.Filmstrip, 'Resolution', 120);
    close(fig);
end
end

% ==============================================================================
function [fr, held] = frameOf(run, f)
fr = min(f, size(run.L,2));
held = f > size(run.L,2);
end

function s = stepName(fr)
% frame 1 is the initial schedule, frame k+1 the k-th accepted best response;
% a run that already converged keeps showing its last step
if fr == 1, s = 'Initial'; else, s = sprintf('Step %d', fr-1); end
end

function totalBox(ax, total, fontSize)
text(ax, 0.015, 0.985, sprintf('Total overload: %.1f aircraft-min', total), 'Units', 'normalized', ...
     'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', fontSize, ...
     'FontWeight','bold', 'Color', [0.1 0.05 0.05], 'BackgroundColor', [1 1 1 0.85], 'Margin', 3);
end

function bm = loadBasemap(name, latlim, lonlim)
[A, RA, attrib] = readBasemapImage(name, latlim, lonlim);
bm.A = A; bm.RA = RA; bm.attrib = attrib; bm.crs = RA.ProjectedCRS;
[x, y] = projfwd(bm.crs, latlim([1 2 2 1]), lonlim([1 1 2 2]));
bm.xlim = [min(x) max(x)]; bm.ylim = [min(y) max(y)];
end

function ps = project(crs, shape)
% polyshape in lon/lat -> polyshape in projected metres (NaN ring breaks kept)
v = shape.Vertices;
[x, y] = projfwd(crs, v(:,2), v(:,1));
ws = warning('off', 'MATLAB:polyshape:repairedBySimplify');
ps = polyshape(x, y);
warning(ws);
end

function drawPanel(ax, geo, shapes, L, labelled, Lmax, highlightId, bm, fontSize)
red = [208 59 59]/255; darkRed = [140 25 25]/255; hiBlue = [42 120 214]/255;
hold(ax, 'on');
xw = bm.RA.XWorldLimits; yw = bm.RA.YWorldLimits;
if strcmp(bm.RA.ColumnsStartFrom, 'north'), yw = fliplr(yw); end
image(ax, 'XData', xw, 'YData', yw, 'CData', bm.A);
for k = 1:numel(geo)       % thin outline of every sector, no fill
    plot(ax, shapes{k}, 'FaceColor', 'none', 'EdgeColor', [0.45 0.45 0.45], 'LineWidth', 0.4);
end
for k = 1:numel(geo)
    v = L(k);
    if ~isnan(v) && v > 0
        s = sqrt(v/Lmax);
        plot(ax, shapes{k}, 'FaceColor', red, 'FaceAlpha', 0.12 + 0.68*s, ...
             'EdgeColor', darkRed, 'LineWidth', 0.8);
    end
end
for k = 1:numel(geo)
    if geo(k).id == highlightId
        plot(ax, shapes{k}, 'FaceColor', 'none', 'EdgeColor', hiBlue, 'LineWidth', 2);
    end
end
% Labels: every sector in `labelled` shows its current overload (0 once
% resolved).  Stacked sectors share a footprint, so their labels go into one
% box, upper layers first.
over = find(labelled)';
if ~isempty(over)
    c = zeros(numel(over), 2);
    for q = 1:numel(over)
        [c(q,1), c(q,2)] = centroid(geo(over(q)).shape);
    end
    [~, ~, grp] = unique(round(c/0.1), 'rows');
    layerRank = containers.Map({'U','I','F','Lower'}, {1, 2, 3, 4});
    hText = gobjects(0);
    for g = unique(grp)'
        members = over(grp == g);
        [~, ord] = sort(cellfun(@(x) layerRank(x), {geo(members).layer}));
        lines = cell(1, numel(members));
        for q = 1:numel(members)
            k = members(ord(q));
            code = geo(k).code(end-1:end);
            if strcmp(geo(k).code, 'LFRBFIS'), code = 'TMA'; end
            if L(k) > 0
                lines{q} = sprintf('%s %.1f', code, L(k));
            else
                lines{q} = sprintf('%s 0', code);
            end
        end
        cc = mean(c(grp == g, :), 1);
        [lx, ly] = projfwd(bm.crs, cc(2), cc(1));
        hText(end+1) = text(ax, lx, ly, strjoin(lines, newline), ...
             'HorizontalAlignment','center', 'FontSize', fontSize, 'FontWeight','normal', ...
             'Color', [0.1 0.05 0.05]); %#ok<AGROW>
    end
    set(ax, 'XLim', bm.xlim, 'YLim', bm.ylim, 'DataAspectRatio', [1 1 1]);
    drawnow;              % text extents are only valid after a draw
    separateLabels(hText);
end
set(ax, 'YDir', 'normal', 'XTick', [], 'YTick', [], 'Box', 'on', ...
    'XColor', [0.6 0.6 0.6], 'YColor', [0.6 0.6 0.6]);
axis(ax, 'equal');
xlim(ax, bm.xlim); ylim(ax, bm.ylim);
end

function separateLabels(h)
% Push apart label boxes that overlap (small neighbouring footprints), moving
% them sideways by half the overlap each.
for it = 1:20
    moved = false;
    for i = 1:numel(h)
        for j = i+1:numel(h)
            a = h(i).Extent; b = h(j).Extent;      % [x y w h] in data units
            ox = min(a(1)+a(3), b(1)+b(3)) - max(a(1), b(1));
            oy = min(a(2)+a(4), b(2)+b(4)) - max(a(2), b(2));
            if ox > 0 && oy > 0
                d = (ox/2 + 0.02*a(3)) * sign((b(1)+b(3)/2) - (a(1)+a(3)/2) + eps);
                h(i).Position(1) = h(i).Position(1) - d;
                h(j).Position(1) = h(j).Position(1) + d;
                moved = true;
            end
        end
    end
    if ~moved, break; end
end
end

function drawLegend(fig, Lmax, pos)
if nargin < 3, pos = [0.3 0.015 0.4 0.05]; end
red = [208 59 59]/255;
ax = axes(fig, 'Position', pos, 'Visible', 'off'); hold(ax, 'on');
vals = [0.02 0.1 0.25 0.5 1]*Lmax;
for i = 1:numel(vals)
    s = sqrt(vals(i)/Lmax);
    patch(ax, i + [0 0.8 0.8 0], [0 0 1 1], red, 'FaceAlpha', 0.12 + 0.68*s, 'EdgeColor', [0.55 0.2 0.2]);
    text(ax, i + 0.4, -0.35, sprintf('%.0f', vals(i)), 'HorizontalAlignment','center', 'FontSize', 9, 'VerticalAlignment','top');
end
text(ax, 0.85, 0.5, 'Daily overload [aircraft-min]:  none = no fill', 'HorizontalAlignment','right', 'FontSize', 9);
text(ax, numel(vals) + 1, 0.5, 'blue outline = sector taking its best response', 'FontSize', 9, 'Color', [42 120 214]/255);
xlim(ax, [0 numel(vals) + 1]); ylim(ax, [-1 1.2]);
end

function writeAnimation(images, gifPath, mp4Path)
nF = numel(images);
h = 2*floor(size(images{1},1)/2); w = 2*floor(size(images{1},2)/2);
for f = 1:nF, images{f} = imresize(images{f}, [h w]); end
dwell = 0.7*[2.5, 1.2*ones(1, nF-2), 2.5];   % 30% faster than 1.2 s / 2.5 s
dwell = dwell(1:nF);
if ~isempty(gifPath)
    for f = 1:nF
        [A, map] = rgb2ind(images{f}, 256);
        if f == 1
            imwrite(A, map, gifPath, 'gif', 'LoopCount', Inf, 'DelayTime', dwell(f));
        else
            imwrite(A, map, gifPath, 'gif', 'WriteMode', 'append', 'DelayTime', dwell(f));
        end
    end
end
if ~isempty(mp4Path)
    fps = 20;
    v = VideoWriter(mp4Path, 'MPEG-4'); v.FrameRate = fps; v.Quality = 95;
    open(v);
    for f = 1:nF
        for k = 1:round(dwell(f)*fps), writeVideo(v, images{f}); end
    end
    close(v);
end
end
