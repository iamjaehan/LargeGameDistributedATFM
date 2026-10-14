function out = ComputeSelfCost(sectorIdx, occupancyMatrix, capacity, controlCenter, sector_ids, flights, assignedSector, action, earliest, timeunit)
% Second term of the potential function (13):
%     sum_{tau : (sectorIdx,tau) in O(x)}  C_{ii}^tau * dtau
% i.e. the occupancy that sector i's OWN flights put into sector i, counted
% only on the time bins where sector i is actually overloaded.
%
% The restriction to O(x) is essential: summing C_{ii}^tau over the whole
% horizon gives the total dwell time of the controlled flights, which a
% departure-time shift leaves unchanged.  That would make this term constant
% and collapse the potential to a scaled copy of the system cost (and to a
% pure constant when kappa = 0).

timen = size(occupancyMatrix, 2);
selfOccupancyVector = zeros(1, timen);
sector_id = sector_ids(sectorIdx);
flightsUnderControl = reshape(find(controlCenter == sector_id), 1, []);

for i = flightsUnderControl
    fn = flights(i);
    sectorMap = assignedSector(fn);

    % every segment this flight spends inside its own controlling sector
    for j = 1:size(sectorMap,1)
        if sectorMap(j,1) ~= sector_id
            continue;
        end
        localStart = round(sectorMap(j,2) - earliest + 1 + action(i)*timeunit);
        localEnd   = round(sectorMap(j,3) - earliest + 1 + action(i)*timeunit);
        localStart = max(1, localStart);
        localEnd   = min(timen, localEnd);
        if localEnd < localStart
            continue;
        end
        selfOccupancyVector(localStart:localEnd) = selfOccupancyVector(localStart:localEnd) + 1;
    end
end

overloadedBins = occupancyMatrix(sectorIdx, :) > capacity;   % O(x) restricted to sector i
out = sum(selfOccupancyVector(overloadedBins));

end
