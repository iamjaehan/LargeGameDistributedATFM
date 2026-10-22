function bodyFile = MakeExpBody(bodyFile)
% Generate ExpBody.m: Main.m with its hard-coded configuration replaced by
% EXP_* variables, so a driver can run the same pipeline many times.
%
%   MakeExpBody            % writes ExpBody.m next to Main.m
%
% The body is GENERATED, never committed.  Checking in a copy of Main.m would
% silently drift the moment Main.m changed, and the experiment would quietly
% stop measuring the current code.  Every substitution below must match
% exactly once or this errors out, which is the drift guard: if Main.m is
% edited in a way that moves an anchor, the experiment refuses to run rather
% than running against a stale assumption.
%
% The driver sets, before run('ExpBody.m'):
%   EXP_DAY  traffic date, e.g. '230726'
%   EXP_EPS  cooperativeness factor kappa
%   EXP_ALG  1 = ours, 3 = reactive FCFS, 4 = strategic FCFS, 5 = centralized MILP
%   EXP_CAP  sector capacity D
%   EXP_MILPTIME  intlinprog time limit for the centralized MILP (algorithm 5)
% and reads back postAlgCost, expElapsed, and whatever the branch produces.
%
% ExpBody.m shares the caller's workspace, so a driver MUST name its own
% variables EXP_* -- Main.m uses i, k, m, n, s, t and would clobber them.

if nargin < 1 || isempty(bodyFile), bodyFile = 'ExpBody.m'; end

src = fileread('Main.m');

subs = {
    'dataDay = ''230726'';'                     , 'dataDay = EXP_DAY;'
    'epsilon = 1;'                              , 'epsilon = EXP_EPS;'
    'algorithm = 1; %'                          , 'algorithm = EXP_ALG; %'
    'capacity = round(maxOccupancy * 0.75);'    , 'capacity = EXP_CAP;'
    'milpMaxTime = 3600;'                       , 'milpMaxTime = EXP_MILPTIME;'
    'recordHistory = true;'                     , 'recordHistory = false;'
    'rng(''shuffle'');'                         , 'rng(1);   % experiment: deterministic'
    '%% Search Equilibrium (Ours)'              , ['tExpStart = tic;' newline '%% Search Equilibrium (Ours)']
    '%% Save result'                            , ['expElapsed = toc(tExpStart);' newline '%% Save result']
};

for k = 1:size(subs,1)
    nHit = numel(strfind(src, subs{k,1}));
    if nHit ~= 1
        error('MakeExpBody:anchor', ...
            ['Main.m contains the anchor\n    %s\n%d times, expected exactly 1. ' ...
             'Main.m has changed -- update the substitution table in MakeExpBody.m ' ...
             'before running any experiment.'], subs{k,1}, nHit);
    end
    src = strrep(src, subs{k,1}, subs{k,2});
end

fid = fopen(bodyFile, 'w');
if fid < 0, error('MakeExpBody:write', 'Cannot write %s', bodyFile); end
fwrite(fid, src);
fclose(fid);
end
