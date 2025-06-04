function out = ComputeOverLoad(sectorIdx, occupancyMatrix, capacity)

localIdx = sectorIdx;
occupancyVector = occupancyMatrix(localIdx, :);

out = 0;
for i = 1:length(occupancyVector)
    if occupancyVector(i) > capacity
        out = out + (occupancyVector(i) - capacity);
    end
end

end