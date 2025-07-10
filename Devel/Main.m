% Load data
controlledFlights = load("controlledFlights.mat"); controlledFlights = controlledFlights.controlledFlights;
% sectors = load("sectors.mat"); sectors = sectors.sectors;
% flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); assigned_sector = flight_sector_map.flight_sector_map;
flightn = length(controlledFlights);

%% Environment setting
n = flightn;
n = 200;

if n < flightn
    flights = controlledFlights(sort(randperm(flightn,n)));
else
    flights = controlledFlights(1:n);
end

capacity = 15;
timeunit = 15; %minutes
epsilon = 1e-5;

actionSet = -2:2; actionSet = actionSet * timeunit;
timeunit = timeunit * 60;

%% Environment identification
% Identify simTime and involved sectors
sector_ids = [];
earliest = inf;
latest = 0;
for i = 1:n
    fn = flights(i);
    sectorMap = assigned_sector(fn);
    sectorNum = size(sectorMap,1);
    sector_ids = vertcat(sector_ids,sectorMap(:,1));
    startTime = sectorMap(1,2);
    endTime = sectorMap(sectorNum,3);
    if startTime < earliest
        earliest = startTime;
    end
    if endTime > latest
        latest = endTime;
    end
end
earliest = earliest - timeunit*2; latest = latest + timeunit*2;
simTime = earliest:latest;
timen = length(simTime);
sector_ids_test = sector_ids;
sector_ids = unique(sector_ids);
m = length(sector_ids); %sectorn

%% Compute the initial occupancy metric
occupancyMatrix = zeros(m, timen);
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
initialOverloadCost = ComputeSystemCost(m, initialOccupancyMatrix, capacity);

%% Identify control center for each flight
controlCenter = int64.empty(n,0);
for i = 1:n
    fn = flights(i);
    sectorMap = assigned_sector(fn);
    controlCenter(i) = sectorMap(1,1);
end

%% Reduce problem size --- Further filter 'controlling sectors'
% Need to modify m, OccuMat, initialOccuMat, initialOverloadCost,
% sector_ids

% controllingSectors = unique(controlCenter);
% m = length(controllingSectors);
% [~,controllingSectorsIdx] = ismember(controllingSectors, sector_ids);
% occupancyMatrix = occupancyMatrix(controllingSectorsIdx,:);
% sector_ids = controllingSectors;

% Plot initial occupancy
initialOccupancyMatrix = occupancyMatrix;
initialOverloadCost = ComputeSystemCost(m, initialOccupancyMatrix, capacity);
PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 2);

%% Search Equilibrium
options = optimoptions('ga','Display','off','UseParallel', true, 'UseVectorized', false);

disp("BRD iteration: "+num2str(1))
optAction = cell(m,1);
solveTime = zeros(m,1);

for i = 1:m % Compute the Best Response for each sector
    sector_id = sector_ids(i);
    sectorIdx = i;
    flightsUnderControl = find(controlCenter == sector_id);
    n_c = length(flightsUnderControl);

    lb = -2*ones(n_c,1);
    ub = 2*ones(n_c,1);
    intcon = 1:n_c;
    
    prevAction = zeros(1,n_c);
    if ~isempty(optAction{i})
        prevAction = optAction{i};
    end
    % ga-based optimizer
    tic
    if n_c > 0
        disp("Solving a problem involving "+num2str(n_c)+" flights")
        fitnessFcn = @(x) ComputeCost(x,n,m,actionSet,occupancyMatrix,assigned_sector,sector_ids,sectorIdx,capacity,flightsUnderControl,epsilon,flights,earliest,prevAction,timeunit);   
        [opt_action, ~] = ga(fitnessFcn,n_c,[],[],[],[],lb,ub,[],intcon,options);
        optAction{i} = opt_action;
        disp("FIR "+num2str(sector_id)+" action: "+num2str(opt_action));
        drawnow;
    end
    solveTime(i) = toc;
    % Update occupancyMatrix
    if ~isempty(optAction{i})
        action = zeros(n_c,1); action(flightsUnderControl) = optAction{i};
        prevActionVector = zeros(n,1);
        prevActionVector(flightsUnderControl) = prevAction;
        occupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest, timeunit, prevActionVector);
    end
end
PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 3);
PlotOccupancy(occupancyMatrix - initialOccupancyMatrix, simTime, sector_ids, m, capacity, 4);

initialOverloadCost
postAlgCost = ComputeSystemCost(m, occupancyMatrix, capacity)

%%

% 
% for i = 1:m
%     if ~isempty(optAction{i})
%         sector_id = sector_ids(i);
%         sectorIdx = i;
%         flightsUnderControl = find(controlCenter == sector_id); n_c = length(flightsUnderControl);
%         action = zeros(n_c,1); action(flightsUnderControl) = optAction{i};
%         occupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest);
%     end
% end