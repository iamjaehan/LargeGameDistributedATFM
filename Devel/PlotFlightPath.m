function PlotFlightPath(flight_paths, flight_id, flip_longitude)
% plotFlightPath Plots the flight path of a specific flight
% - flight_paths: containers.Map from flight_id to N×7 matrix
% - flight_id: ID of the flight to visualize
% - flip_longitude: true if you want to flip x-axis for correct orientation

    if ~isKey(flight_paths, flight_id)
        warning('Flight ID %d not found in map.', flight_id);
        return;
    end

    data = flight_paths(flight_id);  % N×7 matrix
    x = [data(:,4); data(end,6)];
    y = [data(:,5); data(end,7)];

    if flip_longitude
        x = -x;  % Flip left-right
    end

    figure;
    plot(x, y, 'r-', 'LineWidth', 2); hold on;
    scatter(x(1), y(1), 60, 'g', 'filled', 'DisplayName', 'Start');
    scatter(x(end), y(end), 60, 'b', 'filled', 'DisplayName', 'End');
    title(sprintf('Flight Path for Flight ID: %d', flight_id));
    xlabel('Longitude (Projected)');
    ylabel('Latitude (Projected)');
    legend;
    axis equal;
    grid on;
end
