function roi2csv(roimatfile)
% ~~~ SAKE ROI matrix to csv ~~~ 
%Converts CAT12 ROI surface data to csv files
%Input: catROIs_*.mat file path

load(roimatfile)
[ outdir ] = fileparts(roimatfile);

%Extract data, convert to table and save as individual csv files
rois=string(S.aparc_DK40.names);

g=S.aparc_DK40.data.gyrification';
g=array2table(g,'VariableNames',rois);
writetable(g,fullfile(outdir,"gyrification.csv"))

d=S.aparc_DK40.data.sqrtdepth';
d=array2table(d,'VariableNames',rois);
writetable(d,fullfile(outdir,"sqrtdepth.csv"))

t=S.aparc_DK40.data.thickness';
t=array2table(t,'VariableNames',rois);
writetable(t,fullfile(outdir,"thickness.csv"))

end