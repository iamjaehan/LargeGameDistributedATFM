clear all
nCaseSet = [10, 30, 100,  300, 1000, 3000, 10000];
testName = "real_nTest_90_iter10";
iterNum = 1;

caseNum = length(nCaseSet);
for ii = 1:caseNum
    for j = 1:iterNum
        n = nCaseSet(ii);

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
    end
end
