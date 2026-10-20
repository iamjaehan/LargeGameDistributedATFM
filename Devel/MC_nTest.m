clear all
nCaseSet = [10, 30, 100,  300, 1000, 3000, 10000];
testName = "real_nTest_85_iter5";
iterNum = 5;

caseNum = length(nCaseSet);
for ii = 1:caseNum
    for jj = 1:iterNum
        n = nCaseSet(ii);

        epsilon = 0;
        algorithm = 1; % Ours fully noncooperative
        disp("Round Robin with "+num2str(n)+" players.")
        run("Main.m")

        epsilon = 1;
        algorithm = 1; % Ours fully cooperative
        disp("Ours with "+num2str(n)+" players.")
        run("Main.m")
    
        % GA centralized (algorithm 2) was removed; the MILP benchmark
        % (algorithm 5) is BREST-only for now, so this test has no centralized
        % baseline until it is extended to the European dataset.
    end
end
