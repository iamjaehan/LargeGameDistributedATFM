function [controlledFlights, assigned_sector, meta] = LoadDataset(datasetName, day)
% Load a dataset written by ParseSectorHist.
%
%   [cf, as] = LoadDataset('europe')            % merged file
%   [cf, as] = LoadDataset('brest', '230726')   % one traffic date
%   LoadDataset('brest')                        % lists the available dates
%
% Returns the flight ids and the flight -> [agent t_enter t_exit] map that
% Main.m expects.

if nargin < 2, day = ''; end

if isempty(day)
    f = sprintf('parsed/%s.mat', lower(datasetName));
    if ~isfile(f)
        avail = dir(sprintf('parsed/%s_*.mat', lower(datasetName)));
        if isempty(avail)
            error('LoadDataset:notParsed', ...
                  'No parsed data for "%s". Run ParseSectorHist(''%s'') first.', ...
                  datasetName, datasetName);
        end
        dates = regexprep({avail.name}, sprintf('^%s_(.*)\\.mat$', lower(datasetName)), '$1');
        error('LoadDataset:dayRequired', ...
              '"%s" is stored per date. Pass one of: %s', ...
              datasetName, strjoin(dates, ', '));
    end
else
    f = sprintf('parsed/%s_%s.mat', lower(datasetName), day);
    if ~isfile(f)
        error('LoadDataset:noSuchDay', 'Not found: %s', f);
    end
end

S = load(f);
controlledFlights = S.controlledFlights;
assigned_sector   = S.flight_sector_map;
meta              = S.meta;
fprintf('LoadDataset: %s  (%d flights, %d agents, source %s)\n', ...
        f, meta.nFlights, meta.nAgents, meta.source);
end
