function PlotBrestOverloadMap(geo, frames, frameTitles, sector_ids, capacity, varargin)
% Animated map of BREST sector overload, one frame per occupancy snapshot.
%
%   PlotBrestOverloadMap(geo, frames, frameTitles, sector_ids, capacity, ...
%       'Gif', path, 'Mp4', path, 'Pngs', {path or '' per frame}, ...
%       'Highlight', ids)
%
%   frames      cell of m x T occupancy matrices (rows follow sector_ids)
%   frameTitles cell of strings, one per frame
%   Highlight   geo id of the sector that updated in each frame (0 = none)
%
% Four panels, one per altitude layer (sectors overlap vertically, never
% within a layer); see DrawBrestLayer for the colour code.  The colour scale
% is fixed across frames.  The first and last frames are held longer.

opt = inputParser;
addParameter(opt, 'Gif', '');
addParameter(opt, 'Mp4', '');
addParameter(opt, 'Pngs', {});
addParameter(opt, 'Highlight', []);
parse(opt, varargin{:});
opt = opt.Results;

nF = numel(frames);
highlight = opt.Highlight;
if isempty(highlight), highlight = zeros(1, nF); end
[L, Lmax] = OverloadPerGeoSector(geo, frames, sector_ids, capacity);
countries = brestCountries(geo);
ink = [11 11 11]/255; ink2 = [82 81 78]/255;
layers = {'Lower','F','I','U'};
layerTitle = {'Lower (S sectors, TMA)', 'F (FL325-355)', 'I (FL345-375)', 'U (FL365+)'};

images = cell(1, nF);
for f = 1:nF
    fig = figure('Color','w','Units','pixels','Position',[50 50 1150 980],'Visible','off');
    t = tiledlayout(fig, 2, 2, 'TileSpacing','compact', 'Padding','compact');
    for p = 1:4
        ax = nexttile(t);
        DrawBrestLayer(ax, geo, layers{p}, L(:,f), Lmax, highlight(f), countries, 9);
        set(ax, 'FontSize', 9);
        title(ax, layerTitle{p}, 'Color', ink, 'FontWeight', 'bold', 'FontSize', 11);
    end
    addColorbar(fig, t, ax, Lmax, ink2);
    title(t, sprintf('%s  |  total overload %.1f aircraft-min  |  overloaded sectors %d', ...
          frameTitles{f}, sum(L(:,f), 'omitnan'), nnz(L(:,f) > 0)), ...
          'FontSize', 13, 'FontWeight', 'bold', 'Color', ink);

    if numel(opt.Pngs) >= f && ~isempty(opt.Pngs{f})
        exportgraphics(fig, opt.Pngs{f}, 'Resolution', 150);
    end
    if ~isempty(opt.Gif) || ~isempty(opt.Mp4)
        tmp = [tempname '.png'];
        exportgraphics(fig, tmp, 'Resolution', 100);
        images{f} = imread(tmp);
        delete(tmp);
    end
    close(fig);
end

if isempty(opt.Gif) && isempty(opt.Mp4), return; end

% common, even frame size (H.264 needs even dimensions)
h = 2*floor(size(images{1},1)/2); w = 2*floor(size(images{1},2)/2);
for f = 1:nF
    images{f} = imresize(images{f}, [h w]);
end
hold_s = 0.7*2.5; step_s = 0.7*1.0;   % 30% faster than 1.0 s / 2.5 s
dwell = step_s*ones(1, nF); dwell([1 nF]) = hold_s;

if ~isempty(opt.Gif)
    for f = 1:nF
        [A, map] = rgb2ind(images{f}, 256);
        if f == 1
            imwrite(A, map, opt.Gif, 'gif', 'LoopCount', Inf, 'DelayTime', dwell(f));
        else
            imwrite(A, map, opt.Gif, 'gif', 'WriteMode', 'append', 'DelayTime', dwell(f));
        end
    end
end
if ~isempty(opt.Mp4)
    fps = 20;
    v = VideoWriter(opt.Mp4, 'MPEG-4');
    v.FrameRate = fps; v.Quality = 95;
    open(v);
    for f = 1:nF
        for r = 1:round(dwell(f)*fps)
            writeVideo(v, images{f});
        end
    end
    close(v);
end
end

function countries = brestCountries(geo)
[bx, by] = boundingbox(union([geo.shape]));
shp = fullfile(fileparts(mfilename('fullpath')), 'ne_110m_admin_0_countries', 'ne_110m_admin_0_countries.shp');
countries = shaperead(shp, 'UseGeoCoords', true, ...
    'BoundingBox', [bx(1)-1 by(1)-1; bx(2)+1 by(2)+1]);
end

function addColorbar(fig, t, ax, Lmax, ink2)
okFill = 0.55*[1 1 1] + 0.45*[12 163 12]/255;
lowRed = [246 201 201]/255; critical = [208 59 59]/255;
nRamp = 64;
colormap(fig, [okFill; lowRed + (critical - lowRed).*linspace(0,1,nRamp)']);
fr = 1/(nRamp+1);
cb = colorbar(ax, 'Ticks', [0.5*fr, fr + (1-fr)*sqrt([0.1 0.4 1])], ...
    'TickLabels', compose('%.0f', [0 0.1 0.4 1]*Lmax), 'Color', ink2);
cb.Layout.Tile = 'east';
cb.Label.String = 'Daily cumulative overload L_i [aircraft-min]  (green = 0, gray = no traffic, blue outline = sector updating)';
end
