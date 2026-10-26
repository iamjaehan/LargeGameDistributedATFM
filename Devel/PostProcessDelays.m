function [x, info] = PostProcessDelays(x, occ0, as, sector_ids, flights, earliest, tu, D, maxStep, ctrl, kap)
% Option A: sectors in turn minimise their own flights' delay (SectorDelayTieBreak)
% until a full pass changes nothing; then check the result is still a Nash
% equilibrium with one exact best-response round.
n = numel(flights); m = numel(sector_ids);
Lsec = @(o) sum(max(0, o - D), 2);
occ = UpdateOccupancyMatrix_Centralized(n, occ0, as, sector_ids, x, flights, earliest, tu);
t0 = tic; passes = 0;
while true
    passes = passes + 1; changed = false;
    for si = 1:m
        F = find(ctrl == sector_ids(si))'; if isempty(F), continue; end
        [na, r] = SectorDelayTieBreak(occ, as, sector_ids, flights, earliest, tu, D, maxStep, F, x(F));
        if ~r.changed, continue; end
        xn = x; xn(F) = na(:);
        occN = UpdateOccupancyMatrix_Centralized(n, occ0, as, sector_ids, xn, flights, earliest, tu);
        assert(all(Lsec(occN) <= Lsec(occ) + 1e-9), 'a sector overload increased');
        assert(~any(occN(:) > D & occ(:) <= D), 'Definition 4 violated');
        assert(sum(xn) <= sum(x), 'delay increased');
        x = xn; occ = occN; changed = true;
    end
    if ~changed, break; end
end
tbTime = toc(t0);
nImp = 0;
for si = 1:m
    F = find(ctrl == sector_ids(si))'; if isempty(F), continue; end
    na = SolveBestResponseMILP(occ, as, sector_ids, flights, earliest, tu, D, maxStep, F, x(F)', si, kap, 600);
    xc = x; xc(F) = na(:);
    oc = UpdateOccupancyMatrix_Centralized(n, occ0, as, sector_ids, xc, flights, earliest, tu);
    if any(oc(:) > D & occ(:) <= D), continue; end
    Lc = Lsec(oc); Lp = Lsec(occ);
    if Lc(si) + kap*(sum(Lc) - Lc(si)) < Lp(si) + kap*(sum(Lp) - Lp(si)) - 1e-9, nImp = nImp + 1; end
end
info = struct('overload', sum(Lsec(occ)), 'time', tbTime, 'passes', passes, 'nImproving', nImp);
end
