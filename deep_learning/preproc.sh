#!/bin/bash

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
### This script pre-processes T1 MRIs following the Biobank protocol ###
# Usage: ./preproc.sh <T1_path> <outputdir>

#Made by Anastasia GdeT - Sep 2025
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

echo "---------------------------------------"
echo "---------------------------------------"
echo "~~~~~~~ Running pre-processing! ~~~~~~~"
echo "---------------------------------------"
echo "---------------------------------------"

echo "Setting up directories..."

export FSLDIR=/home/jovyan/anastasiagdtimaging/ext/fsl
source ${FSLDIR}/etc/fslconf/fsl.sh
export PATH=${FSLDIR}/bin:$PATH

fsldir="$FSLDIR/bin"
ref="$FSLDIR/data/standard/MNI152_T1_1mm_brain.nii.gz" #/home/jovyan/anastasiagdtimaging/ext/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz

input=$1
outdir=$2
fname=$(basename ${input})
imname=$(basename "$fname" .nii.gz)
wd=${outdir}/${imname}

echo "Input = ${input}"
echo "Outputdir = ${wd}"

if [[ -f ${wd}/T1_biascorr_brain_MNI152_1mm.nii.gz && \
      -f ${wd}/T1_fast_pve_0_MNI152_1mm.nii.gz && \
      -f ${wd}/T1_fast_pve_1_MNI152_1mm.nii.gz && \
      -f ${wd}/T1_fast_pve_2_MNI152_1mm.nii.gz ]]; then
    echo "All outputs already exist!"
    exit 0
fi

if [[ ! -d ${wd} ]]; then
    mkdir -p ${wd}
fi
cp ${input} ${wd}

echo "Running fsl_anat..."
${fsldir}/fsl_anat --clobber -i ${input} -o "${wd}/fsl"

echo "Registering outputs to MNI space..."
${fsldir}/flirt -usesqform -noresampblur -noresample -in ${wd}/fsl.anat/T1_biascorr_brain.nii.gz -ref $ref -omat ${wd}/fsl.anat/reg_mat

${fsldir}/flirt -usesqform -noresampblur -noresample -in ${wd}/fsl.anat/T1_biascorr_brain.nii.gz -ref $ref -applyxfm -init ${wd}/fsl.anat/reg_mat -out ${wd}/fsl.anat/T1_biascorr_brain_MNI152_1mm
for seg in ${wd}/fsl.anat/T1_fast_pve_?.nii.gz; do
    name=$(basename "$seg" .nii.gz)
    ${fsldir}/flirt -usesqform -noresampblur -noresample -in ${seg} -ref $ref -applyxfm -init ${wd}/fsl.anat/reg_mat -out ${wd}/fsl.anat/${name}_MNI152_1mm
done

echo "Moving useful outputs one directory up and clearing up..."
mv ${wd}/fsl.anat/T1_biascorr_brain_MNI152_1mm.nii.gz ${wd}
mv ${wd}/fsl.anat/T1_fast_pve_?_MNI152_1mm.nii.gz ${wd}
rm -r ${wd}/fsl.anat

echo ""
echo "        Done!"
echo ""
echo "---------------------------------------"
echo "~~~~~~~ Pre-processing complete ~~~~~~~"
echo "---------------------------------------"