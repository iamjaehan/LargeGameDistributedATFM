% 파일의 flgiht 정리순서 load
infile = 'Data_4/BREST230726.SECTOR_LIST';
fin = fopen(infile, 'r');
headerLine = fgetl(fin);   % 첫 줄(1246) 건너뛰기
numFlights = str2double(strtrim(headerLine));
flightOrder = zeros(numFlights, 1);  % 미리 벡터 생성
for i = 1:numFlights
tline = fgetl(fin);
tokens = strsplit(strtrim(tline));  % 공백으로 분리
flightOrder(i) = str2double(tokens{1});  % 첫 번째 token이 Flight ID
end
fclose(fin);

% decision variable 순서 정렬
[~, idx] = ismember(flight_ids, flights);
action_reordered = action(idx);

% 검산
for i = 1:flightn
    if action_reordered(find(flightOrder == flights(i))) == action(i)
    else
        disp("WARNING: "+num2str(i))
    end
end

% 입력/출력 파일 경로
infile  = 'Data_4/BREST230726.SECTOR_LIST';
outfile = 'Data_4/BREST230726_withDecision.SECTOR_LIST';

% ===== 1. 원본 파일 읽기 =====
fin  = fopen(infile, 'r');
headerLine = fgetl(fin);  % 첫 줄 (총 flight 개수)
numFlights = str2double(strtrim(headerLine));

lines = cell(numFlights, 1);
for i = 1:numFlights
    lines{i} = fgetl(fin);
end
fclose(fin);

% ===== 2. Flight ID 추출 =====
flight_ids = zeros(numFlights,1);
for i = 1:numFlights
    tokens = strsplit(strtrim(lines{i}));
    flight_ids(i) = str2double(tokens{1});
end

% ===== 3. flights/action → flight_ids 순서로 재정렬 =====
[~, idx] = ismember(flight_ids, flights);
action_reordered = action(idx);

% ===== 4. 새 파일 작성 =====
fout = fopen(outfile, 'w');
fprintf(fout, '%s\n', headerLine);  % 첫 줄 그대로

for i = 1:numFlights
    cleanLine = strtrim(lines{i});
    fprintf(fout, '%s %d \n', cleanLine, action_reordered(i));
end

fclose(fout);

disp("완료: " + outfile);