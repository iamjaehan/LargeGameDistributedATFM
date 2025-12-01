folderPath = '../Analysis/Ours_nTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = length(matFiles);
ours = cell(oursLen,1);
for k = 1:oursLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    ours{k} = data;
end

%% Choose the data of interest
test = ours{end};

%% Extract information
occupancyMatrix = test.occupancyMatrix;
simTime = test.simTime;
sector_id = test.sector_ids;
m = test.m;
capacity = test.capacity;

%% Load sector information
sectors = load("sectors.mat"); sector_id_order = sectors.sector_id_order; sectors = sectors.sectors;
flight_paths = load("flight_paths.mat"); flight_paths = flight_paths.flight_paths;
flight_sector_map = load("flight_sector_map.mat"); flight_sector_map = flight_sector_map.flight_sector_map;
FIRs = load("FIRs.mat"); FIRs = FIRs.FIRs;

%%