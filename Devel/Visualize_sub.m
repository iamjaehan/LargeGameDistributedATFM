lonlim = [-35 45];
latlim = [15 80]; %For whole Europe
worldmap('World');
worldmap(latlim,lonlim);

% draw coastlines
load coastlines
plotm(coastlat, coastlon, 'LineWidth', 1)
hold on
set(gcf,'Position',[800 100 800 800])
% geoshow(countries(idx), 'DisplayType','polygon','FaceColor',[1 0 0],'FaceAlpha',0.2,'EdgeColor','red','EdgeAlpha',0.2,'LineWidth',1.5);

% draw country edges
for i = 1:length(names)
    countryName = names{i};
    idx = strcmp(names, countryName);
    geoshow(countries(idx), 'DisplayType','polygon','FaceColor',[1 1 1],'FaceAlpha',0,'EdgeColor','k','EdgeAlpha',0.2,'LineWidth',1.5);
end