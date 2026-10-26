function [flightDelays, info] = MILPStage2FromSolution(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, stage1Delays)
% Stage 2 of SolveMILP started from a saved, proven-optimal stage-1 schedule:
%   min total delay steps  s.t.  the stage-1 constraints, sum_k w_k l_k <= L*,
% with L* the overload of stage1Delays.  Same model rows as SolveMILP (copied).
tBuild = tic;
m = size(initialOccupancyMatrix, 1);
n = length(flights);
p = maxActionStep + 1;    % actions 0..maxActionStep
nY = n*p;                 % y(f,a) lives in column a*n + f

% Flight segments in simulator indexing (bins segStart..segEnd, inclusive,
% as in UpdateOccupancyMatrix).
segFlight = []; segSector = []; segStart = []; segEnd = [];
for i = 1:n
    sectorMap = assigned_sector(flights(i));
    k = size(sectorMap,1);
    [~, localIdx] = ismember(sectorMap(:,1), sector_ids);
    segFlight = [segFlight; i*ones(k,1)];                          %#ok<AGROW>
    segSector = [segSector; localIdx];                             %#ok<AGROW>
    segStart  = [segStart;  round(sectorMap(:,2) - earliest + 1)]; %#ok<AGROW>
    segEnd    = [segEnd;    round(sectorMap(:,3) - earliest + 1)]; %#ok<AGROW>
end

Cblocks = {}; wBlocks = {}; sBlocks = {}; tBlocks = {};
shifts = (0:p-1)*timeunit;
for s = 1:m
    idx = find(segSector == s);
    if isempty(idx), continue; end

    st = segStart(idx) + shifts;        % first bin, |idx| x p
    en = segEnd(idx) + shifts + 1;      % one past the last bin
    B = unique([st(:); en(:)]);         % row k covers bins B(k) .. B(k+1)-1
    K = numel(B) - 1;
    [~, ks] = ismember(st(:), B);
    [~, ke] = ismember(en(:), B);
    ke = ke - 1;
    cnt = ke - ks + 1;
    col = repmat(segFlight(idx), 1, p) + repmat((0:p-1)*n, numel(idx), 1);

    % expand each (segment, action) over the rows it covers
    first = cumsum([0; cnt(1:end-1)]);
    rr = repelem(ks, cnt) + (1:sum(cnt))' - 1 - repelem(first, cnt);
    Cs = sparse(rr, repelem(col(:), cnt), 1, K, nY);

    % largest occupancy the row can reach: each flight at its worst action
    worst = Cs(:, 1:n);
    for a = 2:p
        worst = max(worst, Cs(:, (a-1)*n + (1:n)));
    end
    keep = full(sum(worst, 2)) > capacity;

    w = diff(B);
    Cblocks{end+1} = Cs(keep,:);  %#ok<AGROW>
    wBlocks{end+1} = w(keep);     %#ok<AGROW>
    sBlocks{end+1} = s*ones(nnz(keep),1); %#ok<AGROW>
    tBlocks{end+1} = B(keep);     %#ok<AGROW>
end
C = vertcat(Cblocks{:});
w = vertcat(wBlocks{:});
rowSector = vertcat(sBlocks{:});
rowBin = vertcat(tBlocks{:});
nL = size(C,1);

f = [zeros(nY,1); w];
A = [C, -speye(nL)];
b = capacity*ones(nL,1);
Aeq = [kron(ones(1,p), speye(n)), sparse(n, nL)];
beq = ones(n,1);
lb = zeros(nY+nL, 1);
ub = [ones(nY,1); inf(nL,1)];
intcon = 1:nY;


y1 = sparse((stage1Delays(:))*n + (1:n)', 1, 1, nY, 1); y1 = full(y1);
l1 = max(0, C*y1 - capacity);
Lstar = w'*l1;
f2 = [repelem((0:p-1)', n); zeros(nL,1)];
A2 = [A; sparse(1, nY), w'];
b2 = [b; Lstar];
opts = optimoptions('intlinprog', 'Display', 'off', 'RelativeGapTolerance', 0, 'AbsoluteGapTolerance', 0.99);
t2 = tic;
[x2, ~, exitflag2] = intlinprog(f2, intcon, A2, b2, Aeq, beq, lb, ub, [y1; l1], opts);
stage2Time = toc(t2);
Y = reshape(round(x2(1:nY)), n, p); [~, chosen] = max(Y, [], 2);
flightDelays = chosen - 1;
occ = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, flightDelays, flights, earliest, timeunit);
overload = ComputeSystemCost(m, occ, capacity);
assert(overload <= Lstar + 1e-9, 'stage 2 raised the overload');
info = struct('overload', overload, 'Lstar', Lstar, 'exitflag', exitflag2, ...
              'buildTime', toc(tBuild) - stage2Time, 'stage2Time', stage2Time);
end
