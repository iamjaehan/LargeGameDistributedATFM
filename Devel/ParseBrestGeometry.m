function geo = ParseBrestGeometry(areFile, gslFile)
% Sector footprints of the BREST FIR, for map plots.
%
%   geo = ParseBrestGeometry()      % uses ../Data_3/BREST.are and .gsl
%
% .are : airblocks; a header "<nPoints> ... <name>" followed by nPoints lines
%        "<lat> <lon>" in arc-minutes.
% .gsl : sectors in order ("S;<code>;<name>;<nBlocks>;..."), each followed by
%        its airblocks ("A;<block>;+;<FLmin>;<FLmax>").
% Sector k of the .gsl is agent id k in the BREST .SECTOR_LIST data.
%
% geo(k): id, code, name, layer ('Lower','F','I','U'), flMin, flMax,
%         shape (polyshape in lon/lat degrees, union of its airblocks).
% Layers follow the code's last letter (LFRRxS / xF / xI / xU; the TMA
% LFRBFIS is Lower); sectors in one layer never share an airblock.

if nargin < 1, areFile = '../Data_3/BREST.are'; end
if nargin < 2, gslFile = '../Data_3/BREST.gsl'; end

% ---- airblocks ----------------------------------------------------------------
lines = strtrim(readlines(areFile));
blocks = containers.Map('KeyType','char','ValueType','any');
i = 1;
while i <= numel(lines)
    tok = strsplit(lines(i));
    nPts = str2double(tok(1));
    if numel(tok) >= 3 && ~isnan(nPts) && nPts == fix(nPts) && nPts > 2
        name = char(tok(end));
        xy = str2double(split(lines(i+1:i+nPts)));   % [lat lon] in arc-minutes
        blocks(name) = [xy(:,2), xy(:,1)]/60;        % [lon lat] degrees
        i = i + nPts + 1;
    else
        i = i + 1;
    end
end

% ---- sectors ------------------------------------------------------------------
lines = strtrim(readlines(gslFile));
geo = struct('id', {}, 'code', {}, 'name', {}, 'layer', {}, 'flMin', {}, 'flMax', {}, 'shape', {});
warnState = warning('off', 'MATLAB:polyshape:repairedBySimplify');
for i = 1:numel(lines)
    tok = split(lines(i), ';');
    if tok(1) == "S"
        k = numel(geo) + 1;
        geo(k).id = k;
        geo(k).code = char(tok(2));
        geo(k).name = char(tok(3));
        geo(k).flMin = inf; geo(k).flMax = -inf;
        geo(k).shape = polyshape();
        last = geo(k).code(end);
        if strcmp(geo(k).code, 'LFRBFIS') || last == 'S'
            geo(k).layer = 'Lower';
        else
            geo(k).layer = last;
        end
    elseif tok(1) == "A"
        k = numel(geo);
        b = char(tok(2));
        if ~isKey(blocks, b)
            error('ParseBrestGeometry:missingBlock', 'Airblock %s of %s not in %s', b, geo(k).code, areFile);
        end
        xy = blocks(b);
        geo(k).shape = union(geo(k).shape, polyshape(xy(:,1), xy(:,2)));
        geo(k).flMin = min(geo(k).flMin, str2double(tok(4)));
        geo(k).flMax = max(geo(k).flMax, str2double(tok(5)));
    end
end
warning(warnState);
end
