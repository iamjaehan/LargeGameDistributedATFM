function cost = ComputeCost(x, n, m, actionSet, occupancyMatrix, assigned_sector, sector_ids, sectorIdx, capacity, flightsUnderControl, epsilon, flights, earliest)

% Update occupancy Matrix based on x
action = zeros(n,1);
% action(flightsUnderControl) = actionSet(x+3); %minute
k = (x + 2)/4;
action(flightsUnderControl) = actionSet(1)*(1 - k) + actionSet(end)*k;
modifiedOccupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest);

% Compute overload cost
overloadCost = ComputeOverLoad(sectorIdx, modifiedOccupancyMatrix, capacity);

% Compute other's overload cost
secondaryCost = 0;
for i = 1:m
    if sectorIdx ~= i
        secondaryCost = secondaryCost + ComputeOverLoad(i, modifiedOccupancyMatrix, capacity);
    end
end

% Compute total cost
cost = overloadCost + epsilon*secondaryCost;

end