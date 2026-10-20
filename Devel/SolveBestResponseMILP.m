function [newAction, info] = SolveBestResponseMILP(occupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, flightsUnderControl, prevAction, sectorIdx, epsilon, maxTime)
% Exact best response of one sector (Algorithm 1 line 7, problem (16)) as a
% MILP solved with intlinprog.
%
% Sector i re-chooses the delays of its own flights F_i, every other flight
% fixed at its current action:
%   min  L_i + kappa * sum_{j~=i} L_j
%   s.t. no sector-time pair outside O(x^(t)) becomes overloaded (Def. 4)
%
% With base = occupancy without F_i, rows are the sector-time intervals on
% which base and every possible F_i contribution are constant (breakpoints of
% base plus every shifted segment end), so the model is exact on the
% simulator grid:
%   rows in O(x):      base + C y - l <= D,  l >= 0,  cost w*l   (soft)
%   rows outside O(x): base + C y     <= D                       (Def. 4, hard)
% Rows that cannot exceed D under any choice, and overloaded rows of other
% sectors when kappa = 0, are dropped: they never change cost or feasibility.
%
% The objective is J_i / kappa (or L_i when kappa = 0): own rows weigh
% 1/kappa, others 1.  For the paper's kappa values 1/kappa is an integer, the
% objective is integer-valued, and AbsoluteGapTolerance < 1 proves the best
% response exact.
%
% info: exitflag, absoluteGap, relativeGap, exact, nRows, nVars, buildTime,
%       solveTime.

if nargin < 13 || isempty(maxTime), maxTime = 600; end

tBuild = tic;
F = reshape(flightsUnderControl, 1, []);
nc = numel(F);
p = maxActionStep + 1;
nY = nc*p;                                % y(q,a) lives in column a*nc + q
prevAction = reshape(prevAction, [], 1);

% Segments of the controlled flights (local flight index q = 1..nc).
segF = []; segS = []; segA = []; segB = [];
for q = 1:nc
    sectorMap = assigned_sector(flights(F(q)));
    k = size(sectorMap,1);
    [~, localIdx] = ismember(sectorMap(:,1), sector_ids);
    segF = [segF; q*ones(k,1)];                               %#ok<AGROW>
    segS = [segS; localIdx];                                  %#ok<AGROW>
    segA = [segA; round(sectorMap(:,2) - earliest + 1)];      %#ok<AGROW>
    segB = [segB; round(sectorMap(:,3) - earliest + 1)];      %#ok<AGROW>
end

% Occupancy of everything sector i does not control (inclusive bins, as in
% UpdateOccupancyMatrix).
base = occupancyMatrix;
for r = 1:numel(segF)
    sh = prevAction(segF(r))*timeunit;
    bins = segA(r)+sh : segB(r)+sh;
    base(segS(r), bins) = base(segS(r), bins) - 1;
end

if epsilon > 0
    cOwn = 1/epsilon; cOther = 1;
else
    cOwn = 1; cOther = 0;
end
yPrev = sparse(prevAction*nc + (1:nc)', 1, 1, nY, 1);

Cb = {}; rhsb = {}; softb = {}; costb = {}; sb = {}; tb = {};
shifts = (0:p-1)*timeunit;
for s = unique(segS)'
    idx = find(segS == s);
    st = segA(idx) + shifts;            % first bin of each (segment, action)
    en = segB(idx) + shifts + 1;        % one past the last bin
    lo = min(st(:)); hi = max(en(:));
    row = base(s,:);
    bc = find(diff(row(lo:hi-1)) ~= 0) + lo;   % bins where base changes
    B = unique([st(:); en(:); bc(:)]);         % row k covers B(k) .. B(k+1)-1
    K = numel(B) - 1;

    [~, ks] = ismember(st(:), B);
    [~, ke] = ismember(en(:), B);
    ke = ke - 1;
    cnt = ke - ks + 1;
    col = repmat(segF(idx), 1, p) + repmat((0:p-1)*nc, numel(idx), 1);
    first = cumsum([0; cnt(1:end-1)]);
    rr = repelem(ks, cnt) + (1:sum(cnt))' - 1 - repelem(first, cnt);
    Cs = sparse(rr, repelem(col(:), cnt), 1, K, nY);

    bK = row(B(1:K))';
    cur = bK + Cs*yPrev;
    worst = Cs(:, 1:nc);
    for a = 2:p
        worst = max(worst, Cs(:, (a-1)*nc + (1:nc)));
    end
    maxOcc = bK + full(sum(worst, 2));
    inO = full(cur) > capacity;
    weight = cOwn*(s == sectorIdx) + cOther*(s ~= sectorIdx);
    keep = maxOcc > capacity & ~(inO & weight == 0);

    w = diff(B);
    Cb{end+1}    = Cs(keep,:);                  %#ok<AGROW>
    rhsb{end+1}  = capacity - bK(keep);         %#ok<AGROW>
    softb{end+1} = inO(keep);                   %#ok<AGROW>
    costb{end+1} = weight*w(keep);              %#ok<AGROW>
    sb{end+1}    = s*ones(nnz(keep),1);         %#ok<AGROW>
    tb{end+1}    = B(keep);                     %#ok<AGROW>
end
C = vertcat(Cb{:}); rhs = vertcat(rhsb{:}); soft = vertcat(softb{:});
cost = vertcat(costb{:}); rowSector = vertcat(sb{:}); rowBin = vertcat(tb{:});
nR = size(C,1); nL = nnz(soft);

info = struct('exitflag', NaN, 'absoluteGap', 0, 'relativeGap', 0, 'exact', true, ...
              'nRows', nR, 'nVars', nY + nL, 'buildTime', 0, 'solveTime', 0);
if nR == 0
    % nothing sector i does can change its cost or violate Def. 4
    newAction = prevAction';
    info.buildTime = toc(tBuild);
    return;
end

E = sparse(find(soft), 1:nL, 1, nR, nL);
f = [zeros(nY,1); cost(soft)];
A = [C, -E];
Aeq = [kron(ones(1,p), speye(nc)), sparse(nc, nL)];
beq = ones(nc,1);
lb = zeros(nY+nL, 1);
ub = [ones(nY,1); inf(nL,1)];
intcon = 1:nY;
x0 = [full(yPrev); max(0, C(soft,:)*full(yPrev) - rhs(soft))];   % incumbent, feasible

integerObjective = epsilon == 0 || abs(1/epsilon - round(1/epsilon)) < 1e-9;
if integerObjective
    absTol = 0.99;
else
    absTol = 1e-6;
end
opts = optimoptions('intlinprog', 'MaxTime', maxTime, 'Display', 'off', ...
    'RelativeGapTolerance', 0, 'AbsoluteGapTolerance', absTol);
info.buildTime = toc(tBuild);

tSolve = tic;
[x, ~, exitflag, output] = intlinprog(f, intcon, A, rhs, Aeq, beq, lb, ub, x0, opts);
info.solveTime = toc(tSolve);
info.exitflag = exitflag;
if isempty(x)
    newAction = prevAction';
    info.exact = false;
    return;
end
info.absoluteGap = output.absolutegap;
info.relativeGap = output.relativegap;
info.exact = exitflag == 1 && integerObjective;

Y = reshape(round(x(1:nY)), nc, p);
[~, chosen] = max(Y, [], 2);
newAction = (chosen - 1)';

% ---- the model must agree with the simulator --------------------------------
newOcc = base;
for r = 1:numel(segF)
    sh = newAction(segF(r))*timeunit;
    bins = segA(r)+sh : segB(r)+sh;
    newOcc(segS(r), bins) = newOcc(segS(r), bins) + 1;
end
yNew = sparse((chosen-1)*nc + (1:nc)', 1, 1, nY, 1);
occModel = (capacity - rhs) + full(C*yNew);
occSim = newOcc(sub2ind(size(newOcc), rowSector, rowBin));
assert(isequal(occModel, occSim), 'SolveBestResponseMILP:mismatch', ...
       'Best-response rows disagree with the simulator.');
assert(~any(newOcc(:) > capacity & occupancyMatrix(:) <= capacity), ...
       'SolveBestResponseMILP:def4', 'Best response violates Definition 4.');
end
