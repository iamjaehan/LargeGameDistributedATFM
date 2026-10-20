function [flightDelays, occupancyMatrix, nPass] = SolveStrategicFCFS(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep)
% Strategic first-come-first-served heuristic (algorithm 4).
%
% Unlike the reactive FCFS (algorithm 3), this one plans with the whole day's
% flight plans known in advance, as a pre-departure (strategic) measure.
%
% Overloaded sector-time pairs are visited in chronological order.  At an
% overloaded (s, tau) the flights PRESENT in s at tau are the ones causing it;
% they are served in order of entry into s, so the most recent entrant is
% delayed first, by the smallest step that moves it out of (s, tau).  This
% repeats until the pair is within capacity or no present flight can be
% delayed further (delay capped at maxActionStep, the same action set A as the
% other methods).
%
% A delay can create overload at a bin the pass has already visited (the
% flight's other sectors shift too), so passes repeat until one makes no
% change.  Delays only increase and are bounded, so this terminates.

n = length(flights);
occupancyMatrix = initialOccupancyMatrix;
flightDelays = zeros(n,1);

% Flatten every flight's sector segments into vectors (undelayed, local
% indices), so presence at (s, tau) is one vectorized test.
segFlight = []; segSector = []; segStart = []; segEnd = [];
for i = 1:n
    sectorMap = assigned_sector(flights(i));
    k = size(sectorMap,1);
    [~, localIdx] = ismember(sectorMap(:,1), sector_ids);
    segFlight = [segFlight; i*ones(k,1)];                          %#ok<AGROW>
    segSector = [segSector; localIdx];                             %#ok<AGROW>
    segStart  = [segStart;  round(sectorMap(:,2) - earliest + 1)]; %#ok<AGROW>
    segEnd    = [segEnd;    round(sectorMap(:,3) - earliest + 1)]; %#ok<AGROW>
end

nPass = 0;
changed = true;
while changed
    changed = false;
    nPass = nPass + 1;

    [ss, tt] = find(occupancyMatrix > capacity);
    [tt, order] = sort(tt);
    ss = ss(order);

    for q = 1:length(tt)
        s = ss(q); tau = tt(q);
        while occupancyMatrix(s,tau) > capacity
            shift = flightDelays(segFlight)*timeunit;
            present = segSector == s & segStart + shift <= tau & segEnd + shift >= tau;
            cand = segFlight(present);
            entry = segStart(present) + shift(present);
            delayable = flightDelays(cand) < maxActionStep;
            cand = cand(delayable); entry = entry(delayable);
            if isempty(cand)
                break;   % unresolvable within the action set
            end
            [~, order] = sort(entry, 'descend');   % last come, delayed first
            cand = unique(cand(order), 'stable');

            moved = false;
            for i = cand'
                for newDelay = flightDelays(i)+1:maxActionStep
                    own = segFlight == i & segSector == s;
                    stillIn = any(segStart(own) + newDelay*timeunit <= tau & ...
                                  segEnd(own)   + newDelay*timeunit >= tau);
                    if ~stillIn
                        prevAction = flightDelays; action = flightDelays;
                        action(i) = newDelay;
                        occupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, i, flights, earliest, timeunit, prevAction);
                        flightDelays(i) = newDelay;
                        moved = true; changed = true;
                        break;
                    end
                end
                if moved, break; end
            end
            if ~moved
                break;   % no present flight can leave (s, tau) within the action set
            end
        end
    end
end

end
