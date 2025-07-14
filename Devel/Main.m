% Load data
controlledFlights = load("controlledFlights.mat"); controlledFlights = controlledFlights.controlledFlights;
% sectors = load("sectors.mat"); sectors = sectors.sectors;
% flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); assigned_sector = flight_sector_map.flight_sector_map;
flightn = length(controlledFlights);

%% Environment setting
% n = flightn;
n = 100;

if n < flightn
    % idd = sort(randperm(round(flightn/3),n))+round(flightn/10);
    % idd =  sort(randperm(flightn,n));
    % flights = controlledFlights(idd);
    flights = controlledFlights(500:500+n);
else
    flights = controlledFlights(1:n);
end

capacity = 32;
timeunit = 15; %minutes
epsilon = 1;

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

%% Iteration part
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
        action = zeros(n,1); action(flightsUnderControl) = optAction{i};
        prevActionVector = zeros(n,1);
        prevActionVector(flightsUnderControl) = prevAction;
        occupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest, timeunit, prevActionVector);
    end
    checkCost = ComputeSystemCost(m, occupancyMatrix, capacity);
    Cii = 0;
    for k = 1:m
        T_sector_id = sector_ids(k); T_sectorIdx = k; T_flightsUnderControl = find(controlCenter == T_sector_id);
        localAction = zeros(n, 1); 
        if ~isempty(optAction{k})
            localAction(T_flightsUnderControl) = optAction{k};
        end
        Cii = Cii + ComputeSelfCost(T_sectorIdx, occupancyMatrix, controlCenter, sector_ids, flights, assigned_sector, localAction,earliest, timeunit);
    end
    potential = (1-epsilon) * Cii + epsilon * checkCost;
    disp("Potential Cost: "+num2str(potential));
end
PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 3);
PlotOccupancy(occupancyMatrix - initialOccupancyMatrix, simTime, sector_ids, m, capacity, 4);

postAlgCost = ComputeSystemCost(m, occupancyMatrix, capacity);
disp("Initial: "+num2str(initialOverloadCost)+" / Post: "+num2str(postAlgCost)+" / Potential: "+num2str(potential));
disp("==========")