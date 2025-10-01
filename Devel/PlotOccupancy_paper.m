function [] = PlotOccupancy_paper(occupancyMatrix, simTime, sector_ids, m, capacity, figNum)

set(groot, 'defaultTextInterpreter','none');  
set(groot, 'defaultAxesTickLabelInterpreter','latex');  
set(groot, 'defaultLegendInterpreter','latex');

% Plot initial occupancy
hmSimTime = seconds(simTime);
hmSimTime.Format = 'hh:mm';
figure(figNum); clf; hold on;
for i = 1:m
    plot(hmSimTime,occupancyMatrix(i,:), 'LineWidth',1);
end
plot([seconds(0), seconds(3600*24-1)], [capacity, capacity],'r--','HandleVisibility','off','LineWidth',2)
labels = arrayfun(@num2str, sector_ids, 'UniformOutput', false);
% legend(labels)
grid on
xlim([duration(0,0,0), duration(24,0,0)]);
drawnow;

xlabel('Time')
ylabel("Number of Aircraft")
% title("Traffic Demand Profile - κ = 1")

set(gcf, 'Position', [900, 100, 800, 700]);  % Set figure size in pixels
% set(gcf, 'Position', [900, 100, 1600, 500]);  % Set figure size in pixels
set(gca,'fontsize',23)
set(gca,'LineWidth',1.5)
set(gca,'FontName','Times New Roman')
ylim([0 16])

end