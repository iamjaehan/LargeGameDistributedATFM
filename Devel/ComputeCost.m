function cost = ComputeCost(x, n, m, occupancyMatrix, assigned_sector, sector_ids, sectorIdx, capacity, flightsUnderControl, epsilon, flights, earliest, prevX, timeunit, prevOverloadMask, bigM)

% Update occupancy Matrix based on x
action = zeros(n,1); prevAction = zeros(n,1);
% action(flightsUnderControl) = x - prevX; %minute -> CHECK
action(flightsUnderControl) = x; %minute
prevAction(flightsUnderControl) = prevX;
modifiedOccupancyMatrix = UpdateOccupancyMatrix(occupancyMatrix, assigned_sector, sector_ids, action, flightsUnderControl, flights, earliest, timeunit, prevAction);

% No-new-overload restriction (Definition 4):
%   O_f(x, x'_i) = { (j,tau) : l_j^tau(x) = 0, l_j^tau(x'_i) > 0 } = empty
% prevOverloadMask is O(x^(t)), the overloaded sector-time pairs before this
% sector deviates.
newOverload = (modifiedOccupancyMatrix > capacity) & ~prevOverloadMask;
violation = sum(modifiedOccupancyMatrix(newOverload) - capacity);

% Compute overload cost
overloadCost = ComputeOverLoad(sectorIdx, modifiedOccupancyMatrix, capacity);

% Compute other's overload cost.  sum_{j~=i} L_j = (sum_j L_j) - L_i, so one
% pass over the matrix replaces the m-1 per-sector passes.
secondaryCost = 0;
if epsilon ~= 0
    secondaryCost = ComputeSystemCost(m, modifiedOccupancyMatrix, capacity) - overloadCost;
end

% Compute total cost
cost = overloadCost + epsilon*secondaryCost;

% Inadmissible candidates are lifted above every admissible cost, and ranked
% by the size of the violation so the GA can still search its way back into
% the admissible set instead of seeing a flat infinite plateau.
if violation > 0
    cost = bigM + bigM*violation;
end

end
