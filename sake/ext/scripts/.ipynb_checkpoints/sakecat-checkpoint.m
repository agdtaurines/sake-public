function sakecat(t1file)
% ~~~ SAKE ~~~ 
%   Running CAT12 T1 VBM
fprintf('~~~ Running CAT12 for SAKE ~~~ \n');
fprintf('Written by Anastasia Gailly de Taurines \n')
fprintf('============================================= \n');
fprintf('T1 file: %s \n', t1file);

spmpath = '/rds/general/user/afg21/home/Playground/PhD/sake/ext/spm12';

fprintf('Adding SPM path: %s \n', spmpath);
addpath(spmpath)

spm('defaults', 'PET');
spm_jobman('initcfg');

matlabbatch = {};

%Pre-processing
matlabbatch{1}.spm.tools.cat.estwrite.data = {['', t1file,',1'] };
matlabbatch{1}.spm.tools.cat.estwrite.data_wmh = {''};
matlabbatch{1}.spm.tools.cat.estwrite.nproc = 0;
matlabbatch{1}.spm.tools.cat.estwrite.useprior = '';
matlabbatch{1}.spm.tools.cat.estwrite.opts.tpm = {[spmpath, '/tpm/TPM.nii']};
matlabbatch{1}.spm.tools.cat.estwrite.opts.affreg = 'mni';
matlabbatch{1}.spm.tools.cat.estwrite.opts.biasacc = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.restypes.optimal = [1 0.3];
matlabbatch{1}.spm.tools.cat.estwrite.extopts.setCOM = 1;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.APP = 1070;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.affmod = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.LASstr = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.LASmyostr = 0;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.gcutstr = 2;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.WMHC = 2;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.shooting.shootingtpm = {[spmpath, '/toolbox/cat12/templates_MNI152NLin2009cAsym/Template_0_GS.nii']};
matlabbatch{1}.spm.tools.cat.estwrite.extopts.registration.shooting.regstr = 0.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.vox = 1.5;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.bb = 12;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.SRP = 22;
matlabbatch{1}.spm.tools.cat.estwrite.extopts.ignoreErrors = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.BIDS.BIDSno = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.surface = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.surf_measures = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.ROImenu.noROI = struct([]);
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.mod = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.GM.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.mod = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.WM.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.mod = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.CSF.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.ct.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.ct.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.ct.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.pp.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.pp.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.pp.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.mod = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.WMH.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.SL.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.SL.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.SL.mod = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.SL.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.mod = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.TPMC.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.atlas.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.native = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.label.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.labelnative = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.bias.warped = 1;
matlabbatch{1}.spm.tools.cat.estwrite.output.las.native = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.las.warped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.las.dartel = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.jacobianwarped = 0;
matlabbatch{1}.spm.tools.cat.estwrite.output.warps = [1 1];
matlabbatch{1}.spm.tools.cat.estwrite.output.rmat = 0;

%Whole brain volume estimations
[ outdir ] = fileparts(t1file);

matlabbatch{2}.spm.tools.cat.tools.calcvol.data_xml(1) = cfg_dep('CAT12: Segmentation: CAT Report', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','catxml', '()',{':'}));
matlabbatch{2}.spm.tools.cat.tools.calcvol.calcvol_TIV = 0;
matlabbatch{2}.spm.tools.cat.tools.calcvol.calcvol_savenames = 1;
matlabbatch{2}.spm.tools.cat.tools.calcvol.calcvol_name = fullfile(outdir,'CATvols.txt');

%Spatial smoothing
matlabbatch{3}.spm.spatial.smooth.data(1) = cfg_dep('CAT12: Segmentation: mwp1 Image', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{1}, '.','mwp', '()',{':'}));
matlabbatch{3}.spm.spatial.smooth.data(2) = cfg_dep('CAT12: Segmentation: mwp2 Image', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','tiss', '()',{2}, '.','mwp', '()',{':'}));
matlabbatch{3}.spm.spatial.smooth.fwhm = [6 6 6];
matlabbatch{3}.spm.spatial.smooth.dtype = 0;
matlabbatch{3}.spm.spatial.smooth.im = 0;
matlabbatch{3}.spm.spatial.smooth.prefix = 's';

%Surface measures extraction
matlabbatch{4}.spm.tools.cat.stools.surfextract.data_surf(1) = cfg_dep('CAT12: Segmentation: Left Central Surface', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','lhcentral', '()',{':'}));
matlabbatch{4}.spm.tools.cat.stools.surfextract.area = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.gmv = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.GI = 1;
matlabbatch{4}.spm.tools.cat.stools.surfextract.SD = 2;
matlabbatch{4}.spm.tools.cat.stools.surfextract.FD = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.tGI = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.lGI = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.GIL = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.surfaces.IS = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.surfaces.OS = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.norm = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.FS_HOME = '<UNDEFINED>';
matlabbatch{4}.spm.tools.cat.stools.surfextract.nproc = 0;
matlabbatch{4}.spm.tools.cat.stools.surfextract.lazy = 0;

%Surface resampling
matlabbatch{5}.spm.tools.cat.stools.surfresamp.data_surf(1) = cfg_dep('CAT12: Segmentation: Left Thickness', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','lhthickness', '()',{':'}));
matlabbatch{5}.spm.tools.cat.stools.surfresamp.merge_hemi = 1;
matlabbatch{5}.spm.tools.cat.stools.surfresamp.mesh32k = 1;
matlabbatch{5}.spm.tools.cat.stools.surfresamp.fwhm_surf = 15;
matlabbatch{5}.spm.tools.cat.stools.surfresamp.lazy = 0;
matlabbatch{5}.spm.tools.cat.stools.surfresamp.nproc = 0;
matlabbatch{6}.spm.tools.cat.stools.surfresamp.data_surf(1) = cfg_dep('Extract additional surface parameters: Left MNI gyrification', substruct('.','val', '{}',{4}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','lPGI', '()',{':'}));
matlabbatch{6}.spm.tools.cat.stools.surfresamp.merge_hemi = 1;
matlabbatch{6}.spm.tools.cat.stools.surfresamp.mesh32k = 1;
matlabbatch{6}.spm.tools.cat.stools.surfresamp.fwhm_surf = 20;
matlabbatch{6}.spm.tools.cat.stools.surfresamp.lazy = 0;
matlabbatch{6}.spm.tools.cat.stools.surfresamp.nproc = 8;

%Surface ROI extraction
matlabbatch{7}.spm.tools.cat.stools.surf2roi.cdata = {
                                                      {
                                                      fullfile(outdir,'surf/lh.thickness.t1_reoriented')
                                                      fullfile(outdir,'surf/lh.gyrification.t1_reoriented')
                                                      fullfile(outdir,'surf/lh.sqrtdepth.t1_reoriented')
                                                      }
                                                      }';
matlabbatch{7}.spm.tools.cat.stools.surf2roi.rdata = {fullfile(spmpath, '/toolbox/cat12/atlases_surfaces/lh.aparc_DK40.freesurfer.annot')};

%And finally, to run everything:
spm_jobman('run', matlabbatch);

end