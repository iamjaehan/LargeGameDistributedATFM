function cost = ComputeSystemCost(m, occupancyMatrix, capacity)

cost = 0;
for i = 1:m
    cost = cost + ComputeOverLoad(i, occupancyMatrix, capacity);
end

end