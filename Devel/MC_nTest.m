clear all
nCaseSet = [10, 30, 100,  300, 1000, 3000, 10000];
testName = "real_nTest_95";
iterNum = 1;

origT = tic;
caseNum = length(nCaseSet);
for i = 1:caseNum
    for j = 1:iterNum
        n = nCaseSet(i);

        epsilon = 0;
        algorithm = 1; % Ours fully noncooperative
        disp("Round Robin with "+num2str(n)+" players.")
        run("Main.m")

        epsilon = 1;
        algorithm = 1; % Ours fully cooperative
        disp("Ours with "+num2str(n)+" players.")
        run("Main.m")
    
        algorithm = 2; % Centralized solution
        disp("Centralized with "+num2str(n)+" players.")
        run("Main.m")

        algorithm = 3; % FCFS solution
        disp("FCFS with "+num2str(n)+" players.")
        run("Main.m")
    end
end
toc(origT)