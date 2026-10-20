function PlotBrestFilmstrip(geo, frames, frameTitles, sector_ids, capacity, highlight, outPng)
% Chronological filmstrip of the BREST overload map: one row per frame
% (initial schedule, then each accepted best response, top to bottom), one
% column per altitude layer.  Same colour code as PlotBrestOverloadMap; the
% sector that updated in a row is outlined in blue.

nF = numel(frames);
if isempty(highlight), highlight = zeros(1, nF); end
[L, Lmax] = OverloadPerGeoSector(geo, frames, sector_ids, capacity);
ink = [11 11 11]/255; ink2 = [82 81 78]/255;
layers = {'Lower','F','I','U'};
layerTitle = {'Lower (S, TMA)', 'F (FL325-355)', 'I (FL345-375)', 'U (FL365+)'};

fig = figure('Color','w','Units','pixels','Position',[50 50 1100 60 + 235*nF],'Visible','off');
t = tiledlayout(fig, nF, 4, 'TileSpacing','tight', 'Padding','compact');
for f = 1:nF
    for p = 1:4
        ax = nexttile(t);
        DrawBrestLayer(ax, geo, layers{p}, L(:,f), Lmax, highlight(f), [], 7);
        set(ax, 'XTick', [], 'YTick', []);
        if f == 1
            title(ax, layerTitle{p}, 'Color', ink, 'FontWeight', 'bold', 'FontSize', 11);
        end
        if p == 1
            ylabel(ax, sprintf('%s\n%.1f aircraft-min', frameTitles{f}, sum(L(:,f), 'omitnan')), ...
                   'Color', ink, 'FontWeight', 'bold', 'FontSize', 9);
        end
    end
end
okFill = 0.55*[1 1 1] + 0.45*[12 163 12]/255;
lowRed = [246 201 201]/255; critical = [208 59 59]/255; nRamp = 64;
colormap(fig, [okFill; lowRed + (critical - lowRed).*linspace(0,1,nRamp)']);
fr = 1/(nRamp+1);
cb = colorbar(ax, 'Ticks', [0.5*fr, fr + (1-fr)*sqrt([0.1 0.4 1])], ...
    'TickLabels', compose('%.0f', [0 0.1 0.4 1]*Lmax), 'Color', ink2);
cb.Layout.Tile = 'east';
cb.Label.String = 'Daily cumulative overload L_i [aircraft-min]  (green = 0, gray = no traffic, blue outline = sector updating)';
exportgraphics(fig, outPng, 'Resolution', 130);
close(fig);
end
