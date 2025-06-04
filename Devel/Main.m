% Load data
controlledFlights = load("controlledFlights.mat"); controlledFlights = controlledFlights.controlledFlights;
sectors = load("sectors.mat"); sector_id_order = sectors.sector_id_order; sectors = sectors.sectors;
flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); assigned_sector = flight_sector_map.flight_sector_map;
flightn = length(controlledFlights);

%% Environment setting
% For smaller problem
n = flightn;
flights = controlledFlights(1:n);

capacity = 20;

%% Environment identification
% Identify simTime and involved sectors
sector_ids = [];
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
simTime = earliest:latest;
timen = length(simTime);
sectorn= length(sector_ids);

%% Compute the initial occupancy metric
occupancyMatrix = zeros(sectorn, timen);
for i = 1:n
    fn = flights(i); % fn: flight number
    sectorMap = assigned_sector(fn);
    sectorNum = size(sectorMap,1);
    for j = 1:sectorNum
        idx = sectorMap(j,1);
        localStart = round(sectorMap(j,2) - earliest + 1);
        localEnd = round(sectorMap(j,3) - earliest +1);
        localIdx = find(sector_ids == idx);
        occupancyMatrix(localIdx, localStart:localEnd) = occupancyMatrix(localIdx, localStart:localEnd) + 1;
    end
end
initialOccupancyMatrix = occupancyMatrix;

% Plot initial occupancy
hmSimTime = seconds(simTime);
hmSimTime.Format = 'hh:mm';
figure(2); clf; hold on;
for i = 1:sectorn
    % plot(simTime,occupancyMatrix(i,:));
    plot(hmSimTime,occupancyMatrix(i,:));
end
plot([seconds(0), seconds(3600*24-1)], [capacity, capacity],'r--')
labels = arrayfun(@num2str, sector_ids, 'UniformOutput', false);
legend(labels)
grid on

%% Identify control center for each flight
controlCenter = int64.empty(n,0);
for i = 1:n
    fn = flights(i);
    sectorMap = assigned_sector(fn);
    controlCenter(i) = sectorMap(1,1);
end

%% Declare overloaded area and time
% Reduce the overload below capacity - 6


%% Search Equilibrium

% - Sectors control affected flights
% - We should choose an action that alleviates the overloaded space.
% - Sectors choose the best response.
% - Questions
    % 1. How to escape infeasibility? - Soft constaint? Repair?
    % 2. Threshold Public Goods Game?
    % 3. Just say the cost is an overwhelmed cost?