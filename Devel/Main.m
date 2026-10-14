% clear all;
%% Dataset selection
% 'europe'  -> 12 country-level agents, all 29 days merged (qualitative demo)
% 'brest'   -> 28 BREST sectors, one traffic date per file; set dataDay
% Parse first with ParseSectorHist('brest') / ParseSectorHist('europe').
dataset = 'brest';
dataDay = '230726';      % '' for datasets stored as a single merged file

[controlledFlights, assigned_sector] = LoadDataset(dataset, dataDay);
flightn = length(controlledFlights);

%% Environment setting
% testName = "real_nTest";

n = flightn; 
epsilon = 1;
algorithm = 1; %1 - Ours, 2 - Centralized, 3 - FCFS
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
% Departure-time adjustments are encoded as integer step counts: the decision
% variable x lives in {0, ..., maxActionStep} and is applied as x*timeunit
% seconds.  At timeunit = 5 min this is the paper's A = {0,5,...,30} minutes.
% The range is set here and enforced by the ga bounds below; no separate
% action vector is passed to the cost functions.
maxActionStep = actionResolution*3;
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
capacity = round(maxOccupancy * 0.75);
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
checkCost = initialOverloadCost;

% Occupancy snapshots feeding VisualizeData.m / the evolution GIFs.
% Collected in a cell and concatenated once at the end: growing the matrix
% with vertcat inside the loop recopies the whole accumulated array every
% time (O(K^2) bytes moved, ~20 MB per append for BREST).  Set to false for
% production runs that do not need the animation.
recordHistory = true;
occupancyHistoryCell = {};
occupancyHistory = [];
if recordHistory
    % frame 0 = the initial schedule.  Also guarantees a non-empty history when
    % no update is ever accepted (e.g. kappa = 0), which would otherwise leave
    % occupancyHistory empty and make VisualizeData.m index out of bounds.
    occupancyHistoryCell{end+1} = occupancyMatrix;
end

% Penalty scale used to enforce the no-new-overload restriction inside the GA.
% sum(initialOccupancyMatrix(:)) upper-bounds any achievable overload cost, so
% any inadmissible candidate is guaranteed to rank below every admissible one.
bigM = 10*(1+epsilon)*sum(initialOccupancyMatrix(:)) + 1;

while true
roundCount = roundCount + 1;
improvedThisRound = false;
nAcceptRound = 0; nInadmRound = 0; nNoImpRound = 0;
disp("====== BRD iteration: "+num2str(roundCount)+" ======")
for i = 1:m % Compute the Best Response for each sector
    sectorIdx = i;
    sector_id = sector_ids(i);
    flightsUnderControl = find(controlCenter == sector_id);
    n_c = length(flightsUnderControl);

    % lb = -actionResolution*ones(n_c,1);
    % ub = actionResolution*ones(n_c,1);
    lb = zeros(n_c,1);
    ub = maxActionStep*ones(n_c,1);
    intcon = 1:n_c;
    
    prevAction = zeros(1,n_c);
    if ~isempty(optAction{i})
        prevAction = optAction{i};
    end

    % O(x^(t)): sector-time pairs already overloaded before sector i deviates.
    % Definition 4 forbids adding anything to this set.
    prevOverloadMask = occupancyMatrix > capacity;

    % ga-based optimizer
    tic
    if n_c > 0
        disp("[r"+num2str(roundCount)+" s"+num2str(i)+"/"+num2str(m)+"] Solving a problem involving "+num2str(n_c)+" flights")
        fitnessFcn = @(x) ComputeCost(x,n,m,occupancyMatrix,assigned_sector,sector_ids,sectorIdx,capacity,flightsUnderControl,epsilon,flights,earliest,prevAction,timeunit,prevOverloadMask,bigM);   
        % Seed the population with the incumbent action.  The best response is
        % an argmin over the admissible set, which always contains the current
        % action, so a correct approximation can never be worse than the status
        % quo.  Without this seed a stochastic GA miss looks identical to "no
        % improving action exists" and terminates the run, falsely reporting a
        % pure Nash equilibrium.
        gaOptions = optimoptions(options, 'InitialPopulationMatrix', prevAction);
        [opt_action, ~] = ga(fitnessFcn,n_c,[],[],[],[],lb,ub,[],intcon,gaOptions);
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

    % ---- Admissibility (Definition 4) + acceptance test (Algorithm 1, l.9) ----
    % (i) the deviation may not overload any sector-time pair that was feasible
    %     before it;  (ii) it is adopted only if it strictly improves the
    %     deviating agent's OWN cost J_i.  Gating on the potential instead is
    %     wrong once O(x) changes: a move that removes overload can raise Phi
    %     and would be rejected.
    newOverloadMask = (tempOccupancyMatrix > capacity) & ~prevOverloadMask;
    admissible = ~any(newOverloadMask(:));

    prevSysCost = ComputeSystemCost(m, occupancyMatrix, capacity);
    candSysCost = ComputeSystemCost(m, tempOccupancyMatrix, capacity);
    Li_prev = ComputeOverLoad(sectorIdx, occupancyMatrix, capacity);
    Li_cand = ComputeOverLoad(sectorIdx, tempOccupancyMatrix, capacity);
    Ji_prev = Li_prev + epsilon*(prevSysCost - Li_prev);   % J_i(x^(t))
    Ji_cand = Li_cand + epsilon*(candSysCost - Li_cand);   % J_i(x^cand)

    accepted = false;
    if ~admissible
        disp("[r"+num2str(roundCount)+" s"+num2str(i)+"] New overload introduced ==> INADMISSIBLE ==> Revert.")
        optAction{i} = prevAction;
        action(flightsUnderControl) = prevAction;
        checkCost = prevSysCost;
        nInadmRound = nInadmRound + 1;
    elseif Ji_cand >= Ji_prev
        disp("[r"+num2str(roundCount)+" s"+num2str(i)+"] No cost improvement ==> Revert.")
        optAction{i} = prevAction;
        action(flightsUnderControl) = prevAction;
        checkCost = prevSysCost;
        nNoImpRound = nNoImpRound + 1;
    else
        occupancyMatrix = tempOccupancyMatrix;
        checkCost = candSysCost;
        improvedThisRound = true;
        accepted = true;
        nAcceptRound = nAcceptRound + 1;
    end

    % Potential function (13), evaluated on the accepted profile (logging only).
    % At epsilon = 1 the (1-epsilon) weight is zero, so the m ComputeSelfCost
    % sweeps cannot change potentialCost -- skipping them is exactly equivalent
    % and avoids an O(m^2) cost per round.
    Cii = 0;
    if epsilon ~= 1
    for k = 1:m
        T_sector_id = sector_ids(k); T_sectorIdx = k; T_flightsUnderControl = find(controlCenter == T_sector_id);
        localAction = zeros(n, 1); 
        if ~isempty(optAction{k})
            localAction(T_flightsUnderControl) = optAction{k};
        end 
        Cii = Cii + ComputeSelfCost(T_sectorIdx, occupancyMatrix, capacity, controlCenter, sector_ids, flights, assigned_sector, localAction,earliest, timeunit);
    end
    end
    potentialCost = (1-epsilon) * Cii + epsilon * checkCost;
    prevPotentialCost = potentialCost;
    if accepted
        statusStr = "ACCEPT";
    else
        statusStr = "revert";
    end
    disp("[r"+num2str(roundCount)+" s"+num2str(i)+"] "+statusStr+" | Potential: "+num2str(potentialCost)+" | System Overload: "+num2str(checkCost));

    costHistory = vertcat(costHistory, checkCost);
    potentialHistory = vertcat(potentialHistory, prevPotentialCost);
    if recordHistory && accepted
        % a reverted iteration leaves occupancyMatrix untouched, so the old
        % unconditional record only ever appended duplicate frames
        occupancyHistoryCell{end+1} = occupancyMatrix; %#ok<SAGROW>
    end
    if checkCost == 0
        break;
    end
end
disp("====== round "+num2str(roundCount)+" done: "+num2str(nAcceptRound)+" accepted, "+ ...
     num2str(nInadmRound)+" inadmissible, "+num2str(nNoImpRound)+" no-improve | overload "+num2str(checkCost)+" ======")
potentialCostOfThisRound = prevPotentialCost;
% (i) a full round over all sectors yields no admissible improving update
%     ==> pure Nash equilibrium w.r.t. the admissible action set, or
% (ii) an overload-free profile was reached mid-round.
if ~improvedThisRound || checkCost == 0
    disp("Termination Condition Satisfied ==> Terminating")
    break;
end
potentialCostOfLastRound = potentialCostOfThisRound;
end

if recordHistory && ~isempty(occupancyHistoryCell)
    occupancyHistory = vertcat(occupancyHistoryCell{:});
end
clear occupancyHistoryCell;

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
lb = zeros(n,1);
ub = maxActionStep*ones(n,1);
intcon = 1:n;

disp("Solving a problem involving "+num2str(n)+" flights")

tic
fitnessFcn = @(x) ComputeCost_Centralized(x, n, m, occupancyMatrix, assigned_sector, sector_ids, capacity, flights, earliest, timeunit, controlCenter);   
% Warm start, matching the decentralized solver.  The centralized problem is
% solved once from the unmodified schedule, so its incumbent is the all-zero
% action; seeding it guarantees the solver never returns a schedule worse than
% doing nothing, and keeps Remark 1's "identical solver assumptions" true.
gaOptions = optimoptions(options, 'InitialPopulationMatrix', zeros(1,n));
[opt_action, postAlgCost] = ga(fitnessFcn,n,[],[],[],[],lb,ub,[],intcon,gaOptions);
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

% timestamp = datestr(now, 'mmdd_HHMMSS');
% if algorithm == 1
%     filename = "../Analysis/Ours_"+testName+"/TestData_"+timestamp;
%     folder = fileparts(filename);
%     if ~isempty(folder) && ~exist(folder, 'dir')
%         mkdir(folder);
%     end
%     save(filename,'m',"postAlgCost",'potentialHistory','costHistory','roundCount','epsilon','optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 2
%     filename = "../Analysis/Centralized_"+testName+"/TestData_"+timestamp;
%     folder = fileparts(filename);
%     if ~isempty(folder) && ~exist(folder, 'dir')
%         mkdir(folder);
%     end
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 3
%     filename = "../Analysis/FCFS_"+testName+"/TestData_"+timestamp;
%     folder = fileparts(filename);
%     if ~isempty(folder) && ~exist(folder, 'dir')
%         mkdir(folder);
%     end
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% end
