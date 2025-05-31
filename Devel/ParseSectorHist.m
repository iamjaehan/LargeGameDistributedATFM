function flight_sector_map = ParseSectorHist()
% Read the .SECTOR_LIST file
fid = fopen('../Data/20230725_NW_SW_Axis_RegulatedFlw.SECTOR_LIST', 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = lines{1};

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
        flight_id = str2double(parts{1});
        num_sectors = str2double(parts{2});
        cursor = 3;

        data = [];
        for j = 1:num_sectors
            sector_id = str2double(parts{cursor});
            t_start   = str2double(parts{cursor+1});
            t_end     = str2double(parts{cursor+2});
            data = [data; sector_id, t_start, t_end];
            cursor = cursor + 3;
        end

        flight_sector_map(flight_id) = data;
    catch
        continue;  % Skip malformed lines
    end
end

% Now flight_sector_map(flight_id) gives an Nx3 matrix:
% [sector_id, t_start, t_end]

end
