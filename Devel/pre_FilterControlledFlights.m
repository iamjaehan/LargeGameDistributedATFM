flight_sector_map = load("flight_sector_map.mat"); flight_sector_map = flight_sector_map.flight_sector_map;

flights = keys(flight_sector_map)';
flights = cell2mat(flights);
n = length(flights);

count = 0;
controlledFlights = int64.empty(n,0);

for i = 1:n
    id = flights(i);
    if ~isempty(flight_sector_map(id))
        count = count+1;
        controlledFlights(count) = id;
    end
end

controlledFlights = controlledFlights(1:count)';
save("controlledFlights.mat","controlledFlights")