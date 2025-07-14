function out = ComputeSelfCost(sectorIdx, occupancyMatrix, controlCenter, sector_ids, flights, assignedSector, action,earliest, timeunit)

out = 0;
selfOccupancyVector = zeros(size(occupancyMatrix(1,:)));
sector_id = sector_ids(sectorIdx);
flightsUnderControl = find(controlCenter == sector_id);

for i = flightsUnderControl
    fn = flights(i);
    sectorMap = assignedSector(fn);

    for j = 1
        localStart = round(sectorMap(j,2) - earliest + 1 + action(i)*timeunit) ;
        localEnd = round(sectorMap(j,3) - earliest + 1 + action(i)*timeunit) ;
        selfOccupancyVector(localStart:localEnd) = selfOccupancyVector(localStart:localEnd) +1;
    end
end

for i = 1:length(selfOccupancyVector)
    out = out + selfOccupancyVector(i);
end

end