function cost = ComputeSystemCost(m, occupancyMatrix, capacity)

% sum_i L_i(x), in a single pass over the occupancy matrix.
cost = sum(max(0, occupancyMatrix(1:m, :) - capacity), 'all');

end
