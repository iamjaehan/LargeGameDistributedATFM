clear all
iterNum = 10;
testName = "real_kTest";
capacity = 7;

for i = 1:iterNum
    epsilon = 0;
    algorithm = 1; % Ours fully cooperative
    disp("*** Ours with "+num2str(epsilon)+" k value. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end

for i = 1:iterNum
    epsilon = 1e-6;
    algorithm = 1; % Ours fully noncooperative
    disp("*** Ours with "+num2str(epsilon)+" k value. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end

for i = 1:iterNum
    epsilon = 0.5;
    algorithm = 1; % Ours fully noncooperative
    disp("*** Ours with "+num2str(epsilon)+" k value. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end

for i = 1:iterNum
    epsilon = 1;
    algorithm = 1; % Ours fully noncooperative
    disp("*** Ours with "+num2str(epsilon)+" k value. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end

for i = 1:iterNum
    algorithm = 2; % Centralized solution
    disp("*** Centralized. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end

for i = 1
    algorithm = 3; % FCFS solution
    disp("*** FCFS. Iteration: "+num2str(i)+" ***")
    run("Main.m")
end
