% RunEuropeScaling -- scalability study on the European dataset.
%
% For each n, Main.m runs on the same n-flight sample (rng(10) inside Main),
% capacity = 85% of that sample's peak occupancy, for ours (kappa = 0, 1)
% and the centralized MILP (stage 1, EXP_MILPTIME limit; the gap is kept when
% the limit is hit).  Everything is deterministic, so one run per n.
%
%   >> RunEuropeScaling          % writes exp_europe_scaling.mat after every n
%
% Time measures for ours, from Main's brTimeLog (one row per best response):
%   brTotal    sum of all best-response solve times
%   brParallel sum over rounds of the slowest sector in that round -- the time
%              if sectors solve their best responses concurrently
%   wall       Main's elapsed time for the whole dynamics
% Main.m is run through a generated body (ExpBodyEurope_tmp.m, git-ignored),
% so driver variables are EXP_* only.

EXP_NS      = [10 30 100 300 1000 3000 10000];
EXP_KAPPAS  = [0 1];
EXP_MILPTIME = 3600;                          % s per n for the centralized MILP
EXP_OUT     = 'exp_europe_scaling.mat';
EXP_LABELS  = [arrayfun(@(k) sprintf('\\kappa = %g', k), EXP_KAPPAS, 'UniformOutput', false), {'Centralized MILP'}];
EXP_NM = numel(EXP_LABELS); EXP_NN = numel(EXP_NS);

% ---- body: Main.m with the configuration replaced (each anchor must match once)
EXP_SRC = fileread('Main.m');
EXP_SUBS = {
    'dataset = ''brest'';'                     , 'dataset = ''europe'';'
    'dataDay = ''230726'';'                    , 'dataDay = '''';'
    'n = flightn; '                            , 'n = EXP_N; '
    'epsilon = 1;'                             , 'epsilon = EXP_EPS;'
    'algorithm = 1; %'                         , 'algorithm = EXP_ALG; %'
    'capacity = round(maxOccupancy * 0.75);'   , 'capacity = round(maxOccupancy * 0.85);'
    'milpMaxTime = 3600;'                      , 'milpMaxTime = EXP_MILPTIME;'
    'recordHistory = true;'                    , 'recordHistory = false;'
    '%% Search Equilibrium (Ours)'             , ['tExpStart = tic;' newline '%% Search Equilibrium (Ours)']
    '%% Save result'                           , ['expElapsed = toc(tExpStart);' newline '%% Save result']
};
for EXP_K = 1:size(EXP_SUBS,1)
    if numel(strfind(EXP_SRC, EXP_SUBS{EXP_K,1})) ~= 1
        error('RunEuropeScaling:anchor', 'Main.m anchor "%s" not found exactly once.', EXP_SUBS{EXP_K,1});
    end
    EXP_SRC = strrep(EXP_SRC, EXP_SUBS{EXP_K,1}, EXP_SUBS{EXP_K,2});
end
EXP_FID = fopen('ExpBodyEurope_tmp.m', 'w'); fwrite(EXP_FID, EXP_SRC); fclose(EXP_FID);

R = struct('ns', EXP_NS, 'kappas', EXP_KAPPAS, 'labels', {EXP_LABELS}, 'capacityRule', '85% of peak occupancy', ...
    'milpTimeLimit', EXP_MILPTIME, 'units', 'overload in aircraft-s, times in s', ...
    'overload', nan(EXP_NN, EXP_NM), 'initialOverload', nan(EXP_NN,1), 'capacity', nan(EXP_NN,1), ...
    'nAgents', nan(EXP_NN,1), 'wall', nan(EXP_NN, EXP_NM), 'brTotal', nan(EXP_NN, EXP_NM), ...
    'brParallel', nan(EXP_NN, EXP_NM), 'rounds', nan(EXP_NN, EXP_NM), 'inexactBR', nan(EXP_NN, EXP_NM), ...
    'milpTime', nan(EXP_NN,1), 'milpLowerBound', nan(EXP_NN,1), 'milpExitflag', nan(EXP_NN,1), ...
    'milpRelGap', nan(EXP_NN,1), 'brTimeLog', {cell(EXP_NN, EXP_NM)});

EXP_KEEP = {'EXP_NS','EXP_KAPPAS','EXP_MILPTIME','EXP_OUT','EXP_LABELS','EXP_NM','EXP_NN', ...
            'R','EXP_KEEP','EXP_NI','EXP_MI','EXP_N','EXP_EPS','EXP_ALG','EXP_T0'};
EXP_T0 = tic;
for EXP_NI = 1:EXP_NN
    for EXP_MI = 1:EXP_NM
        EXP_N = EXP_NS(EXP_NI);
        if EXP_MI <= numel(EXP_KAPPAS), EXP_ALG = 1; EXP_EPS = EXP_KAPPAS(EXP_MI);
        else, EXP_ALG = 5; EXP_EPS = 1; end
        try
            evalc('run(''ExpBodyEurope_tmp.m'')');
            R.overload(EXP_NI, EXP_MI) = postAlgCost;
            R.initialOverload(EXP_NI) = initialOverloadCost;
            R.capacity(EXP_NI) = capacity; R.nAgents(EXP_NI) = m;
            R.wall(EXP_NI, EXP_MI) = expElapsed;
            if EXP_ALG == 1
                R.brTimeLog{EXP_NI, EXP_MI} = brTimeLog;
                R.brTotal(EXP_NI, EXP_MI) = sum(brTimeLog(:,3));
                R.brParallel(EXP_NI, EXP_MI) = sum(accumarray(brTimeLog(:,1), brTimeLog(:,3), [], @max));
                R.rounds(EXP_NI, EXP_MI) = roundCount; R.inexactBR(EXP_NI, EXP_MI) = nInexactBR;
            else
                R.milpTime(EXP_NI) = milpInfo.buildTime + milpInfo.solveTime;
                R.milpLowerBound(EXP_NI) = milpInfo.overloadLowerBound;
                R.milpExitflag(EXP_NI) = milpInfo.exitflag; R.milpRelGap(EXP_NI) = milpInfo.relativeGap;
            end
        catch EXP_ERR
            fprintf('!! n = %d method %d FAILED: %s\n', EXP_N, EXP_MI, EXP_ERR.message);
        end
        fprintf('n = %5d  %-18s overload %9.0f / %9.0f  wall %8.1f s\n', EXP_N, EXP_LABELS{EXP_MI}, ...
                R.overload(EXP_NI, EXP_MI), R.initialOverload(EXP_NI), R.wall(EXP_NI, EXP_MI));
        clearvars('-except', EXP_KEEP{:});
    end
    save(EXP_OUT, '-struct', 'R');
    fprintf('== n = %d done (%.1f min elapsed)\n', EXP_NS(EXP_NI), toc(EXP_T0)/60);
end
fprintf('wrote %s\n', EXP_OUT);
