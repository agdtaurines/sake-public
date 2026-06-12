function spmwbvols(spmvols_path)
% ~~~ SAKE WB volume csv generator ~~~ 
%Outputs SPM WB values
%Input: SPMvols.txt file path

t=readtable(spmvols_path);
[ outputdir ] = fileparts(spmvols_path);

%Summing GM, W and CSF volumes according to SPM tutorial
eTIV=sum(t{1,2:end});

%Producing new SPMvols.txt file
t2=table(eTIV,t.Volume1,t.Volume2,t.Volume3,'VariableNames',["eTIV","GMV","WMV","CSF"]);
writetable(t2,fullfile(outputdir,"SPMvols.txt"))

end