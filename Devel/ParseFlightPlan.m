function flight_paths = ParseFlightPlan()
% ParseFlightPlan reads the .so6 file and extracts flight segments.

    % Read the .so6 file
    fid = fopen('../Data/20230725_NW_SW_Axis_RegulatedFlw .so6', 'r');
    lines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = lines{1};

    % Initialize
    flight_paths = containers.Map('KeyType', 'int64', 'ValueType', 'any');

    for i = 1:length(lines)
        parts = strsplit(strtrim(lines{i}));
        if length(parts) < 18
            continue;
        end

        try
            % Parse fields
            t_start   = str2double(parts{4});
            t_end     = str2double(parts{5});
            x1        = str2double(parts{12});
            y1        = str2double(parts{13});
            x2        = str2double(parts{14});
            flight_id = str2double(parts{15});
            seg_idx   = str2double(parts{16});
            y2        = str2double(parts{17});  % ← y2 comes *after* flight_id and seg_idx

            % Store data: [segment_idx, t_start, t_end, x1, y1, x2, y2]
            row = [seg_idx, t_start, t_end, x1, y1, x2, y2];
            if isKey(flight_paths, flight_id)
                flight_paths(flight_id) = [flight_paths(flight_id); row];
            else
                flight_paths(flight_id) = row;
            end
        catch
            continue;
        end
    end

    save("flight_paths.mat", "flight_paths");
end
