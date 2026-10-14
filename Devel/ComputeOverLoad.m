function out = ComputeOverLoad(sectorIdx, occupancyMatrix, capacity)

% Cumulative overload of one sector: sum_tau max(0, occupancy - D) * dtau.
% Vectorized; occupancies are integer-valued so this is bit-identical to the
% previous element-wise accumulation loop.
out = sum(max(0, occupancyMatrix(sectorIdx, :) - capacity));

end
