clear all;
initCost = 173953;
% initCost = 61503;

% Load Ours
folderPath = '../Analysis/Ours'; 
% folderPath = '../Analysis/Ours_tight'; 
folderPath = '../Analysis/Ours_distributed'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = length(matFiles);
ours = cell(oursLen,1);
for k = 1:oursLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    ours{k} = data;
end

% oursLegend = {"Round Robin (k = 0)", "Self priority (k=1e-9)", "k = 0.2", "k = 0.5", "Cooperative (k = 1.0)"};
oursLegend = {"Round Robin (k = 0)", "Self priority (k=1e-9)", "k = 1e-6", "k = 0.2", "k = 0.5", "Cooperative (k = 1.0)"};
MarkerList = ["^", "d", "*", "o","x","v"];
ColorList = lines(oursLen);

% Load Centralized
folderPath = '../Analysis/Centralized'; 
folderPath = '../Analysis/Centralized_distributed'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
cent = cell(length(matFiles),1);
for k = 1:length(matFiles)
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    cent{k} = data;
end

% Load FCFS
folderPath = '../Analysis/FCFS'; 
folderPath = '../Analysis/FCFS_distributed'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
fcfs = cell(length(matFiles),1);
for k = 1:length(matFiles)
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    fcfs{k} = data;
end

% Preprocessing 
for i = 1:oursLen
    temp = ours{i}.costHistory;
    tempLen = length(temp);
    for j = 1:tempLen-1
        if temp(j+1) > temp(j)
            temp(j+1) = temp(j);
        end
    end
    ours{i}.costHistory = temp;
end

% Cost Evolution History
ours{end}.costHistory = ours{end}.potentialHistory;
figure(1)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
clf
for i = 1:oursLen
    x = 0:1/ours{i}.m:ours{i}.roundCount;
    plot(x,[initCost,ours{i}.costHistory'],'Marker', MarkerList(i), 'Color', ColorList(i,:),'MarkerSize',10,'LineWidth',2)
    hold on
end
grid on
xlabel("Rounds")
ylabel("Overload Cost")
title("Overload Cost Evolution")
legend(oursLegend,'Location','best')
set(gca, 'FontSize', 20);
saveas(gcf, '../Analysis/CostEvolution.png')

% xlim([1 inf])
% set(gcf, 'Position', [100, 100, 800, 800]);  % Set figure size in pixels
% ylim([0 200])
% saveas(gcf, '../Analysis/CostEvolution_Enlarged.png')

% Potential Cost Evolution History
figure(2)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
clf
for i = 1:oursLen
    x = 0:1/ours{i}.m:ours{i}.roundCount;
    plot(x,[ours{i}.potentialHistory(1),ours{i}.potentialHistory'],'Marker', MarkerList(i), 'Color', ColorList(i,:),'MarkerSize',10,'LineWidth',2)
    hold on
end
grid on
xlabel("Rounds")
ylabel("Potential Cost")
title("Potential Cost Evolution")
legend(oursLegend,'Location','best')
set(gca, 'FontSize', 20);
saveas(gcf, '../Analysis/PotentialEvolution.png')

% Final Cost Comparison
finalCost = [];
for i = 1:oursLen
    finalCost = vertcat(finalCost,ours{i}.postAlgCost);
end
finalCost = vertcat(finalCost,cent{1}.postAlgCost);
finalCost = vertcat(finalCost,fcfs{1}.postAlgCost);
figure(3)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
clf
bar(log10(finalCost));
grid on
xticks(1:8)
localLegend = oursLegend;
localLegend{end+1} = "Centralized";
localLegend{end+1} = "FCFS";
xticklabels(localLegend)
ylabel("Final Overload Cost [log scale]")
set(gca, 'FontSize', 20);
title("Final Cost Comparison")
saveas(gcf, '../Analysis/FinalCostComparison.png')

% Computation Time Comparison
compTime = [];
for i = 1:oursLen
    localTime = mean(ours{i}.solveTime) * ours{i}.roundCount;
    compTime = vertcat(compTime, localTime);
end
compTime = vertcat(compTime, cent{1}.solveTime);
compTime = vertcat(compTime, fcfs{1}.solveTime);
figure(4)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
clf
bar(compTime);
grid on
xticks(1:8)
xticklabels(localLegend)
ylabel("Computation Time [s]")
set(gca, 'FontSize', 20);
title("Computation Time Comparison")
saveas(gcf, '../Analysis/TimeComparison.png')

% Pareto Front
figure(5)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
clf
for i = 1:length(finalCost)
    if finalCost(i)==0
        finalCost(i) = finalCost(i) + 1;
    end
end
semilogy(compTime,finalCost,'o','MarkerSize',10)
grid on
for i = 1:length(compTime)
    text(compTime(i)+3,finalCost(i),localLegend{i},'FontSize',20)
end
xlabel("Computation Time [s]")
ylabel("Final Overload Cost")
title("Solution Quality to Time Pareto Front")
set(gca, 'FontSize', 20);
saveas(gcf, '../Analysis/ParetoFront.png')

%% Plotting
% idx = 6;
% PlotOccupancy(ours{idx}.occupancyMatrix, ours{idx}.simTime, ours{idx}.sector_ids, ours{idx}.m, ours{idx}.capacity, 7)