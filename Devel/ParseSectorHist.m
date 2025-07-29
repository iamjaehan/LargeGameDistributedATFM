function flight_sector_map = ParseSectorHist()
    % Read the .SECTOR_LIST file
    fid = fopen('../Data/general_initial_flow_NW_SW_Axis.SECTOR_LIST', 'r');
    lines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    lines = lines{1};
    
    SectorNameList = load("SectorNameList.mat"); SectorNameList = SectorNameList.SectorNameList;
    % fab_name_to_index = containers.Map( ...
    %     {'FABEC', 'UK-IRE', 'NE-FAB', 'DK-SE-FAB', 'SW-FAB'}, ...
    %      1:5);
    fab_name_to_index = containers.Map( ...
        {'Belgium', 'Denmark', 'France', 'Germany', 'Ireland', 'Netherlands', 'Norway', 'Portugal', 'Spain', 'Sweden', 'Switzerland', 'United Kingdom'}, ...
         1:12);


    % First line is number of entries — optional check
    num_entries = str2double(lines{1});

    % Initialize: flight_sector_map: containers.Map<flight_id, Nx3 matrix>
    % Each row: [sector_id, t_start, t_end]
    flight_sector_map = containers.Map('KeyType', 'int64', 'ValueType', 'any');
    
    for i = 2:length(lines)
        parts = strsplit(strtrim(lines{i}));
        if isempty(parts)
            continue;
        end

        try
            flight_id   = str2double(parts{1});
            num_sectors = str2double(parts{5});  % correct index
            cursor      = 6;                     % start of sector data

            data = [];
            t_start = 0;
            t_end = 0;
            for j = 1:num_sectors
                sector_id = str2double(parts{cursor});
                % Get FAB name → index
                fab_name = GetFABFromSectorIndex(sector_id, SectorNameList);
                fab_idx  = fab_name_to_index(fab_name);

                t_start   = str2double(parts{cursor+1});
                if t_start < t_end
                    break;
                end
                t_end     = str2double(parts{cursor+2});
                if t_end < t_start
                    % t_end = t_end s+ 86400; % If exceeds 24 hrs. Reset and terminate
                    t_end = t_start;
                    data = [data; fab_idx, t_start, t_end];
                    break;
                end
                data = [data; fab_idx, t_start, t_end];
                cursor = cursor + 3;
            end

            flight_sector_map(flight_id) = data;
        catch
            continue;  % Skip malformed lines
        end
    end



    save("flight_sector_map.mat", "flight_sector_map");
end
