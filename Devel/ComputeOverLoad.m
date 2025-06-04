function out = ComputeOverLoad(sectorIdx, sector_ids, occupancyMatrix, capacity)

localIdx = find(sector_ids == sectorIdx);
occupancyVector = occupancyMatrix(localIdx, :);

out = 0;
for i = 1:length(occupancyVector)
    if occupancyVector(i) > capacity
        out = out + occupancyVector(i);
    end
end

end