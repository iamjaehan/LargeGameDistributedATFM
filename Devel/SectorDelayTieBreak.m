function [newAction, info] = SectorDelayTieBreak(occ, as, sector_ids, flights, earliest, timeunit, D, maxStep, F, prevAction)
% Post-processing option A, one sector: re-choose the delays of this sector's
% flights F (others fixed) to MINIMISE their total delay steps, subject to
%   - no sector's cumulative overload L_j increases          (so no J_j rises)
%   - Definition 4: no currently feasible sector-time pair becomes overloaded
% The current action is feasible, so the result never has more delay.
F = reshape(F, 1, []); nc = numel(F); p = maxStep + 1; nY = nc*p;
prevAction = reshape(prevAction, [], 1);
segF = []; segS = []; segA = []; segB = [];
for q = 1:nc
    sm = as(flights(F(q))); k = size(sm,1);
    [~, li] = ismember(sm(:,1), sector_ids);
    segF = [segF; q*ones(k,1)]; segS = [segS; li]; %#ok<AGROW>
    segA = [segA; round(sm(:,2) - earliest + 1)]; segB = [segB; round(sm(:,3) - earliest + 1)]; %#ok<AGROW>
end
base = occ;
for r = 1:numel(segF)
    sh = prevAction(segF(r))*timeunit; bins = segA(r)+sh : segB(r)+sh;
    base(segS(r), bins) = base(segS(r), bins) - 1;
end
yPrev = sparse(prevAction*nc + (1:nc)', 1, 1, nY, 1);
Cb = {}; rhsb = {}; softb = {}; wb = {}; sb = {};
shifts = (0:p-1)*timeunit;
for s = unique(segS)'
    idx = find(segS == s);
    st = segA(idx) + shifts; en = segB(idx) + shifts + 1;
    lo = min(st(:)); hi = max(en(:)); row = base(s,:);
    bc = find(diff(row(lo:hi-1)) ~= 0) + lo;
    B = unique([st(:); en(:); bc(:)]); K = numel(B) - 1;
    [~, ks] = ismember(st(:), B); [~, ke] = ismember(en(:), B); ke = ke - 1;
    cnt = ke - ks + 1;
    col = repmat(segF(idx), 1, p) + repmat((0:p-1)*nc, numel(idx), 1);
    first = cumsum([0; cnt(1:end-1)]);
    rr = repelem(ks, cnt) + (1:sum(cnt))' - 1 - repelem(first, cnt);
    Cs = sparse(rr, repelem(col(:), cnt), 1, K, nY);
    bK = row(B(1:K))'; cur = bK + Cs*yPrev;
    worst = Cs(:, 1:nc); for a = 2:p, worst = max(worst, Cs(:, (a-1)*nc + (1:nc))); end
    keep = bK + full(sum(worst, 2)) > D;          % rows that could ever be overloaded
    w = diff(B);
    Cb{end+1} = Cs(keep,:); rhsb{end+1} = D - bK(keep);              %#ok<AGROW>
    softb{end+1} = full(cur(keep)) > D; wb{end+1} = w(keep); sb{end+1} = s*ones(nnz(keep),1); %#ok<AGROW>
end
C = vertcat(Cb{:}); rhs = vertcat(rhsb{:}); soft = vertcat(softb{:}); w = vertcat(wb{:}); rs = vertcat(sb{:});
nR = size(C,1); nL = nnz(soft);
info = struct('exitflag', NaN, 'changed', false);
if nR == 0          % no row of interest: any delay is free, take zero delay
    newAction = zeros(1, nc); info.changed = any(prevAction); info.exitflag = 1; return;
end
E = sparse(find(soft), 1:nL, 1, nR, nL);
A = [C, -E];                                     % occupancy - l <= D  (hard rows: l absent)
% per-sector overload budget over the modelled soft rows: sum w*l <= current
sectS = rs(soft); wS = w(soft); us = unique(sectS);
lCur = max(0, full(C(soft,:)*yPrev) - rhs(soft));
Abud = sparse(numel(us), nY + nL); bbud = zeros(numel(us),1);
for u = 1:numel(us)
    m_ = sectS == us(u);
    Abud(u, nY + find(m_)) = wS(m_)'; %#ok<SPRIX>
    bbud(u) = wS(m_)'*lCur(m_);
end
f = [repelem((0:p-1)', nc); zeros(nL,1)];
Aeq = [kron(ones(1,p), speye(nc)), sparse(nc, nL)]; beq = ones(nc,1);
lb = zeros(nY+nL,1); ub = [ones(nY,1); inf(nL,1)];
x0 = [full(yPrev); lCur];
opts = optimoptions('intlinprog', 'Display','off', 'MaxTime', 600, ...
                    'RelativeGapTolerance', 0, 'AbsoluteGapTolerance', 0.99);
[x, ~, ef] = intlinprog(f, 1:nY, [A; Abud], [rhs; bbud], Aeq, beq, lb, ub, x0, opts);
info.exitflag = ef;
if isempty(x), newAction = prevAction'; return; end
Y = reshape(round(x(1:nY)), nc, p); [~, ch] = max(Y, [], 2);
newAction = (ch - 1)'; info.changed = any(newAction(:) ~= prevAction(:));
end
