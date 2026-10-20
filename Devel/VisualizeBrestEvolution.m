%% BREST sector overload map, from the initial schedule to the equilibrium.
% Run Main.m first (dataset 'brest', algorithm 1, recordHistory = true); this
% script reads occupancyHistory, occupancyHistoryMeta, m, sector_ids,
% capacity and epsilon from the workspace.  It writes (overwriting) to outDir:
%   runs/BrestRun_<tag>.mat    per-sector overload summary for VisualizeBrestCompare
% and, only with makeLayerMaps = true, the per-layer 2x2 maps:
%   BrestFilmstrip_<tag>.png, BrestMap_<tag>.gif / .mp4, BrestMap_<tag>_initial/_final.png

if ~exist('outDir', 'var') || isempty(outDir)
    outDir = '../Analysis/BrestMap';
end
if ~isfolder(outDir), mkdir(outDir); end
if isempty(occupancyHistory)
    error('occupancyHistory is empty - re-run Main.m with recordHistory = true.');
end

geo = ParseBrestGeometry();
nFrames = size(occupancyHistory,1)/m;
frames = cell(1, nFrames);
titles = cell(1, nFrames);
short = cell(1, nFrames);    % row labels of the filmstrip
highlight = zeros(1, nFrames);
for r = 1:nFrames
    frames{r} = occupancyHistory((r-1)*m + (1:m), :);
    rnd = occupancyHistoryMeta(r,1); sIdx = occupancyHistoryMeta(r,2);
    if sIdx == 0
        titles{r} = 'Initial schedule';
        short{r} = 'Initial';
    else
        highlight(r) = sector_ids(sIdx);
        code = geo([geo.id] == highlight(r)).code;
        titles{r} = sprintf('Step %d: round %d, sector %s updates', r-1, rnd, code(end-1:end));
        short{r} = sprintf('Step %d (R%d, %s)', r-1, rnd, code(end-1:end));
    end
end
titles{end} = [titles{end} ' (equilibrium)'];
short{end} = [short{end} ', NE'];

tag = sprintf('D%d_kappa%g', capacity, epsilon);
if exist('makeLayerMaps', 'var') && makeLayerMaps   % optional 2x2 per-layer maps
    pngs = cell(1, nFrames);
    pngs{1} = fullfile(outDir, ['BrestMap_' tag '_initial.png']);
    pngs{end} = fullfile(outDir, ['BrestMap_' tag '_final.png']);
    PlotBrestOverloadMap(geo, frames, titles, sector_ids, capacity, ...
        'Gif', fullfile(outDir, ['BrestMap_' tag '.gif']), ...
        'Mp4', fullfile(outDir, ['BrestMap_' tag '.mp4']), ...
        'Pngs', pngs, 'Highlight', highlight);
    PlotBrestFilmstrip(geo, frames, short, sector_ids, capacity, highlight, ...
        fullfile(outDir, ['BrestFilmstrip_' tag '.png']));
end

% per-sector overload summary of this run, for VisualizeBrestCompare
if ~isfolder(fullfile(outDir, 'runs')), mkdir(fullfile(outDir, 'runs')); end
brestRun = BrestRunFromHistory(occupancyHistory, occupancyHistoryMeta, m, sector_ids, geo, capacity, epsilon); %#ok<NASGU>
save(fullfile(outDir, 'runs', ['BrestRun_' tag '.mat']), 'brestRun');
fprintf('BREST run summary: %d frames, written to %s\n', nFrames, fullfile(outDir, 'runs'));
