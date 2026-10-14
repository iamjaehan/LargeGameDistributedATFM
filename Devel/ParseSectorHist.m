function manifest = ParseSectorHist(datasetName, splitByDate)
% Parse a .SECTOR_LIST file into per-flight sector occupancy records.
%
%   ParseSectorHist('europe')        % 12 country agents, all days merged
%   ParseSectorHist('brest')         % 28 sectors, one .mat per traffic date
%   ParseSectorHist('brest', false)  % override the profile's split setting
%
% Writes parsed/<dataset>.mat or parsed/<dataset>_<YYMMDD>.mat, each holding
%   flight_sector_map : containers.Map(int64 flight id -> [agent t_enter t_exit])
%   controlledFlights : sorted int64 column of the flight ids in that map
%   meta              : dataset, date, counts
% Load them with LoadDataset.

cfg = SectorListProfile(datasetName);
if nargin >= 2 && ~isempty(splitByDate)
    cfg.splitByDate = logical(splitByDate);
end

if ~isfile(cfg.file)
    error('ParseSectorHist:missingFile', 'Cannot find %s', cfg.file);
end

fid = fopen(cfg.file, 'r');
lines = textscan(fid, '%s', 'Delimiter', '\n');
fclose(fid);
lines = lines{1};
if numel(lines) < 2
    error('ParseSectorHist:emptyFile', '%s has no data lines', cfg.file);
end

% ---- verify the declared layout against the file before parsing ----------
probe = strsplit(strtrim(lines{2}));
if numel(probe) < cfg.firstSector + 2
    error('ParseSectorHist:layout', ...
          ['%s: first data line has %d columns, too few for profile "%s" ' ...
           '(expects a sector triple starting at column %d).'], ...
          cfg.file, numel(probe), cfg.name, cfg.firstSector);
end
if isempty(regexp(probe{cfg.dateField}, '^\d{6}$', 'once'))
    error('ParseSectorHist:layout', ...
          ['%s: column %d is "%s", not a YYMMDD date. The profile "%s" does not ' ...
           'match this file''s layout -- check SectorListProfile.'], ...
          cfg.file, cfg.dateField, probe{cfg.dateField}, cfg.name);
end
probeN = str2double(probe{cfg.countField});
if ~(probeN >= 1 && probeN <= 500 && probeN == fix(probeN))
    error('ParseSectorHist:layout', ...
          ['%s: column %d is "%s", not a plausible sector count. The profile ' ...
           '"%s" does not match this file''s layout.'], ...
          cfg.file, cfg.countField, probe{cfg.countField}, cfg.name);
end

useCountry = strcmp(cfg.aggregate, 'country');
if useCountry
    SectorNameList = load('SectorNameList.mat'); SectorNameList = SectorNameList.SectorNameList;
    agentIndex = containers.Map( ...
        {'Belgium','Denmark','France','Germany','Ireland','Netherlands', ...
         'Norway','Portugal','Spain','Sweden','Switzerland','United Kingdom'}, 1:12);
else
    SectorNameList = [];
    agentIndex = [];
end

fprintf('ParseSectorHist: %s  [%s, agents=%s, split=%d]\n', ...
        cfg.file, cfg.name, cfg.aggregate, cfg.splitByDate);

byDate = containers.Map('KeyType','char','ValueType','any');
nSkipped = 0; nParsed = 0;

for i = 2:numel(lines)
    parts = strsplit(strtrim(lines{i}));
    if numel(parts) < cfg.firstSector + 2
        nSkipped = nSkipped + 1; continue;
    end
    try
        flight_id = int64(str2double(parts{1}));
        dayKey    = parts{cfg.dateField};
        nSec      = str2double(parts{cfg.countField});
        cursor    = cfg.firstSector;

        data = []; t_start = 0; t_end = 0;
        for j = 1:nSec
            if cursor + 2 > numel(parts), break; end
            sector_id = str2double(parts{cursor});

            if useCountry
                fab = GetFABFromSectorIndex(sector_id, SectorNameList);
                if ~isKey(agentIndex, fab), break; end
                agent = agentIndex(fab);
            else
                agent = sector_id;
            end

            t_start = str2double(parts{cursor+1});
            if t_start < t_end, break; end          % out-of-order: stop here
            t_end = str2double(parts{cursor+2});
            if t_end < t_start                      % wraps past midnight
                t_end = t_start;
                data = [data; agent, t_start, t_end]; %#ok<AGROW>
                break;
            end
            data = [data; agent, t_start, t_end];    %#ok<AGROW>
            cursor = cursor + 3;
        end

        if isempty(data), nSkipped = nSkipped + 1; continue; end

        if ~cfg.splitByDate, dayKey = 'all'; end
        if ~isKey(byDate, dayKey)
            byDate(dayKey) = containers.Map('KeyType','int64','ValueType','any');
        end
        m = byDate(dayKey);
        m(flight_id) = data; %#ok<NASGU>
        nParsed = nParsed + 1;
    catch
        nSkipped = nSkipped + 1;
    end
end

if nParsed == 0
    error('ParseSectorHist:noData', ...
          'Parsed 0 flights from %s -- the layout profile is almost certainly wrong.', cfg.file);
end
if nSkipped > 0.05*(nParsed + nSkipped)
    warning('ParseSectorHist:manySkipped', ...
            'Skipped %d of %d lines (%.1f%%) in %s -- check the layout profile.', ...
            nSkipped, nParsed+nSkipped, 100*nSkipped/(nParsed+nSkipped), cfg.file);
end

if ~isfolder('parsed'), mkdir('parsed'); end
dayKeys = sort(keys(byDate));
manifest = struct('dataset', {}, 'date', {}, 'file', {}, 'flights', {}, 'agents', {});

for k = 1:numel(dayKeys)
    dayKey = dayKeys{k};
    flight_sector_map = byDate(dayKey); %#ok<NASGU>
    ids = cell2mat(keys(byDate(dayKey)))';
    controlledFlights = sort(int64(ids)); %#ok<NASGU>

    agents = [];
    mm = byDate(dayKey); kk = keys(mm);
    for q = 1:numel(kk)
        rec = mm(kk{q});
        agents = [agents; rec(:,1)]; %#ok<AGROW>
    end
    agents = unique(agents);

    if strcmp(dayKey,'all')
        outName = sprintf('parsed/%s.mat', cfg.name);
    else
        outName = sprintf('parsed/%s_%s.mat', cfg.name, dayKey);
    end
    meta = struct('dataset', cfg.name, 'date', dayKey, 'source', cfg.file, ...
                  'nFlights', numel(controlledFlights), 'nAgents', numel(agents), ...
                  'aggregate', cfg.aggregate, ...
                  'parsedOn', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))); %#ok<NASGU>
    save(outName, 'flight_sector_map', 'controlledFlights', 'meta');

    fprintf('  %-28s  %5d flights  %4d agents\n', outName, numel(controlledFlights), numel(agents));
    manifest(end+1) = struct('dataset', cfg.name, 'date', dayKey, 'file', outName, ...
                             'flights', numel(controlledFlights), 'agents', numel(agents)); %#ok<AGROW>
end

fprintf('ParseSectorHist: %d flights parsed, %d lines skipped, %d file(s) written.\n', ...
        nParsed, nSkipped, numel(dayKeys));
end
