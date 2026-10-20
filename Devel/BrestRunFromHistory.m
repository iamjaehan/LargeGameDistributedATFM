function run = BrestRunFromHistory(occupancyHistory, occupancyHistoryMeta, m, sector_ids, geo, capacity, epsilon)
% Summarise the occupancy snapshots Main.m records (recordHistory = true) for
% PlotBrestOverlayCompare: per frame (initial, then each accepted best
% response) the daily overload of every BREST sector, a step label, and the
% geo id of the sector that updated.  Only these summaries are kept, so the
% result is small enough to store in the repository.
nF = size(occupancyHistory,1)/m;
frames = cell(1, nF);
steps = cell(1, nF);
highlight = zeros(1, nF);
for f = 1:nF
    frames{f} = occupancyHistory((f-1)*m + (1:m), :);
    rnd = occupancyHistoryMeta(f,1); sIdx = occupancyHistoryMeta(f,2);
    if sIdx == 0
        steps{f} = 'Initial';
    else
        highlight(f) = sector_ids(sIdx);
        code = geo([geo.id] == highlight(f)).code;
        steps{f} = sprintf('Step %d (round %d, %s)', f-1, rnd, code(end-1:end));
    end
end
run = struct('label', sprintf('\\kappa = %g', epsilon), 'capacity', capacity, 'epsilon', epsilon, ...
             'L', OverloadPerGeoSector(geo, frames, sector_ids, capacity), ...
             'steps', {steps}, 'highlight', highlight);
end
