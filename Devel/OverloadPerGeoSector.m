function [L, Lmax] = OverloadPerGeoSector(geo, frames, sector_ids, capacity)
% Daily cumulative overload [aircraft-min] of each BREST sector in each frame.
% L is numel(geo) x numel(frames), NaN for sectors without traffic in the data.
L = nan(numel(geo), numel(frames));
[tf, loc] = ismember(sector_ids, [geo.id]);
for f = 1:numel(frames)
    perAgent = sum(max(0, frames{f} - capacity), 2)/60;   % 1-s bins -> minutes
    L(loc(tf), f) = perAgent(tf);
end
Lmax = max(L(:));
end
