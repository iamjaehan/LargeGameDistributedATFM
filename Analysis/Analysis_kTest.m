% Load Ours
folderPath = 'Ours_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = 40;
ours = cell(oursLen,1);
for k = 1:oursLen
    % fileName = fullfile(folderPath, matFiles(k+40).name);
    fileName = fullfile(folderPath, matFiles(k+80).name);
    % fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    ours{k} = data;
end

% Load Centralized
folderPath = 'Centralized_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
centLen = 10;
cent = cell(centLen,1);
for k = 1:centLen
    % fileName = fullfile(folderPath, matFiles(k+10).name);
    fileName = fullfile(folderPath, matFiles(k+20).name);
    % fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    cent{k} = data;
end

% Load FCFS
folderPath = 'FCFS_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
fcfsLen = 1;
fcfs = cell(fcfsLen,1);
for k = 1:fcfsLen
    % fileName = fullfile(folderPath, matFiles(k+1).name);
    fileName = fullfile(folderPath, matFiles(k+2).name);
    % fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    fcfs{k} = data;
end

%% Analysis
iterNum = 10;
epsilonSet = [0 1e-6 0.5 1];

finalCost = zeros(iterNum,6);
compTime = zeros(iterNum,6);
avgCompTime = zeros(iterNum,6);
for i = 1:length(epsilonSet)
    for j = 1:iterNum
        finalCost(j,i) = ours{j + (i-1)*iterNum}.postAlgCost;
        convergeList = find(finalCost(j,i) == ours{j + (i-1)*iterNum}.costHistory);
        adjustVal = convergeList(1)/convergeList(end);
        compTime(j,i) = sum(ours{j + (i-1)*iterNum}.solveTime) * ours{j + (i-1)*iterNum}.roundCount * adjustVal;
        avgCompTime(j,i) = mean(ours{j + (i-1)*iterNum}.solveTime) * ours{j + (i-1)*iterNum}.roundCount * adjustVal;
    end
end

for j = 1:iterNum
    finalCost(j,5) = cent{j}.postAlgCost;
    finalCost(j,6) = fcfs{1}.postAlgCost;
    compTime(j,5) = cent{j}.solveTime;
    compTime(j,6) = fcfs{1}.solveTime;
    avgCompTime(j,5) = cent{j}.solveTime;
    avgCompTime(j,6) = fcfs{1}.solveTime;
end

finalCost = finalCost/60;
compTime = compTime ./ median(compTime(:,5));
avgCompTime = avgCompTime ./ median(avgCompTime(:,5));

finalCostStd = std(finalCost);
compTimeStd = std(compTime);
avgCompTimeStd = std(avgCompTime);
finalCostAvg = mean(finalCost);
compTimeAvg = mean(compTime);
avgCompTimeAvg = mean(avgCompTime);

np = length(ours{1}.solveTime);
initialCost = ours{40}.costHistory(1)/60;

%% Plot
set(groot, 'defaultTextInterpreter','none');  
set(groot, 'defaultAxesTickLabelInterpreter','latex');  
set(groot, 'defaultLegendInterpreter','latex');
colors = lines(6);
oursLegend = {'$\kappa = 0$', '$\kappa=10^{-6}$', '$\kappa = 0.5$', '$\kappa = 1.0$', 'Centralized', 'FCFS'};
oursLegend{end+1} = 'Centralized';
oursLegend{end+1} = 'FCFS';
fontsize = 23;

figure(1)
clf
xlim manual
boxplot(finalCost)
hold on
yline(initialCost, '-.r', '  Initial Overload', ...
    'LineWidth', 2, ...
    'Interpreter', 'latex', ...
    'FontSize', fontsize,...
    'LabelHorizontalAlignment', 'center', ...
    'LabelVerticalAlignment', 'top');
grid on
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman', 'TickLabelInterpreter','latex');
% set(gca,'YScale','log')
xticks(1:6)
xticklabels(oursLegend)
xtickangle(0)
title("Final  Overload Cost Comparison")
ylabel("Overload Cost [Aircraft - min]")
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
set(gca,'LineWidth',1.5)
h = findobj(gca,'Tag','Box');
set(h,'LineWidth',1.5)
yl = ylim;
ylim([yl(1), yl(2) * 1.07])   % 위로 5% 늘리기
exportgraphics(gca,'../Analysis/FinalCostComparison_2.eps', 'Resolution',300);
% exportgraphics(gca,'../Analysis/FinalCostComparison.eps', 'Resolution',300);

figure(2)
clf
boxplot(compTime)
hold on
boxplot(avgCompTime(:,1:4),'Positions',1:4,'Colors','k')
h = findobj(gca,'Tag','Box');
h2 = findobj(gca,'Tag','Median');
set(h, 'LineWidth', 1.5)
set(h(1:4), 'LineStyle', '-.')
set(h2(1:4),'Color','r')
grid on
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
set(gca,'YScale','log','LineWidth',1.5)
xticks(1:6)
xticklabels(oursLegend)
xtickangle(0)
title("Normalized Computation Time Comparison")
ylabel("Normalized Computation Time [-]")
set(gcf, 'Position', [900, 100, 800, 700]);  % Set figure size in pixels
exportgraphics(gca,'../Analysis/TimeComparison_2.eps', 'Resolution',300);
% exportgraphics(gca,'../Analysis/TimeComparison.eps', 'Resolution',300);

%%
% % compTimeAvg = avgCompTimeAvg;
% figure(3)
% clf
% plot(compTimeAvg, finalCostAvg,'ko','MarkerSize',10,'LineWidth',2)
% for i = 1:length(finalCostAvg)
%     text(compTimeAvg(i)+10,finalCostAvg(i)+6,oursLegend{i},'FontSize',fontsize,'Interpreter','latex')
% end
% % x-axis error
% for i = 1:length(compTimeAvg)
%     line([compTimeAvg(i)-compTimeStd(i), compTimeAvg(i)+compTimeStd(i)], [finalCostAvg(i), finalCostAvg(i)], 'Color', 'k');
% end
% % y-axis error
% for i = 1:length(compTimeAvg)
%     line([compTimeAvg(i), compTimeAvg(i)], [finalCostAvg(i)-finalCostStd(i), finalCostAvg(i)+finalCostStd(i)], 'Color', 'k');
% end
% title("Pareto Front")
% xlabel("Computation Time [s]")
% ylabel("Final Overload Cost [Aircraft - min]")
% grid on
% set(gcf, 'Position', [300, 100, 800, 700]);  % Set figure size in pixels
% set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
% set(gca,'XScale','log')
% 
% set(gca,'LineWidth',1.5)
% exportgraphics(gca,'../Analysis/ParetoFront_2.eps', 'Resolution',300);
% % exportgraphics(gca,'../Analysis/ParetoFront.eps', 'Resolution',300);
% 
% figure(4)
% clf
% plot(compTimeAvg, finalCostAvg,'ko','MarkerSize',10,'LineWidth',2)
% for i = 1:length(finalCostAvg)
%     text(compTimeAvg(i)+10,finalCostAvg(i)+1,oursLegend{i},'FontSize',fontsize,'Interpreter','latex')
% end
% % x-axis error
% for i = 1:length(compTimeAvg)
%     line([compTimeAvg(i)-compTimeStd(i), compTimeAvg(i)+compTimeStd(i)], [finalCostAvg(i), finalCostAvg(i)], 'Color', 'k');
% end
% % y-axis error
% for i = 1:length(compTimeAvg)
%     line([compTimeAvg(i), compTimeAvg(i)], [finalCostAvg(i)-finalCostStd(i), finalCostAvg(i)+finalCostStd(i)], 'Color', 'k');
% end
% % title("Pareto Front")
% xlabel("Computation Time [s]")
% ylabel("Final Overload Cost [Aircraft - min]")
% xlim([400 900])
% ylim([-1 7])
% % xlim([700 1000])
% % ylim([-1 25])
% grid on
% set(gcf, 'Position', [300, 100, 800, 700]);  % Set figure size in pixels
% set(gca,'XScale','log')
% set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
% 
% exportgraphics(gca,'../Analysis/ParetoFront_enlarged_2.eps', 'Resolution',300)
% % exportgraphics(gca,'../Analysis/ParetoFront_enlarged.eps', 'Resolution',300);

%%
