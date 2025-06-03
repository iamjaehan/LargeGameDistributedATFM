%% Parsing airspace sector 
% sectors = ParseSectorInfo();
% flight_paths = ParseFlightPlan();
% flight_sector_map = ParseSectorHist();
sectors = load("sectors.mat"); sector_id_order = sectors.sector_id_order; sectors = sectors.sectors;
flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); flight_sector_map = flight_sector_map.flight_sector_map;

%% Plotting
figure(1); clf; hold on; axis equal;

lonlim = [-35 45];
latlim = [15 80];
worldmap('World');
worldmap(latlim,lonlim);

load coastlines
% plot(coastlon, coastlat, 'LineWidth', 1)
plotm(coastlat, coastlon, 'LineWidth', 1)
hold on

indices = cell2mat(keys(sectors));
for i = 1:length(indices)
    sid = indices(i);                  % sector ID
    polygons = sectors(sid);           % cell array of polygons
    for j = 1:length(polygons)
        coords = polygons{j}/60;          % Nx2 [lon, lat]
        plotm(coords(:,2), coords(:,1), 'k','LineWidth',1.2);  % black outline
        if sid == 112 || sid == 95 || sid == 10
        % if sid == 16 || sid == 112 || sid == 243
            plotm(coords(:,2), coords(:,1), 'r','LineWidth',4); 
        end
    end
end
xlabel('Longitude (Projected)');
ylabel('Latitude (Projected)');
title('Airspace Sectors');
grid on;

flight_ids = cell2mat(keys(flight_paths));

for i = 1:1
    % flight_id = flight_ids(i);
    flight_id = 263653925;
    data = flight_paths(flight_id)/60;  % N×7 matrix
    x = data(:,4);
    y = data(:,5);
    
    if false
        x = -x;  % Flip left-right
    end
    
    % plot(x, y, 'r-', 'LineWidth', 2); hold on;
    % scatter(x(1), y(1), 60, 'g', 'filled', 'DisplayName', 'Start');
    % scatter(x(end), y(end), 60, 'b', 'filled', 'DisplayName', 'End');
    plotm(y(1), x(1), 60, 'g.','MarkerSize',15);
    plotm(y(end), x(end), 60, 'b.','MarkerSize',15);
    plotm(y, x, 'r-', 'LineWidth', 2,'LineWidth',1.2); hold on;
end
axis equal;
grid on;
