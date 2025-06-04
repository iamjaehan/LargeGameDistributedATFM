function out = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest)

for i = flightsUnderControl
    fn = flights(i);
    sectorMap = assigned_sector(fn);
    sectorNum = size(sectorMap,1);
    
    % Reset flight impact
    for j = 1:sectorNum
        idx = sectorMap(j,1);
        localStart = round(sectorMap(j,2) - earliest + 1);
        localEnd = round(sectorMap(j,3) - earliest +1);
        localIdx = find(sector_ids == idx);
        occupancyMatrix(localIdx, localStart:localEnd) = occupancyMatrix(localIdx, localStart:localEnd) -1;
    end
    
    % Assign modified flight impact
    for j = 1:sectorNum
        idx = sectorMap(j,1);
        localStart = round(sectorMap(j,2) - earliest + 1 + action(i)) ;
        localEnd = round(sectorMap(j,3) - earliest + 1 + action(i)) ;
        localIdx = find(sector_ids == idx);
        occupancyMatrix(localIdx, localStart:localEnd) = occupancyMatrix(localIdx, localStart:localEnd) +1;
    end
end

out = occupancyMatrix;

end