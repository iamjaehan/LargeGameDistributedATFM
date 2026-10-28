function ExportPaperFigures(outDir)
% Write the paper figures as PDFs: six single panels, the scaling panel and
% the full-page one-day qualitative figure.
%
%   ExportPaperFigures                       % into ../Analysis/revised figure
%
% The three two-panel figures are split so each panel is its own file; the
% scaling figure is already one panel and is copied across unchanged.
%
%   CostComparison_D7    TimeComparison_D7     <- BrestDays_D7
%   CostComparison_D10   TimeComparison_D10    <- BrestDays_D10
%   DelayCompare         GiniCompare           <- BrestDelayFairnessCompare_D7
%   EuropeScalingTime
%   Qualitative_D10      <- PlotBrestQualitative (one day, 230730, full page)
%   TDP_Europe  TDP_BREST   <- PlotTrafficDemand (BREST: 230730)

if nargin < 1 || isempty(outDir), outDir = fullfile('..','Analysis','revised figure'); end
if ~isfolder(outDir), mkdir(outDir); end

PlotBrestDays('exp_brest_days_D7.mat',  outDir, {'CostComparison_D7',  'TimeComparison_D7'});
close all
PlotBrestDays('exp_brest_days_D10.mat', outDir, {'CostComparison_D10', 'TimeComparison_D10'});
close all
PlotBrestDelayFairnessCompare('exp_brest_days_D7.mat', 'exp_brest_days_D7_tiebreak.mat', ...
                              '', outDir, {'DelayCompare', 'GiniCompare'});
close all
PlotEuropeScalingTime();                       % one panel already; writes next to the data
close all
copyfile('EuropeScalingTime.pdf', fullfile(outDir, 'EuropeScalingTime.pdf'));
fprintf('wrote %s\n', fullfile(outDir, 'EuropeScalingTime.pdf'));
PlotBrestQualitative('230730', 'exp_brest_days_D10.mat', [], fullfile(outDir, 'Qualitative_D10.pdf'));
close all
PlotTrafficDemand('europe', '', fullfile(outDir, 'TDP_Europe.pdf'));
close all
PlotTrafficDemand('brest', '230730', fullfile(outDir, 'TDP_BREST.pdf'));   % the qualitative day
close all

d = dir(fullfile(outDir, '*.pdf'));
fprintf('\n%s contains %d PDFs:\n', outDir, numel(d));
for k = 1:numel(d), fprintf('  %-26s %6.0f KB\n', d(k).name, d(k).bytes/1024); end
end
