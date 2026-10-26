% RunBrestTieBreak -- the delay tie-break study behind exp_brest_days_D7_tiebreak.mat.
% Starts from the saved solutions in exp_brest_days_D7.mat (RunBrestDays):
%   ours (each kappa): PostProcessDelays -- every sector in turn minimises its own
%     flights' delay without raising any sector's overload (Definition 4 kept),
%     until no change; then one exact BRD round checks the Nash property (neAfter).
%   centralized MILP: MILPStage2FromSolution -- min delay at overload <= L*.
%   FCFS: unchanged.
% Writes exp_brest_days_D7_tiebreak.mat and the *_tiebreak figures.
cd(fileparts(mfilename('fullpath')));
D = 7; tu = 300; maxStep = 6;
S = load('exp_brest_days_D7.mat');
T = S;                                   % same fields; ours and MILP columns replaced
nD = numel(S.days); nK = numel(S.kappas); kM = find(contains(S.labels, 'MILP'));
T.tieBreakTime = nan(nD, numel(S.labels)); T.neAfter = nan(nD, nK); T.tieBreakPasses = nan(nD, nK);
T.tieBreakNote = ['Delay tie-break. Ours: each sector in turn minimises its own flights'' delay with every ' ...
    'sector''s overload held at or below its equilibrium value and Definition 4 enforced, until no change; ' ...
    'neAfter = 1 if one exact BRD round then finds no improving sector. MILP: stage 2 (min delay at overload <= L*) ' ...
    'from the saved stage-1 schedule. FCFS columns unchanged. comptime = original + tie-break time.'];
for d = 1:nD
    [flights, as] = LoadDataset('brest', S.days{d});
    n = numel(flights); earliest = inf; latest = 0; sid = []; ctrl = zeros(n,1);
    for i = 1:n, sm = as(flights(i)); sid = [sid; sm(:,1)]; ctrl(i) = sm(1,1); earliest = min(earliest, sm(1,2)); latest = max(latest, sm(end,3)); end
    earliest = earliest - 600; latest = latest + 3600;
    sector_ids = unique(sid); m = numel(sector_ids);
    occ0 = zeros(m, length(earliest:latest));
    for i = 1:n, sm = as(flights(i)); for j = 1:size(sm,1), a = round(sm(j,2)-earliest+1); b = round(sm(j,3)-earliest+1); k = find(sector_ids==sm(j,1)); occ0(k,a:b) = occ0(k,a:b)+1; end, end
    assert(isequal(ctrl, S.controlSector{d}(:)), 'flight order differs');
    for k = 1:nK
        [x, r] = PostProcessDelays(S.delayVec{d,k}(:), occ0, as, sector_ids, flights, earliest, tu, D, maxStep, ctrl, S.kappas(k));
        T.delayVec{d,k} = x; T.overload(d,k) = r.overload; T.delayed(d,k) = nnz(x);
        T.tieBreakTime(d,k) = r.time; T.comptime(d,k) = S.comptime(d,k) + r.time;
        T.neAfter(d,k) = r.nImproving == 0; T.tieBreakPasses(d,k) = r.passes;
    end
    [x, r] = MILPStage2FromSolution(occ0, as, sector_ids, flights, earliest, tu, D, maxStep, S.delayVec{d,kM}(:));
    assert(abs(r.overload - S.overload(d,kM)) < 1e-6, 'MILP stage 2 changed the overload');
    T.delayVec{d,kM} = x; T.delayed(d,kM) = nnz(x);
    T.tieBreakTime(d,kM) = r.stage2Time; T.comptime(d,kM) = S.comptime(d,kM) + r.stage2Time;
    save('exp_brest_days_D7_tiebreak.mat', '-struct', 'T');
    fprintf('day %2d/%d %s | min/ac ours %s -> %s | MILP %.2f -> %.2f (stage 2 %.0f s, exitflag %d) | NE kept %d/%d\n', d, nD, S.days{d}, ...
        mat2str(5*cellfun(@mean, S.delayVec(d,1:nK)), 3), mat2str(5*cellfun(@mean, T.delayVec(d,1:nK)), 3), ...
        5*mean(S.delayVec{d,kM}), 5*mean(x), r.stage2Time, r.exitflag, sum(T.neAfter(d,:)), nK);
end
PlotBrestDays('exp_brest_days_D7_tiebreak.mat');
PlotBrestDelayFairness('exp_brest_days_D7_tiebreak.mat');
disp('done');
