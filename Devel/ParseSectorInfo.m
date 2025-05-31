function [sectors, sector_id_order] = ParseSectorInfo()
% ParseSectorInfo parses the .are file into sector polygons and tracks order.
%   sectors: Map from sector_id to {polygon1, polygon2, ...}
%   sector_id_order: List of sector_ids in the order they appear in the file

    % Read the .are file
    fid = fopen('../Data/sectors_2307.are', 'r');
    lines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = lines{1};

    % Initialize
    sectors = containers.Map('KeyType','int32','ValueType','any');
    sector_id_order = [];  % <-- NEW: ordered list of sector IDs
    i = 1;

    while i <= length(lines)
        line = strtrim(lines{i});
        tokens = strsplit(line);

        % Check for header line (sector ID line)
        if length(tokens) >= 2 && ~isnan(str2double(tokens{1}))
            sector_id = str2double(tokens{1});
            coords = [];
            i = i + 1;

            % Read coordinate lines
            while i <= length(lines)
                coord_tokens = strsplit(strtrim(lines{i}));
                if length(coord_tokens) ~= 2
                    break;
                end
                lat = str2double(coord_tokens{1});
                lon = str2double(coord_tokens{2});
                if isnan(lat) || isnan(lon)
                    break;
                end
                coords = [coords; lon, lat];  % (x, y) = (lon, lat)
                i = i + 1;
            end

            % Save to map
            if isKey(sectors, sector_id)
                tmp = sectors(sector_id);
                tmp{end+1} = coords;
                sectors(sector_id) = tmp;
            else
                sectors(sector_id) = {coords};
                sector_id_order(end+1) = sector_id;  % <-- Record appearance order
            end
        else
            i = i + 1;
        end
    end

    disp(['Parsed ', num2str(sectors.Count), ' sector IDs.']);
    save("sectors.mat", "sectors", "sector_id_order");
end
