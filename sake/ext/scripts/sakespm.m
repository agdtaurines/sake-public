function sakespm(t1file)
% ~~~ SAKE ~~~ 
%   Running SPM T1 VBM
fprintf('~~~ Running SPM for SAKE ~~~ \n');
fprintf('Written by Anastasia Gailly de Taurines \n')
fprintf('============================================= \n');
fprintf('T1 file: %s \n', t1file);

extpath = '/rds/general/user/afg21/home/Playground/PhD/sake/ext';
spmpath = fullfile(extpath, '/spm12');
MNIstandard = fullfile(extpath, '/standard/MNI152_T1_1mm_brain.nii');
fprintf('MNIstandard file: %s \n', MNIstandard);

fprintf('Adding SPM path: %s \n', spmpath);
addpath(spmpath)

spm('defaults', 'PET');
spm_jobman('initcfg');

matlabbatch = {};

%File identification
matlabbatch{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.name = 'SPM_VBM';
matlabbatch{1}.cfg_basicio.file_dir.file_ops.cfg_named_file.files = {{t1file}};

%Coregistration
matlabbatch{2}.spm.spatial.coreg.estwrite.ref = {[MNIstandard, ',1']};
matlabbatch{2}.spm.spatial.coreg.estwrite.source(1) = cfg_dep('Named File Selector: Run1(1) - Files', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files', '{}',{1}));
matlabbatch{2}.spm.spatial.coreg.estwrite.other = {''};
matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
matlabbatch{2}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.interp = 4;
matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.mask = 0;
matlabbatch{2}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';

%Segmentation
matlabbatch{3}.spm.spatial.preproc.channel.vols(1) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
matlabbatch{3}.spm.spatial.preproc.channel.biasreg = 0.001;
matlabbatch{3}.spm.spatial.preproc.channel.biasfwhm = 60;
matlabbatch{3}.spm.spatial.preproc.channel.write = [0 1];
matlabbatch{3}.spm.spatial.preproc.tissue(1).tpm = {[spmpath, '/tpm/TPM.nii,1']};
matlabbatch{3}.spm.spatial.preproc.tissue(1).ngaus = 1;
matlabbatch{3}.spm.spatial.preproc.tissue(1).native = [1 0];
matlabbatch{3}.spm.spatial.preproc.tissue(1).warped = [0 1];
matlabbatch{3}.spm.spatial.preproc.tissue(2).tpm = {[spmpath, '/tpm/TPM.nii,2']};
matlabbatch{3}.spm.spatial.preproc.tissue(2).ngaus = 1;
matlabbatch{3}.spm.spatial.preproc.tissue(2).native = [1 0];
matlabbatch{3}.spm.spatial.preproc.tissue(2).warped = [0 1];
matlabbatch{3}.spm.spatial.preproc.tissue(3).tpm = {[spmpath, '/tpm/TPM.nii,3']};
matlabbatch{3}.spm.spatial.preproc.tissue(3).ngaus = 2;
matlabbatch{3}.spm.spatial.preproc.tissue(3).native = [1 0];
matlabbatch{3}.spm.spatial.preproc.tissue(3).warped = [0 1];
matlabbatch{3}.spm.spatial.preproc.tissue(4).tpm = {[spmpath, '/tpm/TPM.nii,4']};
matlabbatch{3}.spm.spatial.preproc.tissue(4).ngaus = 3;
matlabbatch{3}.spm.spatial.preproc.tissue(4).native = [1 0];
matlabbatch{3}.spm.spatial.preproc.tissue(4).warped = [0 0];
matlabbatch{3}.spm.spatial.preproc.tissue(5).tpm = {[spmpath, '/tpm/TPM.nii,5']};
matlabbatch{3}.spm.spatial.preproc.tissue(5).ngaus = 4;
matlabbatch{3}.spm.spatial.preproc.tissue(5).native = [1 0];
matlabbatch{3}.spm.spatial.preproc.tissue(5).warped = [0 0];
matlabbatch{3}.spm.spatial.preproc.tissue(6).tpm = {[spmpath, '/tpm/TPM.nii,6']};
matlabbatch{3}.spm.spatial.preproc.tissue(6).ngaus = 2;
matlabbatch{3}.spm.spatial.preproc.tissue(6).native = [0 0];
matlabbatch{3}.spm.spatial.preproc.tissue(6).warped = [0 0];
matlabbatch{3}.spm.spatial.preproc.warp.mrf = 1;
matlabbatch{3}.spm.spatial.preproc.warp.cleanup = 1;
matlabbatch{3}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
matlabbatch{3}.spm.spatial.preproc.warp.affreg = 'mni';
matlabbatch{3}.spm.spatial.preproc.warp.fwhm = 0;
matlabbatch{3}.spm.spatial.preproc.warp.samp = 3;
matlabbatch{3}.spm.spatial.preproc.warp.write = [1 1];
matlabbatch{3}.spm.spatial.preproc.warp.vox = NaN;
matlabbatch{3}.spm.spatial.preproc.warp.bb = [NaN NaN NaN
                                              NaN NaN NaN];

%Normalisation
matlabbatch{4}.spm.spatial.normalise.write.subj.def(1) = cfg_dep('Segment: Forward Deformations', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','fordef', '()',{':'}));
matlabbatch{4}.spm.spatial.normalise.write.subj.resample(1) = cfg_dep('Coregister: Estimate & Reslice: Resliced Images', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rfiles'));
matlabbatch{4}.spm.spatial.normalise.write.subj.resample(2) = cfg_dep('Segment: mwc1 Images', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','mwc', '()',{':'}));
matlabbatch{4}.spm.spatial.normalise.write.subj.resample(3) = cfg_dep('Segment: mwc2 Images', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','mwc', '()',{':'}));
matlabbatch{4}.spm.spatial.normalise.write.subj.resample(4) = cfg_dep('Segment: mwc3 Images', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{3}, '.','mwc', '()',{':'}));
matlabbatch{4}.spm.spatial.normalise.write.woptions.bb = [-78 -112 -70
                                                          78 76 85];
matlabbatch{4}.spm.spatial.normalise.write.woptions.vox = [1 1 1];
matlabbatch{4}.spm.spatial.normalise.write.woptions.interp = 4;
matlabbatch{4}.spm.spatial.normalise.write.woptions.prefix = 'w';

%Whole brain volume estimations
[ outdir ] = fileparts(t1file);

matlabbatch{5}.spm.util.tvol.matfiles(1) = cfg_dep('Segment: Seg Params', substruct('.','val', '{}',{3}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','param', '()',{':'}));
matlabbatch{5}.spm.util.tvol.tmax = 3;
matlabbatch{5}.spm.util.tvol.mask = {[spmpath, '/tpm/mask_ICV.nii,1']};
matlabbatch{5}.spm.util.tvol.outf = fullfile(outdir,'SPMvols.txt');


%And finally, to run everything:
spm_jobman('run', matlabbatch);

end