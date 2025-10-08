% Load Ours
% folderPath = '../Analysis/Ours_real_nTest'; 
folderPath = '../Analysis/Ours_real_nTest_90_iter10'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = length(matFiles);
ours = cell(oursLen,1);
for k = 1:oursLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    ours{k} = data;
end

% Load Centralized
% folderPath = '../Analysis/Centralized_real_nTest'; 
folderPath = '../Analysis/Centralized_real_nTest_90_iter10'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
centLen = length(matFiles);
cent = cell(centLen,1);
for k = 1:centLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    cent{k} = data;
end

% Load FCFS
folderPath = '../Analysis/FCFS_real_nTest'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
fcfsLen = length(matFiles);
fcfs = cell(fcfsLen,1);
for k = 1:fcfsLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    fcfs{k} = data;
end

%% Preprocess
repeatNum = 1;
oursLegend = {"$\kappa = 0$", "$\kappa = 1.0$", "Centralized"};
oursMarker = {"o","^","*"};
nSet = [10, 30, 100, 300, 1000, 3000, 10000];
caseNum = length(nSet);
colors = lines(6);

% 1- k=0, 2-k=1, 3-cent
finalCost = zeros(3, caseNum);
totTime = zeros(3, caseNum);
avgTime = zeros(3, caseNum);

for i = 1:caseNum
    finalCost(1,i) = ours{2*i - 1}.postAlgCost;
    finalCost(2,i) = ours{2*i}.postAlgCost;
    finalCost(3,i) = cent{i}.postAlgCost;

    convergeList = find(finalCost(1,i) == ours{2*i - 1}.costHistory);
    adjustVal = convergeList(1)/convergeList(end);
    
    totTime(1,i) = sum(ours{2*i - 1}.solveTime) * ours{2*i - 1}.roundCount * adjustVal;
    totTime(2,i) = sum(ours{2*i}.solveTime) * ours{2*i}.roundCount  * adjustVal;
    totTime(3,i) = sum(cent{i}.solveTime);

    avgTime(1,i) = mean(ours{2*i - 1}.solveTime) * ours{2*i - 1}.roundCount  * adjustVal;
    avgTime(2,i) = mean(ours{2*i}.solveTime) * ours{2*i}.roundCount  * adjustVal;
    avgTime(3,i) = mean(cent{i}.solveTime);
end
finalCost = finalCost / 60;
%% Plot
set(groot, 'defaultTextInterpreter','none');  
set(groot, 'defaultAxesTickLabelInterpreter','latex');  
set(groot, 'defaultLegendInterpreter','latex');

figure(1)
clf
plot(nSet, finalCost(1,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
hold on
plot(nSet, finalCost(2,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
plot(nSet, finalCost(3,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
grid on
legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Overload Cost + 1")
title("Overload Cost vs Number of Aircraft")
set(gca, 'FontSize', 20)
set(gca, 'YScale', 'linear', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
saveas(gcf,'../Analysis/acNumtoOverload_tight.png')
exportgraphics(gca,'../Analysis/nTest_overload.eps','Resolution',300)

figure(3)
clf
plot(nSet, avgTime(1,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
hold on
plot(nSet, avgTime(2,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
plot(nSet, avgTime(3,:), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
grid on
legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Computation Time [s]")
title("Average Computation Time per Player vs Number of Aircraft")
set(gca, 'FontSize', 20)
set(gca, 'YScale', 'log', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [200, 200, 800, 700]);  % Set figure size in pixels
% saveas(gcf,'../Analysis/acNumtoAvgTime_tight.png')
exportgraphics(gca,'../Analysis/nTest_avgTime.eps','Resolution',300)

%%
figure(2)
clf
plot(nSet, totTime(1,:), 'Marker', oursMarker{1}, 'MarkerSize', 15, 'LineWidth', 2,'Color',colors(1,:))
hold on
grid on
plot(nSet, totTime(2,:), 'Marker', oursMarker{2}, 'MarkerSize', 15, 'LineWidth', 2,'Color',colors(2,:))
plot(nSet, totTime(3,:), 'Marker', oursMarker{3}, 'MarkerSize', 15, 'LineWidth', 2,'Color',colors(3,:))
plot(nSet, avgTime(1,:), 'Marker', oursMarker{1}, 'MarkerSize', 15, 'LineWidth', 2,'Color',colors(1,:),'LineStyle','--')
plot(nSet, avgTime(2,:), 'Marker', oursMarker{2}, 'MarkerSize', 15, 'LineWidth', 2,'Color',colors(2,:),'LineStyle','--')

legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Computation Time [s]")
title("Scalability Result")
set(gca, 'FontSize', 23)
set(gca, 'YScale', 'log', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [200, 200, 800, 700]);  % Set figure size in pixels
set(gca,'FontName','Times New Roman')
% saveas(gcf,'../Analysis/acNumtoTotalTime_tight.png')
exportgraphics(gca,'../Analysis/nTest_totTime.eps','Resolution',300)