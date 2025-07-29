function [] = PlotOccupancy(occupancyMatrix, simTime, sector_ids, m, capacity, figNum)

% Plot initial occupancy
hmSimTime = seconds(simTime);
hmSimTime.Format = 'hh:mm';
figure(figNum); clf; hold on;
for i = 1:m
    plot(hmSimTime,occupancyMatrix(i,:));
end
plot([seconds(0), seconds(3600*24-1)], [capacity, capacity],'r--','HandleVisibility','off')
labels = arrayfun(@num2str, sector_ids, 'UniformOutput', false);
legend(labels)
grid on
xlim([duration(0,0,0), duration(24,0,0)]);
drawnow;

end