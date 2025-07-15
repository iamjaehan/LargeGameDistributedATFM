function cost = ComputeCost_Centralized(x, n, m, actionSet, occupancyMatrix, assigned_sector, sector_ids, capacity, flights, earliest, timeunit, controlCenter)

epsilon = 0;
cost = 0;
% for i = 1:m
%     sector_id = sector_ids(i);
%     flightsUnderControl = find(controlCenter == sector_id);
%     n_c = length(flightsUnderControl);
%     prevAction = zeros(1,n_c);
%     localCost = ComputeCost(x(flightsUnderControl), n, m, actionSet, occupancyMatrix, assigned_sector, sector_ids, i, capacity, flightsUnderControl, epsilon, flights, earliest, prevAction, timeunit);
%     cost = cost + localCost;
% end

action = x;
modifiedOccu = UpdateOccupancyMatrix_Centralized(n, occupancyMatrix, assigned_sector, sector_ids, action, flights, earliest, timeunit);
cost = ComputeSystemCost(m, modifiedOccu, capacity);

end