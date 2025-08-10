% Load Ours
folderPath = '../Analysis/Ours_nTest_tight'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
oursLen = length(matFiles);
ours = cell(oursLen,1);
for k = 1:oursLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    ours{k} = data;
end

% Load Robin Hood
folderPath = '../Analysis/NonCoop_nTest_tight'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
nonCoopLen = length(matFiles);
nonCoop = cell(nonCoopLen,1);
for k = 1:nonCoopLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    nonCoop{k} = data;
end

% Load Centralized
folderPath = '../Analysis/Centralized_nTest_tight'; 
matFiles = dir(fullfile(folderPath, '*.mat'));
centLen = length(matFiles);
cent = cell(centLen,1);
for k = 1:centLen
    fileName = fullfile(folderPath, matFiles(k).name);
    data = load(fileName);
    cent{k} = data;
end

%% Preprocess
repeatNum = 1;
oursLegend = {"Round Robin (k = 0)", "Cooperative (k = 1.0)", "Centralized"};
nSet = [10, 30, 100, 300];
caseNum = length(nSet);

finalCostRaw = zeros(3,caseNum);
solveTimeRaw = zeros(3,caseNum);
solvePerTimeRaw = zeros(3,caseNum);
finalCost = zeros(3,caseNum,2);
solveTime = zeros(3,caseNum,2);
solvePerTime = zeros(3,caseNum,2);
for i = 1:caseNum
    for j = 1:repeatNum
        localIdx = j + (i-1) * repeatNum;
        finalCostRaw(1,i,j) = nonCoop{localIdx}.postAlgCost;
        finalCostRaw(2,i,j) = ours{localIdx}.postAlgCost;
        finalCostRaw(3,i,j) = cent{localIdx}.postAlgCost;
        solveTimeRaw(1,i,j) = sum(nonCoop{localIdx}.solveTime) * ours{localIdx}.roundCount;
        solveTimeRaw(2,i,j) = sum(ours{localIdx}.solveTime) * ours{localIdx}.roundCount;
        solveTimeRaw(3,i,j) = cent{localIdx}.solveTime;
        solvePerTimeRaw(1,i,j) = mean(nonCoop{localIdx}.solveTime) * ours{localIdx}.roundCount;
        solvePerTimeRaw(2,i,j) = mean(ours{localIdx}.solveTime) * ours{localIdx}.roundCount;
        solvePerTimeRaw(3,i,j) = cent{localIdx}.solveTime;
    end
end
finalCost(:,:,1) = mean(finalCostRaw,3);
finalCost(:,:,2) = std(finalCostRaw,0,3);
solveTime(:,:,1) = mean(solveTimeRaw,3);
solveTime(:,:,2) = std(solveTimeRaw,0,3);
solvePerTime(:,:,1) = mean(solvePerTimeRaw,3);
solvePerTime(:,:,2) = std(solvePerTimeRaw,0,3);

%% Plot
figure(1)
clf
errorbar(nSet, finalCost(1,:,1)+1, finalCost(1,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
hold on
errorbar(nSet, finalCost(2,:,1)+1, finalCost(2,:,2), '^--', 'MarkerSize', 10, 'LineWidth', 2.5)
errorbar(nSet, finalCost(3,:,1)+1, finalCost(3,:,2), 'd--', 'MarkerSize', 10, 'LineWidth', 2.5)
grid on
legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Overload Cost + 1")
title("Overload Cost vs Number of Aircraft")
set(gca, 'FontSize', 20)
set(gca, 'YScale', 'log', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [100, 100, 800, 700]);  % Set figure size in pixels
saveas(gcf,'../Analysis/acNumtoOverload_tight.png')

figure(2)
clf
errorbar(nSet, solveTime(1,:,1), solveTime(1,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
hold on
errorbar(nSet, solveTime(2,:,1), solveTime(2,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
errorbar(nSet, solveTime(3,:,1), solveTime(3,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
grid on
legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Computation Time [s]")
title("Total Computation Time vs Number of Aircraft")
set(gca, 'FontSize', 20)
set(gca, 'YScale', 'log', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [200, 200, 800, 700]);  % Set figure size in pixels
saveas(gcf,'../Analysis/acNumtoTotalTime_tight.png')

figure(3)
clf
errorbar(nSet, solvePerTime(1,:,1), solvePerTime(1,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
hold on
errorbar(nSet, solvePerTime(2,:,1), solvePerTime(2,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
errorbar(nSet, solvePerTime(3,:,1), solvePerTime(3,:,2), 'o--', 'MarkerSize', 10, 'LineWidth', 2.5)
grid on
legend(oursLegend,'Location','Northwest')
xlabel("Number of Aircraft")
ylabel("Computation Time [s]")
title("Average Computation Time per Player vs Number of Aircraft")
set(gca, 'FontSize', 20)
set(gca, 'YScale', 'log', 'XScale', 'log', 'GridAlpha', 0.3, 'MinorGridAlpha', 0.4)
set(gcf, 'Position', [200, 200, 800, 700]);  % Set figure size in pixels
saveas(gcf,'../Analysis/acNumtoAvgTime_tight.png')