function FIRs = ParseFIRGeometry()

% --- Step 1: Parse .gsl (FIRs only) ---
% fid = fopen('../Data/sectors_2307.gsl', 'r');
fid = fopen('../Data_4/BREST.gsl','r');
gsl_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
gsl_lines = gsl_lines{1};

FIRs = struct('name', {}, 'id', {}, 'arc_ids', {}, 'polygons', {});
i = 1;
while i <= length(gsl_lines)
    line = gsl_lines{i};
    if startsWith(line, 'S;')
        tokens = strsplit(line, ';');

        name = tokens{2};
        id = str2double(tokens{4});
        arc_ids = {};

        i = i + 1;
        while i <= length(gsl_lines) && startsWith(gsl_lines{i}, 'A;')
            arc_tokens = strsplit(gsl_lines{i}, ';');
            arc_ids{end+1} = arc_tokens{2};  % e.g., '492ED'
            i = i + 1;
        end

        FIRs(end+1).name = name;
        FIRs(end).id = id;
        FIRs(end).arc_ids = arc_ids;
    else
        i = i + 1;
    end
end

SectorNameList = {};
for i = 1:length(gsl_lines)
    if startsWith(gsl_lines{i}, 'S;')
        tokens = strsplit(gsl_lines{i}, ';');
        SectorNameList{end+1} = tokens{2};  % store sector name
    end
end

% --- Step 2: Parse .gar arcs ---
fid = fopen('../Data/sectors_2307.gar', 'r');
% fid = fopen('../Data_4/BREST.gar', 'r');
gar_lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
gar_lines = gar_lines{1};

arc_map = containers.Map();  % arc_id → polygon (Nx2)

i = 1;
while i <= length(gar_lines)
    line = strtrim(gar_lines{i});
    if startsWith(line, 'A;')
        tokens = strsplit(line, ';');
        arc_id = tokens{2};
        coords = [];

        i = i + 1;
        while i <= length(gar_lines) && startsWith(strtrim(gar_lines{i}), 'P;')
            pt = strsplit(strtrim(gar_lines{i}), ';');
            lat = str2double(pt{2});
            lon = str2double(pt{3});
            coords = [coords; lon, lat];  % lon, lat for plotting
            i = i + 1;
        end

        arc_map(arc_id) = coords;
    else
        i = i + 1;
    end
end

% --- Step 3: Assign polygons to FIRs ---
for k = 1:length(FIRs)
    FIRs(k).polygons = {};
    for j = 1:length(FIRs(k).arc_ids)
        arc_id = FIRs(k).arc_ids{j};
        if isKey(arc_map, arc_id)
            FIRs(k).polygons{end+1} = arc_map(arc_id);
        end
    end
end

save("FIRs.mat","FIRs")
save("SectorNameList.mat","SectorNameList");

end
