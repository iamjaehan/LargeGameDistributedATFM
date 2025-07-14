function cost = ComputeCost(x, n, m, actionSet, occupancyMatrix, assigned_sector, sector_ids, sectorIdx, capacity, flightsUnderControl, epsilon, flights, earliest, prevX, timeunit)

% Update occupancy Matrix based on x
action = zeros(n,1); prevAction = zeros(n,1);
% action(flightsUnderControl) = x - prevX; %minute -> CHECK
action(flightsUnderControl) = x; %minute
prevAction(flightsUnderControl) = prevX;
modifiedOccupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest, timeunit, prevAction);

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

% k = (x + 2)/4;
% action(flightsUnderControl) = actionSet(1)*(1 - k) + actionSet(end)*k;