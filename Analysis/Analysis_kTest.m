% Load Ours
folderPath = 'Ours_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = 40;
ours = cell(oursLen,1);
for k = 1:oursLen
    fileName = fullfile(folderPath, matFiles(k+40).name);
    data = load(fileName);
    ours{k} = data;
end

% Load Centralized
folderPath = 'Centralized_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
centLen = 10;
cent = cell(centLen,1);
for k = 1:centLen
    fileName = fullfile(folderPath, matFiles(k+10).name);
    data = load(fileName);
    cent{k} = data;
end

% Load FCFS
folderPath = 'FCFS_real_kTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
fcfsLen = 1;
fcfs = cell(fcfsLen,1);
for k = 1:fcfsLen
    fileName = fullfile(folderPath, matFiles(k+1).name);
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
        compTime(j,i) = sum(ours{j + (i-1)*iterNum}.solveTime);
        avgCompTime(j,i) = mean(ours{j + (i-1)*iterNum}.solveTime);
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

finalCostStd = std(finalCost);
compTimeStd = std(compTime);
avgCompTimeStd = std(avgCompTime);
finalCostAvg = mean(finalCost);
compTimeAvg = mean(compTime);
avgCompTimeAvg = mean(avgCompTime);

%% Plot
set(groot, 'defaultTextInterpreter','none');  
set(groot, 'defaultAxesTickLabelInterpreter','latex');  
set(groot, 'defaultLegendInterpreter','latex');
colors = lines(6);
% oursLegend = {"Self-Interested (k = 0)", "Self priority (k=1e-6)", "k = 0.5", "Cooperative (k = 1.0)"};
oursLegend = {'$k = 0$', '$k=10^{-6}$', '$k = 0.5$', '$k = 1.0$', 'Centralized', 'FCFS'};
oursLegend{end+1} = 'Centralized';
oursLegend{end+1} = 'FCFS';
fontsize = 23;

figure(1)
clf
boxplot(finalCost+1)
grid on
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman', 'TickLabelInterpreter','latex');
% set(gca,'YScale','log')
xticks(1:6)
xticklabels(oursLegend)
xtickangle(0)
title("Final  Overload Cost Comparison")
ylabel("Overload Cost [Aircraft · min]")
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
% saveas(gcf, '../Analysis/FinalCostComparison.eps')
exportgraphics(gca,'../Analysis/FinalCostComparison.eps', 'Resolution',300);

figure(2)
clf
boxplot(compTime)
% boxplot(avgCompTime)
grid on
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
xticks(1:6)
xticklabels(oursLegend)
xtickangle(0)
title("Total Computation Time Comparison")
ylabel("Computation Time [s]")
set(gcf, 'Position', [900, 100, 800, 700]);  % Set figure size in pixels
% saveas(gcf, '../Analysis/TimeComparison.eps')
exportgraphics(gca,'../Analysis/TimeComparison.eps', 'Resolution',300);

%%
figure(3)
clf
plot(compTimeAvg, finalCostAvg,'ko','MarkerSize',10,'LineWidth',2)
for i = 1:length(finalCostAvg)
    text(compTimeAvg(i)+10,finalCostAvg(i)+6,oursLegend{i},'FontSize',fontsize,'Interpreter','latex')
end
% x-axis error
for i = 1:length(compTimeAvg)
    line([compTimeAvg(i)-compTimeStd(i), compTimeAvg(i)+compTimeStd(i)], [finalCostAvg(i), finalCostAvg(i)], 'Color', 'k');
end
% y-axis error
for i = 1:length(compTimeAvg)
    line([compTimeAvg(i), compTimeAvg(i)], [finalCostAvg(i)-finalCostStd(i), finalCostAvg(i)+finalCostStd(i)], 'Color', 'k');
end
title("Pareto Front")
xlabel("Computation Time [s]")
ylabel("Final Overload Cost [Aircraft · minutes]")
grid on
set(gcf, 'Position', [300, 100, 800, 700]);  % Set figure size in pixels
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
saveas(gcf, '../Analysis/ParetoFront.eps')

figure(4)
clf
plot(compTimeAvg, finalCostAvg,'ko','MarkerSize',10,'LineWidth',2)
for i = 1:length(finalCostAvg)
    text(compTimeAvg(i)+10,finalCostAvg(i)+1,oursLegend{i},'FontSize',fontsize,'Interpreter','latex')
end
% x-axis error
for i = 1:length(compTimeAvg)
    line([compTimeAvg(i)-compTimeStd(i), compTimeAvg(i)+compTimeStd(i)], [finalCostAvg(i), finalCostAvg(i)], 'Color', 'k');
end
% y-axis error
for i = 1:length(compTimeAvg)
    line([compTimeAvg(i), compTimeAvg(i)], [finalCostAvg(i)-finalCostStd(i), finalCostAvg(i)+finalCostStd(i)], 'Color', 'k');
end
title("Pareto Front")
xlabel("Computation Time [s]")
ylabel("Final Overload Cost [Aircraft · min]")
xlim([400 900])
ylim([-1 7])
grid on
set(gcf, 'Position', [300, 100, 800, 700]);  % Set figure size in pixels
set(gca, 'FontSize', fontsize, 'FontName', 'Times New Roman','TickLabelInterpreter','latex');
saveas(gcf, '../Analysis/ParetoFront_enlarged.eps')