function [flightDelays, occupancyMatrix, info] = SolveMILP(initialOccupancyMatrix, assigned_sector, sector_ids, flights, earliest, timeunit, capacity, maxActionStep, maxTime, minimizeDelay)
% Exact centralized benchmark (algorithm 5): problem (17) solved as a MILP
% with intlinprog.  This is the ground-delay-only specialization of the
% Bertsimas & Stock Patterson (1998) TFMP: with fixed routes and fixed sector
% dwell times a flight's whole trajectory is fixed by its departure delay, so
% one binary per (flight, action) suffices.
%
%   stage 1:  min  sum_k w_k l_k
%             s.t. sum_a y_fa = 1                     for every flight f
%                  sum_{f,a} O_k,fa y_fa - l_k <= D    for every kept row k
%                  y binary,  l >= 0
%   stage 2:  min  sum_{f,a} a y_fa   (total delay steps)
%             s.t. the stage-1 constraints and  sum_k w_k l_k <= L*
%
% Stage 1 is problem (17).  Stage 2 (on by default, minimizeDelay) only picks,
% among the schedules with the stage-1 overload L*, the one with the least
% delay; it never changes the overload.  Without it the solver returns an
% arbitrary optimal schedule, which can delay half the flights for nothing.
%
% Rows are built on the simulator's own grid, so the optimum is directly
% comparable with ComputeSystemCost.  Every shift is a multiple of timeunit,
% so a sector's occupancy can only change at the breakpoints
% {segment entry/exit + a*timeunit}; between two breakpoints the occupancy is
% constant, and one row with weight w_k = interval length represents all of
% those bins exactly.  Rows whose occupancy cannot exceed D under any action
% choice are dropped.
%
% maxTime applies to each stage separately.
%
% info: overload (simulator recomputed), overloadLowerBound and exitflag /
%       gaps / nodes / time of stage 1, totalDelaySteps and stage-2 status,
%       nRows, nVars, buildTime, solveTime (both stages).

if nargin < 9 || isempty(maxTime), maxTime = 3600; end
if nargin < 10 || isempty(minimizeDelay), minimizeDelay = true; end

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

% warm start: the unmodified schedule
y0 = [ones(n,1); zeros(nY-n,1)];
x0 = [y0; max(0, C*y0 - capacity)];
buildTime = toc(tBuild);

% Both objectives are integer-valued, so AbsoluteGapTolerance < 1 proves
% optimality; the relative tolerance is switched off so it cannot stop the
% search earlier on large objectives.
opts = optimoptions('intlinprog', 'MaxTime', maxTime, 'Display', 'final', ...
    'RelativeGapTolerance', 0, 'AbsoluteGapTolerance', 0.99);
fprintf('SolveMILP: %d binaries, %d overload rows (%d nonzeros), built in %.1fs\n', ...
    nY, nL, nnz(A), buildTime);

tSolve = tic;
[x, fval, exitflag, output] = intlinprog(f, intcon, A, b, Aeq, beq, lb, ub, x0, opts);
if isempty(x)
    error('SolveMILP:noSolution', 'intlinprog returned no solution (exitflag %d): %s', ...
          exitflag, output.message);
end
stage1 = output;

exitflag2 = NaN; message2 = 'skipped';
if minimizeDelay
    y1 = round(x(1:nY));
    l1 = max(0, C*y1 - capacity);           % tight overload of the stage-1 schedule
    Lstar = w'*l1;
    f2 = [repelem((0:p-1)', n); zeros(nL,1)];
    A2 = [A; sparse(1, nY), w'];
    b2 = [b; Lstar];
    [x2, ~, exitflag2, output2] = intlinprog(f2, intcon, A2, b2, Aeq, beq, lb, ub, [y1; l1], opts);
    message2 = output2.message;
    if ~isempty(x2)
        x = x2;                             % same overload, fewer delays
    end
end
solveTime = toc(tSolve);

Y = reshape(round(x(1:nY)), n, p);
[~, chosen] = max(Y, [], 2);
flightDelays = chosen - 1;
occupancyMatrix = UpdateOccupancyMatrix_Centralized(n, initialOccupancyMatrix, assigned_sector, sector_ids, flightDelays, flights, earliest, timeunit);

% ---- the model and the simulator must agree exactly ----------------------
yChosen = sparse((chosen-1)*n + (1:n)', 1, 1, nY, 1);
occModel = full(C*yChosen);
occSim = occupancyMatrix(sub2ind(size(occupancyMatrix), rowSector, rowBin));
assert(isequal(occModel, occSim), 'SolveMILP:mismatch', ...
       'MILP occupancy rows disagree with the simulator.');
overload = ComputeSystemCost(m, occupancyMatrix, capacity);
assert(overload == sum(w .* max(0, occModel - capacity)), 'SolveMILP:mismatch', ...
       'Overload outside the kept rows: the row pruning is wrong.');

info = struct( ...
    'overload', overload, ...
    'overloadLowerBound', max(0, ceil(fval - stage1.absolutegap - 1e-9)), ...
    'exitflag', exitflag, 'relativeGap', stage1.relativegap, ...
    'absoluteGap', stage1.absolutegap, 'numNodes', stage1.numnodes, ...
    'message', stage1.message, ...
    'totalDelaySteps', sum(flightDelays), 'nDelayed', nnz(flightDelays), ...
    'delayExitflag', exitflag2, 'delayMessage', message2, ...
    'nRows', nL, 'nVars', nY + nL, ...
    'buildTime', buildTime, 'solveTime', solveTime);
end
