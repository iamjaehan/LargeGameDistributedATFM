% RunBrestDays -- the per-day BREST study behind exp_brest_days_D7.mat.
%
% One deterministic run per traffic day for every method, so the spread in
% the results is real instance variation rather than solver noise.  Nothing
% here is stochastic: the best responses are exact MILPs and both FCFS
% baselines are deterministic, which is why there is no Monte Carlo loop.
%
%   >> RunBrestDays            % writes exp_brest_days_D7.mat
%   >> PlotBrestDays('exp_brest_days_D7.mat')
%
% Parse the days first if parsed/brest_*.mat is missing:
%   >> ParseSectorHist('brest')
%
% Timing caveat: run this in ONE session.  The committed .mat was assembled
% incrementally (the full sweep, then the two FCFS columns re-measured after
% they were fixed), so its three method groups were timed under different
% machine load and panel (b) of the figure is indicative only.  A single
% uninterrupted run of this script is the way to get comparable times; the
% overload numbers are deterministic and come out identical either way.

EXP_CAP     = 7;                             % sector capacity D
EXP_KAPPAS  = [0, 1e-6, 0.5, 1];             % the paper's kappa set (1e-6 meets the refined Theorem 1 bound, docs/theorem1_refined_kappa_bound.md)
EXP_ALGS    = [3 4 5];                       % 3/4 = FCFS reactive/strategic, 5 = centralized MILP
EXP_MILPTIME = Inf;                          % no time limit: the MILP column is solved to proven optimality
EXP_OUT     = 'exp_brest_days_D7.mat';
EXP_MINFL   = 100;                           % skip truncated days (230712 has 37)

EXP_LABELS = [ arrayfun(@KappaLabel, EXP_KAPPAS, 'UniformOutput', false), ...
               {'FCFS (reactive)', 'FCFS (strategic)', 'Centralized MILP'} ];
EXP_NM = numel(EXP_LABELS);

MakeExpBody();

% ---- usable days -------------------------------------------------------
EXP_DIR = dir('parsed/brest_*.mat');
if isempty(EXP_DIR)
    error('RunBrestDays:noData', 'No parsed/brest_*.mat. Run ParseSectorHist(''brest'') first.');
end
EXP_DAYS = {};
for EXP_I = 1:numel(EXP_DIR)
    EXP_S = load(fullfile('parsed', EXP_DIR(EXP_I).name), 'meta');
    if EXP_S.meta.nFlights > EXP_MINFL, EXP_DAYS{end+1} = EXP_S.meta.date; end %#ok<SAGROW>
end
EXP_DAYS = sort(EXP_DAYS);
EXP_ND = numel(EXP_DAYS);
fprintf('RunBrestDays: %d days x %d methods, D = %d\n', EXP_ND, EXP_NM, EXP_CAP);

EXP_OVL  = nan(EXP_ND, EXP_NM);  EXP_TIME   = nan(EXP_ND, EXP_NM);
EXP_DEL  = nan(EXP_ND, EXP_NM);  EXP_ROUNDS = nan(EXP_ND, EXP_NM);
EXP_INEX = nan(EXP_ND, EXP_NM);  EXP_FORCED = nan(EXP_ND, EXP_NM);
EXP_MILPLB = nan(EXP_ND, 1);     EXP_MILPEXIT = nan(EXP_ND, 1);
EXP_INIT = nan(EXP_ND, 1);       EXP_NF     = nan(EXP_ND, 1);
EXP_NS   = nan(EXP_ND, 1);
% per-flight delay (action steps) of every method, and the sector controlling
% each flight, so delay and fairness metrics can be computed afterwards
EXP_DELAYVEC = cell(EXP_ND, EXP_NM);  EXP_CTRL = cell(EXP_ND, 1);

% run('ExpBody.m') shares this workspace and Main.m uses short variable
% names, so everything that must survive a run is listed here and restored
% with clearvars afterwards.
EXP_KEEP = {'EXP_CAP','EXP_KAPPAS','EXP_ALGS','EXP_OUT','EXP_MINFL','EXP_LABELS', ...
            'EXP_NM','EXP_DAYS','EXP_ND','EXP_OVL','EXP_TIME','EXP_DEL','EXP_ROUNDS', ...
            'EXP_INEX','EXP_FORCED','EXP_MILPLB','EXP_MILPEXIT','EXP_INIT','EXP_NF','EXP_NS','EXP_KEEP', ...
            'EXP_DELAYVEC','EXP_CTRL', ...
            'EXP_MILPTIME', ...
            'EXP_DI','EXP_MI','EXP_DAY','EXP_EPS','EXP_ALG','EXP_T0'};
EXP_T0 = tic;

for EXP_DI = 1:EXP_ND
    for EXP_MI = 1:EXP_NM
        EXP_DAY = EXP_DAYS{EXP_DI};
        if EXP_MI <= numel(EXP_KAPPAS)
            EXP_ALG = 1; EXP_EPS = EXP_KAPPAS(EXP_MI);
        else
            EXP_ALG = EXP_ALGS(EXP_MI - numel(EXP_KAPPAS)); EXP_EPS = 1;
        end
        try
            evalc('run(''ExpBody.m'')');            % silence the per-round log
            EXP_OVL(EXP_DI, EXP_MI)  = postAlgCost;
            EXP_TIME(EXP_DI, EXP_MI) = expElapsed;
            EXP_INIT(EXP_DI) = initialOverloadCost;
            EXP_NF(EXP_DI)   = n;
            EXP_NS(EXP_DI)   = m;
            EXP_CTRL{EXP_DI} = double(controlCenter(:));
            if EXP_ALG == 1
                EXP_DELAYVEC{EXP_DI, EXP_MI} = double(action(:));
            elseif EXP_ALG == 5
                EXP_DELAYVEC{EXP_DI, EXP_MI} = double(optAction(:));
            else
                EXP_DELAYVEC{EXP_DI, EXP_MI} = double(flightDelays(:));
            end
            if EXP_ALG == 1
                EXP_DEL(EXP_DI, EXP_MI)    = nnz(action);
                EXP_ROUNDS(EXP_DI, EXP_MI) = roundCount;
                EXP_INEX(EXP_DI, EXP_MI)   = nInexactBR;
            else
                if EXP_ALG ~= 5        % the MILP branch returns optAction, not flightDelays
                    EXP_DEL(EXP_DI, EXP_MI) = nnz(flightDelays);
                end
                if EXP_ALG == 4
                    EXP_FORCED(EXP_DI, EXP_MI) = fcfsInfo.nForced;
                elseif EXP_ALG == 5
                    EXP_DEL(EXP_DI, EXP_MI)  = milpInfo.nDelayed;
                    EXP_MILPLB(EXP_DI)       = milpInfo.overloadLowerBound;
                    EXP_MILPEXIT(EXP_DI)     = milpInfo.exitflag;
                end
            end
        catch EXP_ERR
            fprintf('!! day %s method %d FAILED: %s\n', EXP_DAY, EXP_MI, EXP_ERR.message);
        end
        clearvars('-except', EXP_KEEP{:});
    end
    fprintf('day %2d/%d  %s  (%.1f min elapsed)\n', EXP_DI, EXP_ND, EXP_DAYS{EXP_DI}, toc(EXP_T0)/60);
    SaveStudy(EXP_OUT, EXP_LABELS, EXP_OVL, EXP_TIME, EXP_DEL, EXP_ROUNDS, EXP_INEX, EXP_INIT, ...
              EXP_DAYS, EXP_KAPPAS, EXP_CAP, EXP_NF, EXP_NS, EXP_FORCED(:, numel(EXP_KAPPAS)+2), ...
              EXP_MILPLB, EXP_MILPEXIT, EXP_MILPTIME, EXP_DELAYVEC, EXP_CTRL);   % partial results survive an interruption
end

labels = EXP_LABELS; overload = EXP_OVL; comptime = EXP_TIME; delayed = EXP_DEL;
rounds = EXP_ROUNDS; inexact = EXP_INEX; initialOverload = EXP_INIT;
days = EXP_DAYS; kappas = EXP_KAPPAS; capacityUsed = EXP_CAP;
nFlights = EXP_NF; nSectors = EXP_NS;
strategicForced = EXP_FORCED(:, numel(EXP_KAPPAS)+2);
milpLowerBound = EXP_MILPLB; milpExitflag = EXP_MILPEXIT; milpTimeLimit = EXP_MILPTIME;
SaveStudy(EXP_OUT, labels, overload, comptime, delayed, rounds, inexact, initialOverload, ...
          days, kappas, capacityUsed, nFlights, nSectors, strategicForced, ...
          milpLowerBound, milpExitflag, milpTimeLimit, EXP_DELAYVEC, EXP_CTRL);

fprintf('\n===== BREST per-day, D = %d, %d days =====\n', capacityUsed, EXP_ND);
fprintf('initial overload: median %.0f  (%.0f .. %.0f) aircraft-s\n\n', ...
        median(initialOverload), min(initialOverload), max(initialOverload));
fprintf('%-18s %12s %12s %11s\n','method','median ovl','median red%','median s');
for EXP_MI = 1:EXP_NM
    fprintf('%-18s %12.0f %11.1f%% %11.2f\n', labels{EXP_MI}, ...
        median(overload(:,EXP_MI),'omitnan'), ...
        median(100*(1 - overload(:,EXP_MI)./initialOverload),'omitnan'), ...
        median(comptime(:,EXP_MI),'omitnan'));
end
fprintf('\nbest responses not proven optimal: %d\n', sum(inexact(:),'omitnan'));
fprintf('centralized MILP proven optimal on %d of %d days (exitflag 1)\n', nnz(milpExitflag==1), EXP_ND);
fprintf('wrote %s  (%.1f min)\n', EXP_OUT, toc(EXP_T0)/60);

function SaveStudy(out, labels, overload, comptime, delayed, rounds, inexact, initialOverload, ...
                   days, kappas, capacityUsed, nFlights, nSectors, strategicForced, ...
                   milpLowerBound, milpExitflag, milpTimeLimit, delayVec, controlSector) %#ok<INUSD>
% delayVec{d,k}: per-flight delay in action steps (x timeunit), method k, day d
% controlSector{d}: controlling sector id of each flight on day d
save(out, 'labels','overload','comptime','delayed','rounds','inexact', ...
     'initialOverload','days','kappas','capacityUsed','nFlights','nSectors', ...
     'strategicForced','milpLowerBound','milpExitflag','milpTimeLimit', ...
     'delayVec','controlSector');
end

function s = KappaLabel(k)
if k == 0
    s = '\kappa = 0';
elseif k > 0 && k < 1e-3
    s = sprintf('\\kappa = 10^{%d}', round(log10(k)));
else
    s = sprintf('\\kappa = %g', k);
end
end
