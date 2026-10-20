function [flightDelays, occupancyMatrix, info] = SolveStrategicFCFS(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep)
% Strategic first-come-first-served baseline (algorithm 4), as described by
% the reviewer:
%
%   "start with a single trajectory and go adding new trajectories only if
%    they do not violate the load.  The first candidate trajectory that would
%    violate the load is delayed until a departure time that does not
%    violate."
%
% So this is sequential admission, not repair.  The airspace starts EMPTY and
% flights are inserted one at a time in order of scheduled departure -- that
% ordering is what makes it first-come-first-served: an earlier flight keeps
% its slot and later ones absorb the delay.  Each flight takes the earliest
% delay in the action set at which its whole trajectory fits under capacity,
% and once placed it is never moved again.
%
% Bounded action set.  The reviewer's rule ("delayed until a departure time
% that does not violate") is unbounded, but the proposed method may only use
% A = {0, ..., maxActionStep} steps, so this baseline is held to the same set
% for a fair comparison.  A flight that fits at no delay in A is inserted
% anyway, at the delay that adds the least overload; info.nForced counts them.
% Those forced insertions are the only way the result can carry overload.
%
% info: nForced, forcedOverload, totalDelaySteps, nDelayed.

n = length(flights);
m = size(initialOccupancyMatrix, 1);
timen = size(initialOccupancyMatrix, 2);

% Per-flight segments, in simulator indexing (inclusive bins), undelayed.
segSector = cell(n,1); segStart = cell(n,1); segEnd = cell(n,1);
departure = zeros(n,1);
for i = 1:n
    sectorMap = assigned_sector(flights(i));
    [~, localIdx] = ismember(sectorMap(:,1), sector_ids);
    segSector{i} = localIdx;
    segStart{i}  = round(sectorMap(:,2) - earliest + 1);
    segEnd{i}    = round(sectorMap(:,3) - earliest + 1);
    departure(i) = min(segStart{i});
end

% first come, first served: scheduled departure order (index breaks ties)
[~, order] = sortrows([departure, (1:n)']);

occupancyMatrix = zeros(m, timen);      % empty airspace
flightDelays = zeros(n,1);
nForced = 0; forcedOverload = 0;

for i = reshape(order, 1, [])
    ss = segSector{i}; aa = segStart{i}; bb = segEnd{i};

    chosen = -1; bestAdd = inf; bestD = 0;
    for d = 0:maxActionStep
        sh = d*timeunit;
        added = 0;
        for r = 1:numel(ss)
            lo = max(1, aa(r)+sh); hi = min(timen, bb(r)+sh);
            if hi < lo, continue; end
            occ = occupancyMatrix(ss(r), lo:hi);
            % overload this flight would add on top of what is already there
            added = added + sum(max(0, occ + 1 - capacity) - max(0, occ - capacity));
        end
        if added == 0
            chosen = d;          % earliest delay that violates nothing
            break;
        end
        if added < bestAdd
            bestAdd = added; bestD = d;
        end
    end

    if chosen < 0                % fits nowhere in A -- insert at the least-bad delay
        chosen = bestD;
        nForced = nForced + 1;
        forcedOverload = forcedOverload + bestAdd;
    end

    flightDelays(i) = chosen;
    sh = chosen*timeunit;
    for r = 1:numel(ss)
        lo = max(1, aa(r)+sh); hi = min(timen, bb(r)+sh);
        if hi < lo, continue; end
        occupancyMatrix(ss(r), lo:hi) = occupancyMatrix(ss(r), lo:hi) + 1;
    end
end

% the committed schedule must be what the simulator reproduces
check = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, ...
            sector_ids, flightDelays, flights, earliest, timeunit);
assert(isequal(check, occupancyMatrix), 'SolveStrategicFCFS:mismatch', ...
       'Incrementally built occupancy disagrees with the simulator.');

info = struct('nForced', nForced, 'forcedOverload', forcedOverload, ...
              'totalDelaySteps', sum(flightDelays), 'nDelayed', nnz(flightDelays));
end
