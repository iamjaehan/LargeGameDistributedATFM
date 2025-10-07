% clear all;
% Load data
controlledFlights = load("controlledFlights.mat"); controlledFlights = controlledFlights.controlledFlights;
flight_sector_map = load("flight_sector_map.mat"); assigned_sector = flight_sector_map.flight_sector_map;
flightn = length(controlledFlights);

%% Environment setting
% testName = "real_nTest";

% n = flightn; 
% epsilon = 0;
% algorithm = 3; %1 - Ours, 2 - Centralized, 3 - FCFS
% capacity = 7;

timeunit = 5; %minutes
rng(10);  % fix seed

timeStart = hours(7);
timeEnd   = hours(10);

if n < flightn
    % idd = sort(randperm(round(flightn/10),n));
    idd =  sort(randperm(flightn,n));
    flights = controlledFlights(idd);
    % flights = controlledFlights(200:200+n);
else
    flights = controlledFlights(1:n);
end

actionResolution = 2;
% actionSet = -actionResolution:actionResolution; actionSet = actionSet * timeunit;
actionSet = 0:actionResolution*3; actionSet = actionSet * timeunit;
timeunit = timeunit * 60;

rng('shuffle');

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
earliest = earliest - timeunit*actionResolution; latest = latest + timeunit*actionResolution * 6;
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
maxOccupancy = max(initialOccupancyMatrix(:));
capacity = round(maxOccupancy * 0.90);
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
% initialOccupancyMatrix = occupancyMatrix;
% initialOverloadCost = ComputeSystemCost(m, initialOccupancyMatrix, capacity);

% PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 2);

%% Search Equilibrium (Ours)
if algorithm == 1
options = optimoptions('ga','Display','off','UseParallel', true, 'UseVectorized', false);
optAction = cell(m,1);
solveTime = zeros(m,1);
potentialCost = inf;
prevPotentialCost = inf;
potentialCostOfLastRound = inf;
roundCount = 0;

costHistory = [];
potentialHistory = [];
action = zeros(n,1);

while true
roundCount = roundCount + 1;
disp("====== BRD iteration: "+num2str(roundCount)+" ======")
for i = 1:m % Compute the Best Response for each sector
    sectorIdx = i;
    sector_id = sector_ids(i);
    flightsUnderControl = find(controlCenter == sector_id);
    n_c = length(flightsUnderControl);

    % lb = -actionResolution*ones(n_c,1);
    % ub = actionResolution*ones(n_c,1);
    lb = zeros(n_c,1);
    ub = 6*ones(n_c,1);
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
        % disp("FIR "+num2str(sector_id)+" action: "+num2str(opt_action));
        drawnow;
    else
        continue;
    end
    solveTime(i) = toc;
    % Update occupancyMatrix
    if ~isempty(optAction{i})
        action(flightsUnderControl) = optAction{i};
        tempOccupancyMatrix = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, action, flights, earliest, timeunit);
    else
        tempOccupancyMatrix = occupancyMatrix;
    end

    % Check viability
    checkCost = ComputeSystemCost(m, tempOccupancyMatrix, capacity);
    Cii = 0;
    for k = 1:m
        T_sector_id = sector_ids(k); T_sectorIdx = k; T_flightsUnderControl = find(controlCenter == T_sector_id);
        localAction = zeros(n, 1); 
        if ~isempty(optAction{k})
            localAction(T_flightsUnderControl) = optAction{k};
        end 
        Cii = Cii + ComputeSelfCost(T_sectorIdx, tempOccupancyMatrix, controlCenter, sector_ids, flights, assigned_sector, localAction,earliest, timeunit);
    end
    potentialCost = (1-epsilon) * Cii + epsilon * checkCost;
    disp("Potential Cost: "+num2str(potentialCost));
    if potentialCost > prevPotentialCost
        disp("Increased Potential Cost ==> Revert.")
        optAction{i} = prevAction;
        action(flightsUnderControl) = prevAction;
    else
        occupancyMatrix = tempOccupancyMatrix;
        prevPotentialCost = potentialCost;
    end
    costHistory = vertcat(costHistory, checkCost);
    potentialHistory = vertcat(potentialHistory, prevPotentialCost);
    if checkCost == 0
        break;
    end
end
potentialCostOfThisRound = prevPotentialCost;
if potentialCostOfThisRound == potentialCostOfLastRound || checkCost == 0
    disp("Termination Condition Satisfied ==> Terminating")
    break;
end
potentialCostOfLastRound = potentialCostOfThisRound;
end

% PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 3);
% PlotOccupancy(occupancyMatrix - initialOccupancyMatrix, simTime, sector_ids, m, capacity, 4);

postAlgCost = ComputeSystemCost(m, occupancyMatrix, capacity);
disp("Initial: "+num2str(initialOverloadCost)+" / Post: "+num2str(postAlgCost)+" / Potential: "+num2str(potentialCostOfThisRound));
disp("==========")

%% Centralized Algorithm
elseif algorithm == 2
options = optimoptions('ga','UseParallel', true,'Display','off');
% lb = -actionResolution*ones(n,1);
% ub = actionResolution*ones(n,1);
lb = -actionResolution*zeros(n,1);
ub = 6*ones(n,1);
intcon = 1:n;

disp("Solving a problem involving "+num2str(n)+" flights")

tic
fitnessFcn = @(x) ComputeCost_Centralized(x, n, m, actionSet, occupancyMatrix, assigned_sector, sector_ids, capacity, flights, earliest, timeunit, controlCenter);   
[opt_action, postAlgCost] = ga(fitnessFcn,n,[],[],[],[],lb,ub,[],intcon,options);
optAction = opt_action;
solveTime = toc;

occupancyMatrix = UpdateOccupancyMatrix_Centralized(n, occupancyMatrix, assigned_sector, sector_ids, optAction, flights, earliest, timeunit);

% PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 3);
% PlotOccupancy(occupancyMatrix - initialOccupancyMatrix, simTime, sector_ids, m, capacity, 4);

postAlgCost = ComputeSystemCost(m, occupancyMatrix, capacity);
disp("Initial: "+num2str(initialOverloadCost)+" / Post: "+num2str(postAlgCost));
disp("==========")
%% FCFS
elseif algorithm == 3
tic
% 초기 설정
flightDelays = zeros(n,1);  % action vector
maxDelayStep = 4;
delayOptions = 0:maxDelayStep;  % FCFS는 정방향만 보자
occupancyMatrix = initialOccupancyMatrix;

% 시간 설정
startIdx = round(seconds(timeStart - seconds(earliest))) + 1;
endIdx   = round(seconds(timeEnd   - seconds(earliest))) + 1;
startIdx = max(1, startIdx);
endIdx   = min(timen, endIdx);
stepSize = 300; % 5분
simStepIndices = startIdx:stepSize:endIdx;

% 전체 시간, 섹터 순회
stepLen = length(simStepIndices);
count = 0;
for t = simStepIndices
    count = count + 1;
    disp("CurStep: " + num2str(count) + " out of " + num2str(stepLen));
    for s = 1:m
        if occupancyMatrix(s,t) > capacity
            % 1. 미래에 해당 sector로 진입할 예정인 flight 찾기
            futureFlights = [];
            futureTimes = [];
            for i = 1:n
                fn = flights(i);
                sectorMap = assigned_sector(fn);
                for j = 1:size(sectorMap,1)
                    sectorID = sectorMap(j,1);
                    entryTime = round(sectorMap(j,2) - earliest + 1 + flightDelays(i)*timeunit);
                    if sectorID == sector_ids(s) && entryTime > t
                        futureFlights(end+1) = i;
                        futureTimes(end+1) = entryTime;
                        break;
                    end
                end
            end

            % 2. entryTime 순으로 정렬 (FCFS)
            [~, order] = sort(futureTimes);
            orderedFlights = futureFlights(order);

            % 3. 순서대로 delay 시도
            for idx = 1:length(orderedFlights)
                i = orderedFlights(idx);
                delayApplied = false;
                for d = delayOptions
                    newDelay = flightDelays(i) + d;
                    if newDelay > maxDelayStep
                        continue;
                    end
                    testDelays = flightDelays;
                    testDelays(i) = newDelay;
                    tempOccu = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, testDelays, flights, earliest, timeunit);
                    if tempOccu(s,t) <= capacity
                        flightDelays(i) = newDelay;
                        occupancyMatrix = tempOccu;
                        delayApplied = true;
                        break;
                    end
                end
                % delay로도 해결 안되면 최대 delay 적용
                if ~delayApplied
                    flightDelays(i) = maxDelayStep;
                    testDelays = flightDelays;
                    tempOccu = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, testDelays, flights, earliest, timeunit);
                    occupancyMatrix = tempOccu;
                end
                if occupancyMatrix(s,t) <= capacity
                    break;
                end
            end
        end
    end
end
solveTime = toc;
end

% PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, 3);
% PlotOccupancy(occupancyMatrix - initialOccupancyMatrix, simTime, sector_ids, m, capacity, 4);

postAlgCost = ComputeSystemCost(m, occupancyMatrix, capacity);
disp("Initial: "+num2str(initialOverloadCost)+" / Post: "+num2str(postAlgCost));
disp("==========")

%% Save result
% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1
%     filename = "../Analysis/Ours_tight/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized_tight/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 3
%     filename = "../Analysis/FCFS_tight/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end

% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1
%     filename = "../Analysis/Ours/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 3
%     filename = "../Analysis/FCFS/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end

% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1
%     filename = "../Analysis/Ours_distributed/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized_distributed/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 3
%     filename = "../Analysis/FCFS_distributed/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end

% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1 && epsilon == 1
%     filename = "../Analysis/Ours_nTest_tight/TestData_"+timestamp+"_"+n;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 1 && epsilon == 0
%     filename = "../Analysis/NonCoop_nTest_tight/TestData_"+timestamp+"_"+n;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized_nTest_tight/TestData_"+timestamp+"_"+n;
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end

% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1
%     filename = "../Analysis/Ours_real_kTest/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized_real_kTest/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 3
%     filename = "../Analysis/FCFS_real_kTest/TestData_"+timestamp;
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end

timestamp = datestr(now, 'mmdd_HHMMSS');
if algorithm == 1
    filename = "../Analysis/Ours_"+testName+"/TestData_"+timestamp;
    folder = fileparts(filename);
    if ~isempty(folder) && ~exist(folder, 'dir')
        mkdir(folder);
    end
    save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
elseif algorithm == 2
    filename = "../Analysis/Centralized_"+testName+"/TestData_"+timestamp;
    folder = fileparts(filename);
    if ~isempty(folder) && ~exist(folder, 'dir')
        mkdir(folder);
    end
    save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
elseif algorithm == 3
    filename = "../Analysis/FCFS_"+testName+"/TestData_"+timestamp;
    folder = fileparts(filename);
    if ~isempty(folder) && ~exist(folder, 'dir')
        mkdir(folder);
    end
    save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
end
