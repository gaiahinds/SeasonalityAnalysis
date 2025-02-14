clearvars
close all

%% Parameters defined by user
filePrefix = 'Cross'; % File name to match. 
siteabrev = 'CSM'; %abbreviation of site
sp = 'Pm'; % your species code
srate = 200; % sample rate
tpwsPath = 'I:\My Drive\CentralPac_TPWS_metadataReduced\CSM\TPWS_125\TPWS2\'; %directory of TPWS files
saveDir = 'I:\My Drive\CentralPac_TPWS_metadataReduced\CSM\Seasonality'; %specify directory to save files
effortXls = 'I:\My Drive\CentralPac_TPWS_metadataReduced\CSM\Pm_Effort.xlsx'; % specify excel file with effort times
dayBinCSV= 'I:\My Drive\CentralPac_TPWS_metadataReduced\CSM\Seasonality\KR_dayData_forGLMR125.csv'; % specify csv document with general PM information
%% Get effort times matching prefix file
%when multiple sites in the effort table
allEfforts = readtable(effortXls); %read effort table
site = siteabrev; %abbreviation used in effort table

siteNUM = unique(allEfforts.Sites);
[sr,~] = size(siteNUM);

if sr > 1
    effTable = allEfforts(ismember(allEfforts.Sites,site),:); %effort is for multiple sites
else
    effTable = allEfforts; %effort is for one site only
end

% make Variable Names consistent
startVar = find(~cellfun(@isempty,regexp(effTable.Properties.VariableNames,'Start.*Effort'))>0,1,'first');
endVar = find(~cellfun(@isempty,regexp(effTable.Properties.VariableNames,'End.*Effort'))>0,1,'first');
effTable.Properties.VariableNames{startVar} = 'Start';
effTable.Properties.VariableNames{endVar} = 'End';

Start = datetime(x2mdate(effTable.Start),'ConvertFrom','datenum');
End = datetime(x2mdate(effTable.End),'ConvertFrom','datenum');

effort = table(Start,End);
%% get default parameters
p = sp_setting_defaults('sp',sp,'analysis','SumPPICIBin');
%% group effort in bins
effort.diffSec = seconds(effort.End-effort.Start);
effort.bins = effort.diffSec/(60*p.binDur);
effort.roundbin = round(effort.diffSec/(60*p.binDur));

secMonitEffort = sum(effort.diffSec);
binMonitEffort = sum(effort.roundbin);

[er,~] = size(effort.Start);

if er > 1
    binEffort = intervalToBinTimetable(effort.Start,effort.End,p); % convert intervals in bins when there is multiple lines of effort
    binEffort.sec = binEffort.bin*(p.binDur*60);
else
    binEffort = intervalToBinTimetable_Only1RowEffort(effort.Start,effort.End,p); % convert intervals in bins when there is only one line of effort
    binEffort.sec = binEffort.bin*(p.binDur*60);
end
%% load data
filename = [tpwsPath,filePrefix,'_',sp,'_gender.mat'];
load(filename);
%% group data by days and add effort
binPresence = synchronize (binData, binEffort);
binPresence.Properties.VariableNames{'bin'} = 'Effort_Bin';
binPresence.Properties.VariableNames{'sec'} = 'Effort_Sec';
binPresence = retime(binPresence,'daily','sum');
binPresence.maxPP = [];
binPresence.meanICI = [];
binPresence.BigMale = [];
binPresence.Other = [];
binPresence.Count = [];
binPresence(~binPresence.Effort_Bin,:) = []; %removes days with no effort, NOT days with no presence
%% accounting for effort
[p,q]=size(binPresence);
binPresence.MaxEffort_Bin = ones(p,1)*(288);
binPresence.MaxEffort_Sec = ones(p,1) * (86400); %seconds in one day

%dealing with duty cycled data
if strcmp(siteabrev,'CB');
    ge = binPresence.Effort_Bin(222:516); %bin effort (excluding ships but not considering the duty cycle)
    ge = ge/288; %%proportion of data that was not 'ships' considering full recording effort
    binPresence.Effort_Bin(222:516) = ge * 240; %for CB02 10 on 2 off (12 minute cycle) -- meaning you're recording 0.8333 percent of the time
    binPresence.Effort_Sec(222:516) = binPresence.Effort_Bin(222:516) * 5 * 60;
    else
if strcmp(siteabrev,'BD');
    ge = binPresence.Effort_Bin(274:end); %bin effort (excluding ships but not considering the duty cycle)
    ge = ge/288; %%proportion of data that was not 'ships' considering full recording effort
    binPresence.Effort_Bin(274:end) = ge * 144; %for ALEUT03BD ONLY 5 on 5 off (10 minute cycle) -- meaning you're recording 0.5 percent of the time
    binPresence.Effort_Sec(274:end) = binPresence.Effort_Bin(274:end) * 5 * 60;
    else
binPresence.MaxEffort_Bin = ones(p,1)*(288);
end
end

%Proportion of hours
binPresence.FeMinutes = binPresence.Female *5;
binPresence.JuMinutes = binPresence.Juvenile *5;
binPresence.MaMinutes = binPresence.Male *5;
binPresence.FeHours = binPresence.FeMinutes ./60;
binPresence.JuHours = binPresence.JuMinutes ./60;
binPresence.MaHours = binPresence.MaMinutes ./60;
binPresence.FeHoursProp = binPresence.FeHours ./(binPresence.Effort_Sec ./ (60*60));
binPresence.JuHoursProp = binPresence.JuHours ./(binPresence.Effort_Sec ./ (60*60));
binPresence.MaHoursProp = binPresence.MaHours ./(binPresence.Effort_Sec ./ (60*60));

%normalize bin counts for each sex based on bin effort
binPresence.NormEffort_Bin = binPresence.Effort_Bin./binPresence.MaxEffort_Bin; %what proportion of the day was there effort
binPresence.NormEffort_Sec = binPresence.Effort_Sec./binPresence.MaxEffort_Sec; %what proportion of the day was there effort
binPresence.FemaleNormBin = round(binPresence.Female ./ binPresence.NormEffort_Bin); %what would the normalized bin count be given the amount of effort for Females
binPresence.JuvenileNormBin = round(binPresence.Juvenile ./ binPresence.NormEffort_Bin); %what would the normalized bin count be given the amount of effort for Juveniles
binPresence.MaleNormBin = round(binPresence.Male ./ binPresence.NormEffort_Bin); %what would the normalized bin count be given the amount of effort for Males
binPresence.FemaleHoursNorm = round(binPresence.FemaleNormBin ./ binPresence.NormEffort_Bin); %convert the number of 5-min bins per day to hours
binPresence.JuvenileHoursNorm = round(binPresence.JuvenileNormBin ./ binPresence.NormEffort_Bin); %convert the number of 5-min bins per day to hours
binPresence.MaleHoursNorm = round(binPresence.MaleNormBin ./ binPresence.NormEffort_Bin); %convert the number of 5-min bins per day to hours
%% find month and season
binPresence.Season = zeros(p,1);
binPresence.month = month(binPresence.tbin);

%Winter starts on January (closest to the real thing, which is Dec. 21st)
summeridxD = (binPresence.month == 7  | binPresence.month == 8 | binPresence.month == 9);
fallidxD = (binPresence.month == 10  | binPresence.month == 11 | binPresence.month == 12);
winteridxD = (binPresence.month == 1  | binPresence.month == 2 | binPresence.month == 3);
springidxD = (binPresence.month == 4  | binPresence.month == 5 | binPresence.month == 6);

binPresence.Season(summeridxD) = 1;
binPresence.Season(fallidxD) = 2;
binPresence.Season(winteridxD) = 3;
binPresence.Season(springidxD) = 4;

%add year and day to data
binPresence.Year = year(binPresence.tbin);
binPresence.day = day(binPresence.tbin,'dayofyear');

NANidx = ismissing(binPresence(:,{'FemaleNormBin'}));
binPresence{:,{'FemaleNormBin'}}(NANidx) = 0; %if there was effort, but no detections change the NormBin column to zero

NANidx = ismissing(binPresence(:,{'JuvenileNormBin'}));
binPresence{:,{'JuvenileNormBin'}}(NANidx) = 0; %if there was effort, but no detections change the NormBin column to zero

NANidx = ismissing(binPresence(:,{'MaleNormBin'}));
binPresence{:,{'MaleNormBin'}}(NANidx) = 0; %if there was effort, but no detections change the NormBin column to zero

writetable(timetable2table(binPresence), [saveDir,'\', siteabrev, '_binPresence.csv']); %table with bin presence for each sex (timeseries)
%% day table with days grouped together (summed and averaged) ** USE THIS **
[MD,~] = findgroups(binPresence.day);

if length(MD) < 365
    meantab365 = table(binPresence.day(:), binPresence.FeHoursProp(:),binPresence.JuHoursProp(:),binPresence.MaHoursProp(:));
    meantab365.Properties.VariableNames = {'Day' 'HoursPropFE' 'HoursPropJU' 'HoursPropMA'};
    [pp,~]=size(meantab365);
    meantab365.Season = zeros(pp,1);
    meantab365.month = month(meantab365.Day);
    %Winter starts on January 1st
    summeridxD = (meantab365.month == 7  | meantab365.month == 8 | meantab365.month == 9);
    fallidxD = (meantab365.month == 10  | meantab365.month == 11 | meantab365.month == 12);
    winteridxD = (meantab365.month == 1  | meantab365.month == 2 | meantab365.month == 3);
    springidxD = (meantab365.month == 4  | meantab365.month == 5 | meantab365.month == 6);
    %adds the season according to the month the data was collected
    meantab365.Season(summeridxD) = 1;
    meantab365.Season(fallidxD) = 2;
    meantab365.Season(winteridxD) = 3;
    meantab365.Season(springidxD) = 4;
    writetable(meantab365, [saveDir,'\',siteabrev,'_365GroupedMean.csv']); %table with the mean for each day of the year
else
    binPresence.day = categorical(binPresence.day);
    %mean for females
    [mean, sem, std, var, range] = grpstats(binPresence.FeHoursProp, binPresence.day, {'mean','sem','std','var','range'}); %takes the mean of each day of the year
    meantable = array2table(mean);
    semtable = array2table(sem);
    stdtable = array2table(std);
    vartable = array2table(var);
    rangetable = array2table(range);
    newcol_mean = (1:length(mean))';
    meanarrayFE365 = [newcol_mean mean sem std var range];
    meantabFE365 = array2table(meanarrayFE365);
    meantabFE365.Properties.VariableNames = {'Day' 'HoursPropFE' 'SEM' 'Std' 'Var' 'Range'};
    %mean for juveniles
    [mean, sem, std, var, range] = grpstats(binPresence.JuHoursProp, binPresence.day, {'mean','sem','std','var','range'}); %takes the mean of each day of the year
    meantable = array2table(mean);
    semtable = array2table(sem);
    stdtable = array2table(std);
    vartable = array2table(var);
    rangetable = array2table(range);
    newcol_mean = (1:length(mean))';
    meanarrayJU365 = [newcol_mean mean sem std var range];
    meantabJU365 = array2table(meanarrayJU365);
    meantabJU365.Properties.VariableNames = {'Day' 'HoursPropJU' 'SEM' 'Std' 'Var' 'Range'};
    %mean for males
    [mean, sem, std, var, range] = grpstats(binPresence.MaHoursProp, binPresence.day, {'mean','sem','std','var','range'}); %takes the mean of each day of the year
    meantable = array2table(mean);
    semtable = array2table(sem);
    stdtable = array2table(std);
    vartable = array2table(var);
    rangetable = array2table(range);
    newcol_mean = (1:length(mean))';
    meanarrayMA365 = [newcol_mean mean sem std var range];
    meantabMA365 = array2table(meanarrayMA365);
    meantabMA365.Properties.VariableNames = {'Day' 'HoursPropMA' 'SEM' 'Std' 'Var' 'Range'};    

[pp,~]=size(meantabFE365);
meantabFE365.Season = zeros(pp,1);
meantabFE365.month = month(meantabFE365.Day);

[pp,~]=size(meantabJU365);
meantabJU365.Season = zeros(pp,1);
meantabJU365.month = month(meantabJU365.Day);

[pp,~]=size(meantabMA365);
meantabMA365.Season = zeros(pp,1);
meantabMA365.month = month(meantabMA365.Day);

%Winter starts on January 1st
summeridxD = (meantabFE365.month == 7  | meantabFE365.month == 8 | meantabFE365.month == 9);
fallidxD = (meantabFE365.month == 10  | meantabFE365.month == 11 | meantabFE365.month == 12);
winteridxD = (meantabFE365.month == 1  | meantabFE365.month == 2 | meantabFE365.month == 3);
springidxD = (meantabFE365.month == 4  | meantabFE365.month == 5 | meantabFE365.month == 6);

%adds the season according to the month the data was collected
meantabFE365.Season(summeridxD) = 1;
meantabFE365.Season(fallidxD) = 2;
meantabFE365.Season(winteridxD) = 3;
meantabFE365.Season(springidxD) = 4;

%Winter starts on January 1st
summeridxD = (meantabJU365.month == 7  | meantabJU365.month == 8 | meantabJU365.month == 9);
fallidxD = (meantabJU365.month == 10  | meantabJU365.month == 11 | meantabJU365.month == 12);
winteridxD = (meantabJU365.month == 1  | meantabJU365.month == 2 | meantabJU365.month == 3);
springidxD = (meantabJU365.month == 4  | meantabJU365.month == 5 | meantabJU365.month == 6);

%adds the season according to the month the data was collected
meantabJU365.Season(summeridxD) = 1;
meantabJU365.Season(fallidxD) = 2;
meantabJU365.Season(winteridxD) = 3;
meantabJU365.Season(springidxD) = 4;

%Winter starts on January 1st
summeridxD = (meantabMA365.month == 7  | meantabMA365.month == 8 | meantabMA365.month == 9);
fallidxD = (meantabMA365.month == 10  | meantabMA365.month == 11 | meantabMA365.month == 12);
winteridxD = (meantabMA365.month == 1  | meantabMA365.month == 2 | meantabMA365.month == 3);
springidxD = (meantabMA365.month == 4  | meantabMA365.month == 5 | meantabMA365.month == 6);

%adds the season according to the month the data was collected
meantabMA365.Season(summeridxD) = 1;
meantabMA365.Season(fallidxD) = 2;
meantabMA365.Season(winteridxD) = 3;
meantabMA365.Season(springidxD) = 4;

writetable(meantabFE365, [saveDir,'\',siteabrev,'_365GroupedMeanFemale.csv']); %table with the mean for each day of the year
writetable(meantabJU365, [saveDir,'\',siteabrev,'_365GroupedMeanJuvenile.csv']); %table with the mean for each day of the year
writetable(meantabMA365, [saveDir,'\',siteabrev,'_365GroupedMeanMale.csv']); %table with the mean for each day of the year
end
%% Integral Time Scale Calculation 
%continuous data
binPresence.FeHoursProp(isnan(binPresence.FeHoursProp)) = 0;
ts = binPresence.FeHoursProp;
its_cont = IntegralTimeScaleCalc(ts);
binPresence.JuHoursProp(isnan(binPresence.JuHoursProp)) = 0;
ts = binPresence.JuHoursProp;
its_cont = IntegralTimeScaleCalc(ts);
binPresence.MaHoursProp(isnan(binPresence.MaHoursProp)) = 0;
ts = binPresence.MaHoursProp;
its_cont = IntegralTimeScaleCalc(ts);
%Grouped Data
if exist('meantab365','var')
    meantab365.HoursPropFE(isnan(meantab365.HoursPropFE)) = 0; 
    ts = meantab365.HoursPropFE;
    its_cont = IntegralTimeScaleCalc(ts);
    meantab365.HoursPropJU(isnan(meantab365.HoursPropJU)) = 0; 
    ts = meantab365.HoursPropJU;
    its_cont = IntegralTimeScaleCalc(ts);
    meantab365.HoursPropMA(isnan(meantab365.HoursPropMA)) = 0; 
    ts = meantab365.HoursPropMA;
    its_cont = IntegralTimeScaleCalc(ts);
else
    meantabFE365.HoursPropFE(isnan(meantabFE365.HoursPropFE)) = 0; 
    ts = meantabFE365.HoursPropFE;
    its_cont = IntegralTimeScaleCalc(ts);
    meantabJU365.HoursPropJU(isnan(meantabJU365.HoursPropJU)) = 0; 
    ts = meantabJU365.HoursPropJU;
    its_cont = IntegralTimeScaleCalc(ts);
    meantabMA365.HoursPropMA(isnan(meantabMA365.HoursPropMA)) = 0; 
    ts = meantabMA365.HoursPropMA;
    its_cont = IntegralTimeScaleCalc(ts);
end
%% Save workspace variable
save([saveDir,'\',siteabrev,'_workspaceStep3.mat']);