function cfg = SectorListProfile(name)
% Layout and aggregation rules for each .SECTOR_LIST dataset.
%
% The European and BREST files have DIFFERENT column layouts, and the old code
% switched between them by hand-editing two places marked "WARNING".  Getting
% one of them wrong failed silently (the parse loop's try/catch swallowed the
% error and produced an empty or wrong map with no message), so the layout now
% lives here and is verified against the file before parsing.
%
% Fields:
%   file        path to the .SECTOR_LIST, relative to Devel/
%   dateField   column holding the YYMMDD traffic date
%   countField  column holding the number of sectors crossed
%   firstSector column of the first [sector, t_enter, t_exit] triple
%   aggregate   'country' -> 12 country-level agents (via GetFABFromSectorIndex)
%               'sector'  -> raw sector ids as agents
%   splitByDate default for writing one .mat per traffic date
%
% Observed layouts:
%   europe : 263246006 1 230713 230713 15 193 39001.0 39151.0 223 ...
%            id        ? date   date   n  s1  t0      t1      s2
%   brest  : 263246006 0 1084.25 230713 230713 3 21 41701.0 41947.0 22 ...
%            id        ? ?       date   date   n s1 t0      t1      s2

switch lower(name)
    case 'europe'
        cfg.file        = '../Data/general_initial_flow_NW_SW_Axis.SECTOR_LIST';
        cfg.dateField   = 3;
        cfg.countField  = 5;
        cfg.firstSector = 6;
        cfg.aggregate   = 'country';
        cfg.splitByDate = false;   % 29 days; merged, as the qualitative demo uses it

    case 'brest'
        cfg.file        = '../Data_4/BREST.SECTOR_LIST';
        cfg.dateField   = 4;
        cfg.countField  = 6;
        cfg.firstSector = 7;
        cfg.aggregate   = 'sector';
        cfg.splitByDate = true;    % 29 days; one usable instance per day

    case 'brest-0726'
        % the pre-extracted single-day file, same layout as the master
        cfg.file        = '../Data_4/BREST230726.SECTOR_LIST';
        cfg.dateField   = 4;
        cfg.countField  = 6;
        cfg.firstSector = 7;
        cfg.aggregate   = 'sector';
        cfg.splitByDate = false;

    otherwise
        error('SectorListProfile:unknown', ...
              'Unknown dataset "%s". Known: europe, brest, brest-0726.', name);
end

cfg.name = lower(name);
end
