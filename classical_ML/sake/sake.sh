#!/bin/bash
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# SAKE (Swiss Army KnifE) 
# by Anastasia Gailly de Taurines
# version 2.0
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Print out usage instructions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sakeusage() {
cat <<EOF
SAKE (Swiss Army KnifE) v.0.1

Usage:
        sake.sh --t1 <t1> --outputdir <outputdir> [options] [pipelines]
    OR  sake.sh -i <t1> -o <outputdir> [options] [pipelines]
           to run sake with a t1 and a specified output destination and one or more additional arguments
        sake.sh [options]
           to run sake with one or more arguments

Optional pipeline arguments (after previous arguments): 
     -all,--all               run sake with all pipelines
     -spm,--spm				  run spm pipeline
     -cat,--cat12			  run cat12 pipeline
     -fsl,--fsl               run fsl pipeline
     -fs,--freesurfer         run freesurfer pipeline
     -ss,--synthseg           run synthseg pipeline
     -fts,--fastsurfer        run fastsurfer pipeline
     
EOF
exit 1
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Supporting functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Wrap the specified ($1) argument as a Matlab command and execute it, limiting number of Matlab threads to $2 
# NB: requires matlab available on the bash path (version not specified)
sakewrapmatlab() {
wd=`dirname "$(readlink -f "$0")"`;
cmd="matlab -nodisplay -nosplash -nodesktop -r \"addpath('$wd'); maxNumCompThreads($2);$1;exit\"";
sakeecho "Running Matlab with command: ${cmd}"
eval ${cmd}
}
    
# Echo the argument/s (to stdout) depending on whether SAKEVERBOSE is set
sakeecho() { # used to echo if verbose flag set
	if [[ "${SAKEVERBOSE}" == "true" ]]; then
    echo "~~SAKE~~: ${*}";
	fi
}

# Echo the argument/s to the stderr and exit with an error code (1)
sakeerror() { 
    echo >&2 "~SAKE+ *ERROR*: ${*}";
	exit 1;
}

# Set up - environment variable defaults, modules, paths, etc.
sakesetup() {
    # Set environment variables that have defaults
    if [[ -z "${SAKEVERBOSE}" ]]; then
		export SAKEVERBOSE="true"
	fi
    
    if [[ -z "${SAKEDIR}" ]]; then
        export SAKEDIR="$(dirname -- "$(readlink -f "${BASH_SOURCE}")")"
    fi
    
    if [[ -z "${SAKENEWPERMISSIONS}" ]]; then
        export SAKENEWPERMISSIONS="774"
    fi

    if [[ -z "${FSLOUTPUTTYPE}" ]]; then
        export FSLOUTPUTTYPE=NIFTI;
    fi
    
    sakeecho "------------------------------------------------------"
    sakeecho "-------------------- Running SAKE --------------------"
    sakeecho "         Made by Anastasia Gailly de Taurines         "
    sakeecho "                       ~ V2.0 ~                       "
    sakeecho "------------------------------------------------------"
    sakeecho "------------------------------------------------------"

    sakeecho "SAKEDIR= ${SAKEDIR}"
    
    # *** LOAD NECESSARY HPC MODULES ***
	module load MATLAB/2023b > /dev/null 2>&1
	module load FSL/6.0.5.1-foss-2021a > /dev/null 2>&1
    
    export FREESURFER_HOME="/rds/general/user/afg21/home/RCS_help/freesurfer"
    source $FREESURFER_HOME/SetUpFreeSurfer.sh

	FSLMNI1MM="$FSLDIR/data/standard/MNI152_T1_1mm_brain"
}

# Check a file argument is specified and exists and quit otherwise
sakecheckorquit() {
# Check input exists
	if [[ -n "$1" && ! -f "$1" ]]; then
    	sakeerror "Input $1 does not exist!"
	fi
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Main functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Check for the case of no arguments specified, i.e., print usage and quit
if [  $# -lt 1 ]; then
  sakeusage;
  exit 1
fi
 
# Set up
sakesetup;

# Set up paths, variables and run other non-pipeline arguments
while [[ $# -gt 0 ]]; do
 case $1 in
     -i|--t1)
        t1="$2";
        shift 2
        sakeecho "T1PATH= ${t1}"
        
        sakecheckorquit ${t1}
        
        if [[ $t1 == *.nii.gz ]]; then 
        	sub=`basename ${t1} .nii.gz`
        elif [[ $t1 == *.nii ]]; then
        	sub=`basename ${t1} .nii`
        else
        	sakeerror "T1 file extension not .nii or .nii.gz!"
        fi
        
        sakeecho "SUBJECT= ${sub}"
        ;;
        
        
    -o|--outputdir)
        outputdir="$2"
        shift 2
        sakeecho "OUTPUTDIR= ${outputdir}"

        # If output directory doesn't exist, try to make it:
        if [ ! -d "${outputdir}" ]; then
            sakeecho "Making outputdir..."
            mkdir -p -m ${SAKENEWPERMISSIONS} ${outputdir}
        fi

        if [ ! -d "${outputdir}" ]; then # check once more to see if it still fails, exit if so
            sakeerror "Output directory does not exist or could not be made : ${outputdir}"
        fi
        
        if [ ! -f ${outputdir}/t1_reoriented.nii ]; then
            sakeecho "Reorienting T1 to standard..."
            fslreorient2std ${t1} ${outputdir}/t1_reoriented.nii.gz
            gzip -dk ${outputdir}/t1_reoriented.nii.gz
            sakeecho "Reoriented T1!"
        else
        	sakeecho "T1 already reoriented to standard!"
        fi
        sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "
        ;;
           
        
        
# Run the T1 pre-processing pipelines
    -all|--all)
       shift 1
       sakeecho "Re-running SAKE with all pipelines..."
       ./sake.sh --t1 ${t1} --outputdir ${outputdir} --spm --cat12 --fsl --freesurfer --synthseg --fastsurfer
       ;;
       

    -fsl|--fsl)
       shift 1
       sakeecho "                    ***** FSL *****                   "
       
       if [[ ! -f ${outputdir}/fsl/fsl.anat/T1_fast_pve_1.nii.gz ]]; then
       		sakeecho "Running FSL pre-processing..."
       		
       		if [[ -d ${outputdir}/fsl ]]; then
       			rm -r ${outputdir}/fsl
       		fi
       		
       		mkdir ${outputdir}/fsl
       		cp ${outputdir}/t1_reoriented.nii ${outputdir}/fsl
       		
       		#Run pre-processing
       		fsl_anat -i ${outputdir}/fsl/t1_reoriented.nii -o ${outputdir}/fsl/fsl
       else
       		sakeecho "FSL pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/fsl/fsl.anat/T1_fast_pve_1_MNI152_1mm.nii.gz || ! -f ${outputdir}/fsl/fsl.anat/T1_fast_pve_2_MNI152_1mm.nii.gz ]]; then
       		#Register outputs to MNI152 1mm standard space  
       		sakeecho "Registering outputs to MNI152 1mm standard space..."
       		
       		if [ ! -f ${outputdir}/fsl/fsl.anat/reg_mat ]; then
       			sakeecho "Making registration matrix..."
       			flirt -usesqform -noresampblur -noresample -in ${outputdir}/fsl/fsl.anat/T1_biascorr_brain.nii.gz -ref $FSLMNI1MM -omat ${outputdir}/fsl/fsl.anat/reg_mat
       		fi
      
           	sakeecho "Registering images..."
           	for im in ${outputdir}/fsl/fsl.anat/T1_fast_pve_?.nii.gz; do               
            	name=`basename $im`
            	flirt -usesqform -noresampblur -noresample -in ${im} -ref $FSLMNI1MM -applyxfm -init ${outputdir}/fsl/fsl.anat/reg_mat -out ${outputdir}/fsl/fsl.anat/${name::-7}_MNI152_1mm
           	done
       
       else
           	sakeecho "FSL registration already complete!"
       fi
       
       if [[ ! -f ${outputdir}/fsl/fsl.anat/ROIVols.csv || ! -f ${outputdir}/fsl/fsl.anat/wb_stats.csv ]]; then
       		#Extract mean ROI c1 VBM volumes
       		sakeecho "Extracting features for FSL..."
       		ROIVOLS_PATH="${SAKEDIR}/ext/scripts"
       		$ROIVOLS_PATH/ROIVols.sh ${outputdir}/fsl/fsl.anat/T1_fast_pve_1_MNI152_1mm.nii.gz
       		
       		#Extract eTIV, GMV, WMV & CSF - this is done as described in the FSL wiki. Note that CSF estimate is not expected to be accurate using this method.
       		! > ${outputdir}/fsl/fsl.anat/wb_stats.csv
       		echo "eTIV,GMV,WMV,CSF" >> ${outputdir}/fsl/fsl.anat/wb_stats.csv
       		eTIV=$( awk -F'= ' '{print $2}' ${outputdir}/fsl/fsl.anat/T1_vols.txt | sed '1,2d' )
       		GMV=$( echo "$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_1.nii.gz -m)*$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_1.nii.gz -v | awk '{print $2}')" | bc )
       		WMV=$( echo "$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_2.nii.gz -m)*$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_2.nii.gz -v | awk '{print $2}')" | bc )
       		CSF=$( echo "$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_0.nii.gz -m)*$(fslstats ${outputdir}/fsl/fsl.anat/T1_fast_pve_0.nii.gz -v | awk '{print $2}')" | bc )
       		echo "${eTIV},${GMV},${WMV},${CSF}" >> ${outputdir}/fsl/fsl.anat/wb_stats.csv
       		
       else
           	sakeecho "FSL feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/fsl/FSL_fx.csv ]]; then
       		sakeecho "Arranging FSL features for analysis..."
            ! > ${outputdir}/fsl/FSL_fx.csv
            paste -d, \
                "${outputdir}/fsl/fsl.anat/wb_stats.csv" \
                <(cut -d, -f2- "${outputdir}/fsl/fsl.anat/ROIVols.csv") \
                > ${outputdir}/fsl/FSL_fx.csv

       else
           	sakeecho "FSL feature arrangement already complete!"
       fi
    
       sakeecho "FSL pre-processing complete!"
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "
       ;;
       
       
    -spm|--spm)
	   shift 1
       sakeecho "                    ***** SPM *****                   "
       
       if [[ ! -f ${outputdir}/spm/mwc1rt1_reoriented.nii ]]; then
       		sakeecho "Running SPM pre-processing..."
        
       		if [[ -d ${outputdir}/spm ]]; then
       			rm -r ${outputdir}/spm
       		fi
       		
       		mkdir ${outputdir}/spm
       		cp ${outputdir}/t1_reoriented.nii ${outputdir}/spm
       		
       		#Run pre-processing
       		sakewrapmatlab "cd('${SAKEDIR}/ext/scripts');sakespm('${outputdir}/spm/t1_reoriented.nii');spmwbvols('${outputdir}/spm/SPMvols.txt');" 1;
           
       else
       		sakeecho "SPM pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/spm/mwc1rt1_reoriented_MNI152_1mm.nii.gz || ! -f ${outputdir}/spm/mwc2rt1_reoriented_MNI152_1mm.nii.gz ]]; then
           	#Register outputs to MNI152 1mm standard space
           	sakeecho "Registering outputs to MNI152 1mm standard space..."
           
           	if [ ! -f ${outputdir}/spm/reg_mat ]; then
               	sakeecho "Making registration matrix..."
               	flirt -usesqform -noresampblur -noresample -in ${outputdir}/spm/mwc3rt1_reoriented.nii -ref $FSLMNI1MM -omat ${outputdir}/spm/reg_mat
           	fi
           
           	sakeecho "Registering images..."
           	for im in ${outputdir}/spm/mwc?rt1_reoriented.nii; do
               	name=`basename $im`
               	flirt -usesqform -noresampblur -noresample -in $im -ref $FSLMNI1MM -applyxfm -init ${outputdir}/spm/reg_mat -out ${outputdir}/spm/${name::-4}_MNI152_1mm
           	done
       
       else
           	sakeecho "SPM registration already complete!"
       fi
       
       if [[ ! -f ${outputdir}/spm/ROIVols.csv ]]; then
       		#Extract mean ROI c1 VBM volumes
       		sakeecho "Extracting features for SPM..."
       		ROIVOLS_PATH="${SAKEDIR}/ext/scripts"
       		$ROIVOLS_PATH/ROIVols.sh ${outputdir}/spm/mwc1rt1_reoriented_MNI152_1mm.nii.gz
       else
           	sakeecho "SPM feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/spm/SPM_fx.csv ]]; then
       		sakeecho "Arranging SPM features for analysis..."
            ! > ${outputdir}/spm/SPM_fx.csv
            paste -d, \
                "${outputdir}/spm/SPMvols.txt" \
                <(cut -d, -f2- "${outputdir}/spm/ROIVols.csv") \
                > ${outputdir}/spm/SPM_fx.csv

       else
           	sakeecho "SPM feature arrangement already complete!"
       fi    
       
       sakeecho "SPM pre-processing complete!"
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "
       ;;
       
       
    -cat|--cat12)
       shift 1
       sakeecho "                   ***** CAT12 *****                  "
       
       if [[ ! -f ${outputdir}/cat12/mri/mwp1t1_reoriented.nii || ! -f ${outputdir}/cat12/label/thickness.csv ]]; then
       		sakeecho "Running CAT12 pre-processing..."
        
       		if [[ -d ${outputdir}/cat12 ]]; then
       			rm -r ${outputdir}/cat12
       		fi
       		
       		mkdir ${outputdir}/cat12
       		cp ${outputdir}/t1_reoriented.nii ${outputdir}/cat12
       		
       		#Run pre-processing
       		sakewrapmatlab "cd('${SAKEDIR}/ext/scripts');sakecat('${outputdir}/cat12/t1_reoriented.nii');roi2csv('${outputdir}/cat12/label/catROIs_t1_reoriented.mat');" 1;
       		
       else
       		sakeecho "CAT12 pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/cat12/mri/mwp1t1_reoriented_MNI152_1mm.nii.gz ]]; then
           	#Register outputs to MNI152 1mm standard space
           	sakeecho "Registering outputs to MNI152 1mm standard space..."
           
           	if [ ! -f ${outputdir}/cat12/mri/reg_mat ]; then
            	sakeecho "Making registration matrix..."
            	flirt -usesqform -noresampblur -noresample -in ${outputdir}/cat12/mri/mwp1t1_reoriented.nii -ref $FSLMNI1MM -omat ${outputdir}/cat12/mri/reg_mat
           	fi
           
           	sakeecho "Registering images..."
           	for im in ${outputdir}/cat12/mri/mwp?t1_reoriented.nii; do               
            	name=`basename $im`
            	flirt -usesqform -noresampblur -noresample -in ${im} -ref $FSLMNI1MM -applyxfm -init ${outputdir}/cat12/mri/reg_mat -out ${outputdir}/cat12/mri/${name::-4}_MNI152_1mm
           	done
           
       else
        	sakeecho "CAT12 registration already complete!"
       fi
       
       if [[ ! -f ${outputdir}/cat12/mri/ROIVols.csv ]]; then
       		#Extract mean ROI c1 VBM volumes
       		sakeecho "Extracting features for CAT12..."
       		ROIVOLS_PATH="${SAKEDIR}/ext/scripts"
       		$ROIVOLS_PATH/ROIVols.sh ${outputdir}/cat12/mri/mwp1t1_reoriented_MNI152_1mm.nii.gz
       else
           	sakeecho "CAT12 feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/cat12/CAT12_fx.csv ]]; then
       		sakeecho "Arranging CAT12 features for analysis..."
            ! > ${outputdir}/cat12/CAT12_fx.csv
            (
              # Column names
              paste -d, \
                <(echo "eTIV,GMV,WMV,CSF") \
                <(head -1 "${outputdir}/cat12/mri/ROIVols.csv" | cut -d, -f2- | sed 's/\([^,]*\)/\1_volume/g') \
                <(head -1 "${outputdir}/cat12/label/thickness.csv" | sed 's/\([^,]*\)/\1_thickness/g') \
                <(head -1 "${outputdir}/cat12/label/gyrification.csv" | sed 's/\([^,]*\)/\1_gyrification/g') \
                <(head -1 "${outputdir}/cat12/label/sqrtdepth.csv" | sed 's/\([^,]*\)/\1_sqrtdepth/g')
              
              # Data
              paste -d, \
                <(awk '{print $2,$3,$4,$5}' "${outputdir}/cat12/CATvols.txt" | sed 's/ /,/g') \
                <(tail -n +2 "${outputdir}/cat12/mri/ROIVols.csv" | cut -d, -f2-) \
                <(tail -n +2 "${outputdir}/cat12/label/thickness.csv") \
                <(tail -n +2 "${outputdir}/cat12/label/gyrification.csv") \
                <(tail -n +2 "${outputdir}/cat12/label/sqrtdepth.csv")
            ) > "${outputdir}/cat12/CAT12_fx.csv"
            
       else
           	sakeecho "CAT12 feature arrangement already complete!"
       fi
       
       sakeecho "CAT12 pre-processing complete!"
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "
       ;;
       
       
    -fs|--freesurfer)
       shift 1
       sakeecho "            ***** FREESURFER (v7.4.0) *****           "
       
       if [[ ! -f ${outputdir}/freesurfer/stats/lh.aparc.stats || ! -f ${outputdir}/freesurfer/stats/rh.aparc.stats ]]; then
       		sakeecho "Running FREESURFER pre-processing..."
        
       		if [[ -d ${outputdir}/freesurfer ]]; then
       			rm -r ${outputdir}/freesurfer
       		fi
       		
       		#Run pre-processing
       		export JOB_NUM=$(echo ${PBS_JOBID} | cut -f 1 -d '.' | cut -f 1 -d '[')
       		export NEW_TMPDIR="${EPHEMERAL}/${JOB_NUM}.${PBS_ARRAY_INDEX}"
       		mkdir -p ${NEW_TMPDIR}
       		export TMPDIR=${NEW_TMPDIR}
       		export SUBJECTS_DIR=${outputdir}
       		export FS_LICENSE="${SAKEDIR}/ext/license.txt"
       		
       		recon-all -s freesurfer -i ${outputdir}/t1_reoriented.nii -all
       		
       		rm -r ${NEW_TMPDIR}
       		
       else
       		sakeecho "FREESURFER pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/freesurfer/stats/ct_lh_stats.csv || ! -f ${outputdir}/freesurfer/stats/wb_stats.csv ]]; then
       		#Extract ROI volumes and cortical thickness
       		sakeecho "Extracting features for FREESURFER..."
       		aparcstats2table --subjects ${outputdir}/freesurfer --meas thickness --hemi lh --delimiter comma --tablefile ${outputdir}/freesurfer/stats/ct_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/freesurfer --meas thickness --hemi rh --delimiter comma --tablefile ${outputdir}/freesurfer/stats/ct_rh_stats.csv
       		aparcstats2table --subjects ${outputdir}/freesurfer --meas volume --hemi lh --delimiter comma --tablefile ${outputdir}/freesurfer/stats/vol_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/freesurfer --meas volume --hemi rh --delimiter comma --tablefile ${outputdir}/freesurfer/stats/vol_rh_stats.csv
            asegstats2table --subjects ${outputdir}/freesurfer --meas volume --delimiter comma --tablefile ${outputdir}/freesurfer/stats/aseg_stats.csv
       		
       		! > ${outputdir}/freesurfer/stats/wb_stats.csv
       		echo "eTIV,GMV,WMV,CSF" >> ${outputdir}/freesurfer/stats/wb_stats.csv
       		bvspath="${outputdir}/freesurfer/stats/brainvol.stats"
       		asegpath="${outputdir}/freesurfer/stats/aseg.stats"
       		eTIV=$( grep -w "EstimatedTotalIntraCranialVol" ${asegpath} | awk -F, '{print $4}' )
       		GMV=$( grep -w "TotalGrayVol" ${bvspath} | awk -F, '{print $4}' )
       		WMV=$( grep -w "CerebralWhiteMatterVol" ${bvspath} | awk -F, '{print $4}' )
       		CSF=$( grep -w "VentricleChoroidVol" ${bvspath} | awk -F, '{print $4}' )
       		printf "%s,%s,%s,%s\n" $eTIV $GMV $WMV $CSF >> ${outputdir}/freesurfer/stats/wb_stats.csv
       		
       else
           	sakeecho "FREESURFER feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/freesurfer/FS_fx.csv ]]; then
       		sakeecho "Arranging FREESURFER features for analysis..."
            ! > ${outputdir}/freesurfer/FS_fx.csv
            paste -d, \
                "${outputdir}/freesurfer/stats/wb_stats.csv" \
                <(cut -d, -f2-35 "${outputdir}/freesurfer/stats/ct_lh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/freesurfer/stats/ct_rh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/freesurfer/stats/vol_lh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/freesurfer/stats/vol_rh_stats.csv") \
                <(cut -d, -f2-14,16-64 "${outputdir}/freesurfer/stats/aseg_stats.csv") \
                > "${outputdir}/freesurfer/FS_fx.csv"
    
       else
           	sakeecho "FREESURFER feature arrangement already complete!"
       fi
    
       sakeecho "FREESURFER pre-processing complete!"  
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "     
       ;;
       
       
    -ss|--synthseg)
       shift 1
       sakeecho "                 ***** SYNTHSEG *****                 "
       
       if [[ ! -f ${outputdir}/synthseg/stats/lh.aparc.stats || ! -f ${outputdir}/synthseg/stats/rh.aparc.stats ]]; then
       		sakeecho "Running SYNTHSEG pre-processing..."
        
       		if [[ -d ${outputdir}/synthseg ]]; then
       			rm -r ${outputdir}/synthseg
       		fi
       		
       		#Run pre-processing
       		export JOB_NUM=$(echo ${PBS_JOBID} | cut -f 1 -d '.' | cut -f 1 -d '[')
       		export NEW_TMPDIR="${EPHEMERAL}/${JOB_NUM}.${PBS_ARRAY_INDEX}"
       		mkdir -p ${NEW_TMPDIR}
       		export TMPDIR=${NEW_TMPDIR}
       		export SUBJECTS_DIR=${outputdir}
       		export FS_LICENSE="${SAKEDIR}/ext/license.txt"
       		
       		${FREESURFER_HOME}/bin/recon-all-clinical.sh ${outputdir}/t1_reoriented.nii synthseg 1
       		
       		rm -r ${NEW_TMPDIR}
       		
       else
       		sakeecho "SYNTHSEG pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/synthseg/stats/ct_lh_stats.csv || ! -f ${outputdir}/synthseg/stats/wb_stats.csv ]]; then
       		#Extract ROI volumes and cortical thickness
       		sakeecho "Extracting features for SYNTHSEG..."
       		aparcstats2table --subjects ${outputdir}/synthseg --meas thickness --hemi lh --delimiter comma --tablefile ${outputdir}/synthseg/stats/ct_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/synthseg --meas thickness --hemi rh --delimiter comma --tablefile ${outputdir}/synthseg/stats/ct_rh_stats.csv
       		aparcstats2table --subjects ${outputdir}/synthseg --meas volume --hemi lh --delimiter comma --tablefile ${outputdir}/synthseg/stats/vol_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/synthseg --meas volume --hemi rh --delimiter comma --tablefile ${outputdir}/synthseg/stats/vol_rh_stats.csv
            #no ASEG file
       		
       		! > ${outputdir}/freesurfer/stats/wb_stats.csv
       		echo "eTIV,GMV,WMV,CSF" >> ${outputdir}/synthseg/stats/wb_stats.csv
       		bvspath="${outputdir}/synthseg/stats/brainvol.stats"
       		ssvolpath="${outputdir}/synthseg/stats/synthseg.vol.csv"
       		eTIV=$( awk -F, '{print $2}' ${ssvolpath} | sed '1d' )
       		GMV=$( grep -w "TotalGrayVol" ${bvspath} | awk -F, '{print $4}' )
       		WMV=$( grep -w "CerebralWhiteMatterVol" ${bvspath} | awk -F, '{print $4}' )
       		CSF=$( grep -w "VentricleChoroidVol" ${bvspath} | awk -F, '{print $4}' )
       		printf "%s,%s,%s,%s\n" $eTIV $GMV $WMV $CSF >> ${outputdir}/synthseg/stats/wb_stats.csv
       		
       else
           	sakeecho "SYNTHSEG feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/synthseg/SS_fx.csv ]]; then
       		sakeecho "Arranging SYNTHSEG features for analysis..."
            ! > ${outputdir}/synthseg/SS_fx.csv
            paste -d, \
                "${outputdir}/synthseg/stats/wb_stats.csv" \
                <(cut -d, -f2-35 "${outputdir}/synthseg/stats/ct_lh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/synthseg/stats/ct_rh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/synthseg/stats/vol_lh_stats.csv") \
                <(cut -d, -f2-35 "${outputdir}/synthseg/stats/vol_rh_stats.csv") \
                <(cut -d, -f3-17,19-34 "${outputdir}/synthseg/stats/synthseg.vol.csv" | sed '1s/ /-/g') \
                > "${outputdir}/synthseg/SS_fx.csv"

       else
           	sakeecho "SYNTHSEG feature arrangement already complete!"
       fi

       sakeecho "SYNTHSEG pre-processing complete!"
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "             
       ;;
       
       
    -fts|--fastsurfer)
       shift 1
       sakeecho "                ***** FASTSURFER *****                "
       
       if [[ ! -f ${outputdir}/fastsurfer/stats/lh.aparc.DKTatlas.mapped.stats || ! -f ${outputdir}/fastsurfer/stats/rh.aparc.DKTatlas.mapped.stats ]]; then
       		sakeecho "Running FASTSURFER pre-processing..."
        
       		if [[ -d ${outputdir}/fastsurfer ]]; then
       			rm -r ${outputdir}/fastsurfer
       		fi
       		
       		#Run pre-processing
            singularity exec --no-mount home,cwd -e \
                 -B ${outputdir}:/data \
                 -B ${outputdir}:/output \
                 -B ${SAKEDIR}/ext:/fs \
                  ${SAKEDIR}/ext/fastsurfer-cpu-latest.sif \
                  /fastsurfer/run_fastsurfer.sh \
                  --fs_license /fs/license.txt \
                  --t1 /data/t1_reoriented.nii.gz \
                  --sid fastsurfer --sd /output \
                  --no_cereb

       else
       		sakeecho "FASTSURFER pre-processing already complete!"
       fi
       
       if [[ ! -f ${outputdir}/fastsurfer/stats/lh.aparc.DKTatlas.mapped.stats || ! -f ${outputdir}/fastsurfer/stats/rh.aparc.DKTatlas.mapped.stats ]]; then
       		sakeecho "FASTSURFER pre-processing failed!"       
       
       elif [[ -f ${outputdir}/fastsurfer/stats/lh.aparc.DKTatlas.mapped.stats && ! -f ${outputdir}/fastsurfer/stats/ct_lh_stats.csv ]]; then
       		#Extract ROI volumes and cortical thickness
       		sakeecho "Extracting features for FASTSURFER..."
       		aparcstats2table --subjects ${outputdir}/fastsurfer --parc aparc.DKTatlas.mapped --meas thickness --hemi lh --delimiter comma --tablefile ${outputdir}/fastsurfer/stats/ct_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/fastsurfer --parc aparc.DKTatlas.mapped --meas thickness --hemi rh --delimiter comma --tablefile ${outputdir}/fastsurfer/stats/ct_rh_stats.csv
       		aparcstats2table --subjects ${outputdir}/fastsurfer --parc aparc.DKTatlas.mapped --meas volume --hemi lh --delimiter comma --tablefile ${outputdir}/fastsurfer/stats/vol_lh_stats.csv
       		aparcstats2table --subjects ${outputdir}/fastsurfer --parc aparc.DKTatlas.mapped --meas volume --hemi rh --delimiter comma --tablefile ${outputdir}/fastsurfer/stats/vol_rh_stats.csv
            asegstats2table --subjects ${outputdir}/fastsurfer --meas volume --delimiter comma --tablefile ${outputdir}/fastsurfer/stats/aseg_stats.csv
       		
       		! > ${outputdir}/fastsurfer/stats/wb_stats.csv
       		echo "eTIV,GMV,WMV,CSF" >> ${outputdir}/fastsurfer/stats/wb_stats.csv
       		bvspath="${outputdir}/fastsurfer/stats/brainvol.stats"
       		asegpath="${outputdir}/fastsurfer/stats/aseg.stats"
       		eTIV=$( grep -w "EstimatedTotalIntraCranialVol" ${asegpath} | awk -F, '{print $4}' )
       		GMV=$( grep -w "TotalGrayVol" ${bvspath} | awk -F, '{print $4}' )
       		WMV=$( grep -w "CerebralWhiteMatterVol" ${bvspath} | awk -F, '{print $4}' )
       		CSF=$( grep -w "VentricleChoroidVol" ${bvspath} | awk -F, '{print $4}' )
       		printf "%s,%s,%s,%s\n" $eTIV $GMV $WMV $CSF >> ${outputdir}/fastsurfer/stats/wb_stats.csv
       		
       else
           	sakeecho "FASTSURFER feature extraction already complete!"
       fi
       
       if [[ ! -f ${outputdir}/fastsurfer/stats/ct_lh_stats.csv || ! -f ${outputdir}/fastsurfer/stats/wb_stats.csv ]]; then
       		sakeecho "FASTSURFER feature extraction failed!"       
       
       elif [[ -f ${outputdir}/fastsurfer/stats/ct_lh_stats.csv && ! -f ${outputdir}/fastsurfer/FTS_fx.csv ]]; then
       		sakeecho "Arranging FASTSURFER features for analysis..."
            ! > ${outputdir}/fastsurfer/FTS_fx.csv
            paste -d, \
                "${outputdir}/fastsurfer/stats/wb_stats.csv" \
                <(cut -d, -f2-32 "${outputdir}/fastsurfer/stats/ct_lh_stats.csv") \
                <(cut -d, -f2-32 "${outputdir}/fastsurfer/stats/ct_rh_stats.csv") \
                <(cut -d, -f2-32 "${outputdir}/fastsurfer/stats/vol_lh_stats.csv") \
                <(cut -d, -f2-32 "${outputdir}/fastsurfer/stats/vol_rh_stats.csv") \
                <(cut -d, -f2-14,16-64 "${outputdir}/fastsurfer/stats/aseg_stats.csv") \
                > "${outputdir}/fastsurfer/FTS_fx.csv"
        
       else
           	sakeecho "FASTSURFER feature arrangement already complete!"
       fi
       
       sakeecho "FASTSURFER pre-processing complete!"
       sakeecho "- - - - - - - - - - - - - - - - - - - - - - - - - - - "         
       ;;

    *)
       sakeerror "Unknown argument: $1"
       ;;
  esac
done

### Concatenate all feature matrices produced by the different pipelines
fsl="${outputdir}/fsl/FSL_fx.csv"
spm="${outputdir}/spm/SPM_fx.csv"
cat12="${outputdir}/cat12/CAT12_fx.csv"
fs="${outputdir}/freesurfer/FS_fx.csv"
ss="${outputdir}/synthseg/SS_fx.csv"
fts="${outputdir}/fastsurfer/FTS_fx.csv"

if [[ -f $fsl && -f $spm && -f $cat12 && -f $fs && -f $ss && -f $fts ]]; then
	if [[ ! -f ${outputdir}/full_fx.csv ]]; then
		sakeecho "Concatenating all feature matrices..."
		paste -d ',' \
            <(printf "sub\n%s\n" "$sub") \
            "$fsl" "$spm" "$cat12" "$fs" "$ss" "$fts" \
            > ${outputdir}/full_fx.csv
	else
		sakeecho "Full feature matrix already exists!"
	fi
else
	sakeerror "Cannot make full feature matrix: missing feature matrix from a pre-processing pipeline!"
fi

sakeecho "------------------------------------------------------"
sakeecho "------------------------------------------------------"
sakeecho "              ~~~~~ SAKE complete! ~~~~~              "
sakeecho "------------------------------------------------------"
sakeecho "------------------------------------------------------"
