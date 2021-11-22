% Isak / Tobias / Simen 
% Rinex Read
% Version 1.2
% Date: 09/11/2021

%%
% Store current directory
current_dir = pwd;
clear all
%readRinexObs304_dirpath = "C:\Users\tobia\OneDrive\Skrivebord\GMGD320\MATLAB\GNSS_reading_protocol\readRinexObs304\readRinexObs304_sourcecode";

%data dir relative to readRinexObs304_dirpath 
%data_dir   = "C:\Users\tobia\OneDrive\Skrivebord\GMGD320\New Folder\DATA\Topcon\Topcon";
%data_dir = 'C:\Users\isakf\Documents\Geomatikk\7_2021H\GMGD320\GMGD320_Group_Task\RINEX_Rounds';
Topcon_21   = '21_10_21_50002940.21o';
Topcon_19   = '19_10_21_50002920.21o';
Topcon_14   = '14_10_21_50002870.21o';
Topcon_26   = '26_10_21_50002990.21o';
Topcon_statisk = '320m3010 .21o';
Emlid_14 = 'reach_raw_202110141047.21O';
Emlid_19 = 'reach_raw_202110191050.21O';
Emlid_21 = 'reach_raw_202110210856.21O';
Emlid_statisk = 'reach_raw_202110280857.21O';
%filename    = 'reach_raw_202110210856.21O';
filename = append(pwd, '\RINEX_Rounds\', Topcon_statisk);
Topcon = "21o";
if contains(filename,Topcon) == 1
    system = "Topcon";
else 
    system = "Emlid" ;
end

%% read only GPS, with only code observation types and all bands. Don't read SS and LLI

% changing working directory to readRinexObs304
%cd(readRinexObs304_dirpath)

includeAllGNSSsystems = 0;
includeAllObsCodes = 0;
desiredGNSSsystems = ["G"];
desiredObsCodes = ["C", "L"];
desiredObsBands = [1,2,5];
readLLI  = 0;
readSS   = 0;

[GNSS_obs, GNSS_LLI, GNSS_SS, GNSS_SVs, time_epochs, nepochs, GNSSsystems,...
    obsCodes, approxPosition, max_sat, tInterval, markerName, rinexVersion, recType, timeSystem, leapSec, gnssType,...
    rinexProgr, rinexDate, antDelta, tFirstObs, tLastObs, clockOffsetsON, GLO_Slot2ChannelMap, success] = ...
    readRinexObs304(filename,readSS,readLLI,includeAllGNSSsystems,includeAllObsCodes, desiredGNSSsystems,... 
    desiredObsCodes, desiredObsBands);

%% Iterate through only GPS. For the first 10 epochs, compute the linear combination L1C-L2X if both L1C and L2X are present

if system == "Topcon"
    desiredGNSS_systems = ["G"];
    phase1_code = "L1C";
    phase2_code = "L2W";
    code1_code  = "C1C";
    code2_code  = "C2W";
end

if system == "Emlid"
    desiredGNSS_systems = ["G"];
    phase1_code = "L1C";
    phase2_code = "L2X";
    code1_code  = "C1C";
    code2_code  = "C2X";
end

c = 299792458;
phase1_wavelength = c/(1575.42*10^6);
phase2_wavelength = c/(1227.60*10^6);
alfa = (1575.42*10^6)^2/(1227.60*10^6)^2;

n_epochs_to_display = nepochs;

% map container to map from GNSS system code to actual name
GNSSnames = containers.Map(["G","R","C","E"], ["GPS", "GLONASS", "Beidou", "Galileo"]);
nGNSSsystems = length(desiredGNSS_systems);

MP1 = []; MP2 = [];
SV_list = [];

for k = 1:nGNSSsystems
   %get current GNSS system
   sys = desiredGNSS_systems(k);
   
   % get current GNSS system index, return None if current sys is not in
   % data
   sysIndex = find([GNSSsystems{:}]==sys); 
   
   %fprintf('\nCurrently showing %s linear combinations\n\n', GNSSnames(sys))
   
   % iterate through epochs for the current GNSS system
   all_sat_MP1 = NaN(n_epochs_to_display,32);
   all_sat_MP2 = NaN(n_epochs_to_display,32);

   fasebrudd = zeros(n_epochs_to_display,32);
   for epoch =1:n_epochs_to_display
      % get number of sat for current GNSS system that have observations
      % this epoch
      n_sat = GNSS_SVs{sysIndex}(epoch, 1);
      
      % get sat IDs of current GNSS system with observation this epoch 
      SVs = GNSS_SVs{sysIndex}(epoch, 2:n_sat+1);
      
      %iterate through all satelites of current GNSS system this epoch
      for sat = 1:n_sat
         SV = SVs(sat);
                
         % get index of phase 1 & 2 and code 1 & 2 obs for current sat if present
         phase1_index = ismember(obsCodes{sysIndex},phase1_code);
         phase2_index = ismember(obsCodes{sysIndex},phase2_code);
         code1_index  = ismember(obsCodes{sysIndex},code1_code);
         code2_index  = ismember(obsCodes{sysIndex},code2_code);
         
         % get phaseobservations anf convert from units of cycles to meters
         phase1 = GNSS_obs{sysIndex}(SV, phase1_index, epoch)*phase1_wavelength;
         phase2 = GNSS_obs{sysIndex}(SV, phase2_index, epoch)*phase2_wavelength;
         
         % get code observations (m)
         code1 = GNSS_obs{sysIndex}(SV, code1_index, epoch);
         code2 = GNSS_obs{sysIndex}(SV, code2_index, epoch);
         if ~any([phase1, phase2] == 0)
              % Fasebruddindikator
            IOD = (alfa/(alfa-1))*(phase1 - phase2); 
            fasebrudd(epoch, SV) = IOD;
         end
         %check that none of the phase obs are missing
         if ~any([phase1, phase2, code1] == 0)
            % Multipath + Bias
            Mp1 = code1 - (1 + 2/(alfa-1))*phase1 + (2/(alfa-1))*phase2;                   
            all_sat_MP1(epoch,SV) = Mp1;
         end 
         if ~any([phase1, phase2, code2] == 0)
            Mp2 = code2 - (2*alfa/(alfa-1))*phase1 + (2*alfa/(alfa-1)-1)*phase2;                      
            all_sat_MP2(epoch,SV) = Mp2;
%          % get code observations (m)
%          code1 = GNSS_obs{sysIndex}(SV, code1_index, epoch);
%          code2 = GNSS_obs{sysIndex}(SV, code2_index, epoch);
%          if ~any([phase1, phase2] == 0)
%               % Fasebruddindikator
%             IOD = (alfa/(alfa-1))*(phase1 - phase2); 
%             fasebrudd(epoch, SV) = IOD;
%             % Multipath + Bias
%             Mp1 = code1 - (1 + 2/(alfa-1))*phase1 + (2/(alfa-1))*phase2;                   
%             all_sat_MP1(epoch,SV) = Mp1;
%             Mp2 = code2 - (2*alfa/(alfa-1))*phase1 + (2*alfa/(alfa-1)-1)*phase2;                      
%             all_sat_MP2(epoch,SV) = Mp2;
           
         end   
      end
   end
end


[m,n] = size(fasebrudd);
d = [];
index = [];
for i = 1:m-1
    for j = 1:n
        d2 = fasebrudd(i+1,j);
        d = fasebrudd(i,j);
        dis = d2 - d;
        if abs(dis)  > 4/60 || (dis ~= 0 && i == 1)
            index = [index;j,i];
            %index = [index;j,i+1];
        elseif abs(dis)  < 4/60 && (dis ~= 0 && i+1 == nepochs)
            index = [index;j,i+1];
            %index = [index;j,i+1];
        end
    end
end  
index = sortrows(index,1);
[n, m] =size(index);

mean_table_MP1 = [];
mean_table_MP2 = [];
for k = 1:n-1
    if (index(k,1) == index(k+1,1))% && index(k,2) ~= 1   %&& (k+2 < m && isnan(all_sat_MP1(index(k+2,1),index(k+2,2))) == 1)
        mean_table_MP1 = [mean_table_MP1;index(k,1),index(k,2),(index(k+1,2)),mean(all_sat_MP1(index(k,2):(index(k+1,2)),index(k,1)),'omitnan')];
        mean_table_MP2 = [mean_table_MP2;index(k,1),index(k,2),(index(k+1,2)),mean(all_sat_MP2(index(k,2):(index(k+1,2)),index(k,1)),'omitnan')];
    end
end

mean_table_MP1( any( isnan(mean_table_MP1), 2 ), : ) = [];
mean_table_MP2( any( isnan(mean_table_MP2), 2 ), : ) = [];
[m,n] = size(mean_table_MP1);
for k = 1:m-1
    if mean_table_MP1(k+1,2) == mean_table_MP1(k,3)
        mean_table_MP1(k+1,2) = mean_table_MP1(k+1,2)+1;
    end
    if mean_table_MP2(k+1,2) == mean_table_MP2(k,3) 
        mean_table_MP2(k+1,2) = mean_table_MP2(k+1,2)+1;
    end
end

 
% Fjerner Bias fra MP (MP-Bias)    
[m,n] = size(mean_table_MP1);
real_MP1 = all_sat_MP1;
real_MP2 = all_sat_MP2;
for i = 1:m
    real_MP1(mean_table_MP1(i,2):mean_table_MP1(i,3),mean_table_MP1(i,1)) = (real_MP1(mean_table_MP1(i,2):mean_table_MP1(i,3),mean_table_MP1(i,1))) - (mean_table_MP1(i,4));
    real_MP2(mean_table_MP2(i,2):mean_table_MP2(i,3),mean_table_MP2(i,1)) = (real_MP2(mean_table_MP2(i,2):mean_table_MP2(i,3),mean_table_MP2(i,1))) - (mean_table_MP2(i,4));
end
    
% Fjerner alle kolonner med kun "NaN" verdier
%real_MP1 = real_MP1(:,~all(isnan(real_MP1)));
%real_MP2 = real_MP2(:,~all(isnan(real_MP2)));

% Plot
[m, n] = size(real_MP1);
[m, n] = size(real_MP2);

% Test

MP1 = figure;
for i = 1:n
    plot(real_MP1(:, i))
    hold on
end
[row,kolonne] =  size(mean_table_MP1);
mean_value = mean(abs(mean_table_MP1(1:row,kolonne)),'omitnan');
tekst = [system, 'Multipath for ionospheric free linear combination 1 with the mean value of', mean_value, 'm'];
title(tekst);
ylim([-10 10]);
xlim([-5 7700]);
xlabel('Epochs') 
ylabel('Noise(meters)') 
filnavn = append(system,'_MP1.png');
exportgraphics(MP1,filnavn)
MP2 = figure;
for i = 1:n
    plot(real_MP2(:, i))
    hold on
    
end
[row,kolonne] =  size(mean_table_MP2);
mean_value = mean(abs(mean_table_MP2(1:row,kolonne)),'omitnan');
tekst = [system, 'Multipath for ionospheric free linear combination 2 with the mean value of', mean_value, 'm'];
title(tekst);
ylim([-10 10]);
xlim([-5 7700]);
xlabel('Epochs') 
ylabel('Noise(meters)')
filnavn = append(system,'_MP2.png');
exportgraphics(MP2,filnavn)
%plot(real_MP(:,4))

[row,kolonne] =  size(mean_table_MP1);
bias = figure
for k = 1:row
    nj = mean_table_MP1(k,2)-mean_table_MP1(k,1);
    ni = mean_table_MP1(k,2)-mean_table_MP1(k,1)
end

sqrt((mean(real_MP1(1,:),'omitnan')^2)/(mean_table_MP1(1,3)-mean_table_MP1(1,2)))


