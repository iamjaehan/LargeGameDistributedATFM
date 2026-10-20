%% Side-by-side BREST overload maps of two runs (default: kappa = 0 vs 1).
% Each run must first be produced by Main.m (dataset 'brest', algorithm 1,
% recordHistory = true) followed by VisualizeBrestEvolution, which stores its
% summary in <outDir>/runs/BrestRun_D<D>_kappa<k>.mat.  Set compareD and
% compareKappas before running to change the pair.  Writes (overwriting):
%   BrestCompare_D<D>_kappa<a>_vs_<b>.gif / .mp4
%   BrestCompareFilmstrip_D<D>_kappa<a>_vs_<b>.png

if ~exist('outDir', 'var') || isempty(outDir), outDir = '../Analysis/BrestMap'; end
if ~exist('compareD', 'var') || isempty(compareD), compareD = 7; end
if ~exist('compareKappas', 'var') || isempty(compareKappas), compareKappas = [0 1]; end

geo = ParseBrestGeometry();
clear runs
for q = 1:numel(compareKappas)
    f = fullfile(outDir, 'runs', sprintf('BrestRun_D%d_kappa%g.mat', compareD, compareKappas(q)));
    if ~isfile(f)
        error('VisualizeBrestCompare:missingRun', ...
              'Missing %s - run Main.m with epsilon = %g, capacity = %d, then VisualizeBrestEvolution.', ...
              f, compareKappas(q), compareD);
    end
    S = load(f);
    runs(q) = S.brestRun; %#ok<SAGROW>
end

tag = sprintf('D%d_kappa%s', compareD, strjoin(compose('%g', compareKappas), '_vs_'));
PlotBrestOverlayCompare(geo, runs, ...
    'Gif', fullfile(outDir, ['BrestCompare_' tag '.gif']), ...
    'Mp4', fullfile(outDir, ['BrestCompare_' tag '.mp4']), ...
    'Filmstrip', fullfile(outDir, ['BrestCompareFilmstrip_' tag '.png']), ...
    'Title', 'BREST FIR Overload Evolution Comparison');
fprintf('BREST comparison written to %s (%s)\n', outDir, tag);
