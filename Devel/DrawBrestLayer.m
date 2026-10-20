function DrawBrestLayer(ax, geo, layer, L, Lmax, highlightId, countries, fontSize)
% Draw one altitude layer of the BREST overload map into ax.
%
%   layer        'Lower' | 'F' | 'I' | 'U'
%   L            daily cumulative overload per geo sector [aircraft-min]
%                (NaN = no traffic), indexed like geo
%   Lmax         top of the colour scale (shared across frames)
%   highlightId  geo id of the sector that just updated (0 = none)
%   countries    shaperead struct for background borders ([] = none)
%
% Fill: green = no overload, red ramp (sqrt scale) = overload, gray = no
% traffic.  Every sector carries its code and, when overloaded, its value.

good   = [12 163 12]/255;  okFill = 0.55*[1 1 1] + 0.45*good;
lowRed = [246 201 201]/255; critical = [208 59 59]/255;
noData = [230 230 227]/255; edge = [0.35 0.35 0.33];
ink = [11 11 11]/255; ink2 = [82 81 78]/255; hiBlue = [42 120 214]/255;

hold(ax, 'on');
for c = 1:numel(countries)
    plot(ax, countries(c).Lon, countries(c).Lat, '-', 'Color', [0.78 0.78 0.76], 'LineWidth', 0.5);
end
plot(ax, union([geo.shape]), 'FaceColor', 'none', 'EdgeColor', ink2, 'LineWidth', 1, 'LineStyle', '--');

hiShape = [];
for k = find(strcmp({geo.layer}, layer))
    v = L(k);
    if isnan(v)
        col = noData; txt = ink2;
    elseif v == 0
        col = okFill; txt = ink;
    else
        s = sqrt(v/Lmax);
        col = lowRed + (critical - lowRed)*s;
        txt = ink; if s > 0.55, txt = [1 1 1]; end
    end
    plot(ax, geo(k).shape, 'FaceColor', col, 'FaceAlpha', 1, 'EdgeColor', edge, 'LineWidth', 0.7);
    if geo(k).id == highlightId
        hiShape = geo(k).shape;
    end
    [cx, cy] = centroid(geo(k).shape);
    lab = geo(k).code(end-1:end);
    if strcmp(geo(k).code, 'LFRBFIS'), lab = 'TMA'; end
    if ~isnan(v) && v > 0
        lab = sprintf('%s\n%.1f', lab, v);
    end
    text(ax, cx, cy, lab, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
         'FontSize', fontSize, 'Color', txt, 'FontWeight', 'bold');
end
if ~isempty(hiShape)   % drawn last so no neighbour covers the outline
    plot(ax, hiShape, 'FaceColor', 'none', 'EdgeColor', hiBlue, 'LineWidth', 3.5);
end

allShape = union([geo.shape]);
[bx, by] = boundingbox(allShape);
xlim(ax, bx + [-0.4 0.4]); ylim(ax, by + [-0.3 0.3]);
daspect(ax, [1/cosd(mean(by)) 1 1]);
set(ax, 'Box','on', 'XColor', ink2, 'YColor', ink2, 'TickDir','out');
end
