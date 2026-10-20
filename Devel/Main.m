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
algorithm = 1; %1 - Ours, 3 - FCFS (reactive), 4 - Strategic FCFS, 5 - Centralized MILP (BREST only); 2 (GA centralized) removed
milpMaxTime = 3600;      % s, intlinprog time limit for algorithm 5
brMaxTime = 600;         % s, intlinprog time limit for each best response (algorithm 1)
% capacity = 7;

timeunit = 5; %minutes
rng(10);  % fix seed

fcfsLookahead = 30;      % min, how far ahead the reactive FCFS (algorithm 3) detects overload
fcfsScanStep  = 5;       % min, how often it scans

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
% The range is set here and passed to every solver as maxActionStep.
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
occupancyHistoryMeta = zeros(0,2);   % per frame: [round, deviating sector index]; [0 0] = initial
if recordHistory
    % frame 0 = the initial schedule.  Also guarantees a non-empty history when
    % no update is ever accepted (e.g. kappa = 0), which would otherwise leave
    % occupancyHistory empty and make VisualizeData.m index out of bounds.
    occupancyHistoryCell{end+1} = occupancyMatrix;
    occupancyHistoryMeta(end+1,:) = [0 0];
end

nInexactBR = 0;   % best responses not proven optimal (time limit / no solution)

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

    prevAction = zeros(1,n_c);
    if ~isempty(optAction{i})
        prevAction = optAction{i};
    end

    % O(x^(t)): sector-time pairs already overloaded before sector i deviates.
    % Definition 4 forbids adding anything to this set.
    prevOverloadMask = occupancyMatrix > capacity;

    % Exact best response (problem (16)) as a MILP; Definition 4 is a hard
    % constraint inside it, and the current action is the warm start.
    tic
    if n_c > 0
        disp("[r"+num2str(roundCount)+" s"+num2str(i)+"/"+num2str(m)+"] Solving a problem involving "+num2str(n_c)+" flights")
        [opt_action, brInfo] = SolveBestResponseMILP(occupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, flightsUnderControl, prevAction, sectorIdx, epsilon, brMaxTime);
        optAction{i} = opt_action;
        if ~brInfo.exact
            nInexactBR = nInexactBR + 1;
            disp("[r"+num2str(roundCount)+" s"+num2str(i)+"] best response NOT proven optimal (exitflag "+num2str(brInfo.exitflag)+", gap "+num2str(brInfo.absoluteGap)+")")
        end
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
    % The MILP already enforces (i); the check stays as a guard.
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
        occupancyHistoryMeta(end+1,:) = [roundCount, sectorIdx]; %#ok<SAGROW>
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
disp("Initial: "+num2str(initialOverloadCost)+" / Post: "+num2str(postAlgCost)+" / Potential: "+num2str(potentialCostOfThisRound)+" / inexact best responses: "+num2str(nInexactBR));
disp("==========")

%% Centralized GA -- removed; use algorithm 5 (Centralized MILP)
elseif algorithm == 2
error('Main:removed', 'Algorithm 2 (GA centralized) was removed. Use algorithm 5 (Centralized MILP).');
%% FCFS (reactive / tactical)
elseif algorithm == 3
tic
[flightDelays, occupancyMatrix] = SolveReactiveFCFS(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, fcfsLookahead*60, fcfsScanStep*60);
solveTime = toc;
disp("Reactive FCFS: "+num2str(nnz(flightDelays))+" flights delayed")
%% Strategic FCFS (whole-day flight plans known in advance)
elseif algorithm == 4
tic
[flightDelays, occupancyMatrix, fcfsInfo] = SolveStrategicFCFS(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep);
solveTime = toc;
disp("Strategic FCFS: "+num2str(fcfsInfo.nDelayed)+" flights delayed, "+ ...
     num2str(fcfsInfo.nForced)+" could not be placed within the action set (added overload "+ ...
     num2str(fcfsInfo.forcedOverload)+")")
%% Centralized MILP (exact, intlinprog) -- BREST only for now
elseif algorithm == 5
if ~strcmp(dataset, 'brest')
    error('Main:milpDataset', 'The MILP benchmark (algorithm 5) is set up for the BREST dataset only.');
end
[optAction, occupancyMatrix, milpInfo] = SolveMILP(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, milpMaxTime);
solveTime = milpInfo.buildTime + milpInfo.solveTime;
disp("MILP: overload "+num2str(milpInfo.overload)+" (lower bound "+num2str(milpInfo.overloadLowerBound)+ ...
     ", exitflag "+num2str(milpInfo.exitflag)+", "+num2str(milpInfo.solveTime,'%.1f')+" s) | "+ ...
     num2str(milpInfo.nDelayed)+" flights delayed, "+num2str(milpInfo.totalDelaySteps)+" delay steps")
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
% elseif algorithm == 4
%     filename = "../Analysis/StrategicFCFS_"+testName+"/TestData_"+timestamp;
%     folder = fileparts(filename);
%     if ~isempty(folder) && ~exist(folder, 'dir')
%         mkdir(folder);
%     end
%     save(filename,'m',"postAlgCost",'flightDelays', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity")
% elseif algorithm == 5
%     filename = "../Analysis/MILP_"+testName+"/TestData_"+timestamp;
%     folder = fileparts(filename);
%     if ~isempty(folder) && ~exist(folder, 'dir')
%         mkdir(folder);
%     end
%     save(filename,'m',"postAlgCost",'optAction', 'occupancyMatrix',"solveTime","simTime","sector_ids","capacity","milpInfo")
% end
