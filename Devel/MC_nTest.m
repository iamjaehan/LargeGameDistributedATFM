clear all
nCaseSet = [10, 300, 1000, 3000, 10000];

caseNum = length(nCaseSet);
for i = 1:caseNum
    n = nCaseSet(i);
    epsilon = 1;
    algorithm = 1;
    run("Main.m")

    epsilon = 0;
    algorithm = 1;
    run("Main.m")

    algorithm = 2;
    run("Main.m")
end