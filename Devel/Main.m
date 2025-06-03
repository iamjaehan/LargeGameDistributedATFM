% Load data
controlledFlights = load("controlledFlights.mat"); controlledFlights = controlledFlights.controlledFlights;
sectors = load("sectors.mat"); sector_id_order = sectors.sector_id_order; sectors = sectors.sectors;
flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); assigned_sector = flight_sector_map.flight_sector_map;
flightn = length(controlledFlights);

% For smaller problem
n = flightn;
flights = controlledFlights(1:n);

%% Environment identification
% Identify simTime and involved sectors
sector_ids = [];
simTime = earliest:latest;
earliest = inf;
latest = 0;
for i = 1:n
    fn = flights(i);
    sectorMap = assigned_sector(fn);
    sectorNum = size(sectorMap,1);
    sector_ids = unique(vertcat(sector_ids,sectorMap(:,1)));
    startTime = sectorMap(1,2);
    endTime = sectorMap(sectorNum,3);
    if startTime < earliest
        earliest = startTime;
    end
    if endTime > latest
        latest = endTime;
    end
end
sectorn= length(sector_ids);

%% Compute the occupancy metric
occupancyMatrix = zeros(sectorn, length(simTime));
for i = 1:n
    fn = flights(i); % fn: flight number
    sectorMap = assigned_sector(fn);
    sectorNum = size(sectorMap,1);
    for j = 1:sectorNum
        idx = sectorMap(j,1);
        localStart = sectorMap(j,2) - earliest + 1;
        localEnd = sectorMap(j,3) - earliest +1;
        localIdx = find(sector_ids == idx);
        occupancyMatrix(localIdx, localStart:localEnd) = occupancyMatrix(localIdx, localStart:localEnd) + 1;
    end
end

figure(1); clf; hold on;
for i = 1:sectorn
    plot(simTime,occupancyMatrix(i,:));
end
labels = arrayfun(@num2str, sector_ids, 'UniformOutput', false);
legend(labels)
grid on

%% Declare overloaded area and time

%% Filter controllable flights

%% Search Equilibrium

% - Sectors control affected flights
% - We should choose an action that alleviates the overloaded space.
% - Sectors choose the best response.
% - Questions
    % 1. How to escape infeasibility? - Soft constaint? Repair?
    % 2. Threshold Public Goods Game?
    % 3. Just say the cost is an overwhelmed cost?