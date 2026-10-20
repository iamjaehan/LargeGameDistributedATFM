function [flightDelays, occupancyMatrix] = SolveReactiveFCFS(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, lookahead, scanStep)
% Reactive (tactical) first-come-first-served baseline (algorithm 3, paper
% Section 6.2): "When an overload is detected, the imminent flight scheduled
% to enter the congested sector is delayed using the same discrete action set
% A as in our model, until feasibility is restored or no further delay options
% remain."
%
% Time only moves forward.  Every scanStep bins the controller looks
% lookahead bins ahead; each overloaded (s, tau) found there is treated in
% chronological order.  The flights that would be in s at tau and have not
% departed yet are the ones a ground delay can still move; the most imminent
% entrant into s is delayed first, by the smallest step that takes it out of
% (s, tau).  This repeats until (s, tau) is within capacity or no such flight
% is left.  Flights already airborne at the scan time are never touched.
%
% The previous version looked only at occupancy AT the scan time and delayed
% flights entering AFTER it, which cannot change that occupancy; every
% candidate therefore ended at the maximum delay.

n = length(flights);
timen = size(initialOccupancyMatrix, 2);
occupancyMatrix = initialOccupancyMatrix;
flightDelays = zeros(n,1);

% Flatten every flight's sector segments (undelayed, inclusive bins).
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
departure = accumarray(segFlight, segStart, [n 1], @min);   % first entry = departure

for t = 1:scanStep:timen
    win = t : min(timen, t + lookahead - 1);
    [ss, tt] = find(occupancyMatrix(:, win) > capacity);
    tt = tt + t - 1;
    [tt, order] = sort(tt);
    ss = ss(order);

    for q = 1:length(tt)
        s = ss(q); tau = tt(q);
        while occupancyMatrix(s,tau) > capacity
            shift = flightDelays(segFlight)*timeunit;
            present = segSector == s & segStart + shift <= tau & segEnd + shift >= tau;
            notDeparted = departure(segFlight) + shift > t;
            delayable = flightDelays(segFlight) < maxActionStep;
            cand = present & notDeparted & delayable;
            if ~any(cand)
                break;   % no delay option remains for this overload
            end
            [~, order] = sort(segStart(cand) + shift(cand));   % imminent entrant first
            candFlights = segFlight(cand);
            candFlights = unique(candFlights(order), 'stable');

            moved = false;
            for i = candFlights'
                own = segFlight == i & segSector == s;
                for newDelay = flightDelays(i)+1:maxActionStep
                    stillIn = any(segStart(own) + newDelay*timeunit <= tau & ...
                                  segEnd(own)   + newDelay*timeunit >= tau);
                    if ~stillIn
                        flightDelays(i) = newDelay;
                        occupancyMatrix = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, flightDelays, flights, earliest, timeunit);
                        moved = true;
                        break;
                    end
                end
                if moved, break; end
            end
            if ~moved
                break;
            end
        end
    end
end

end
