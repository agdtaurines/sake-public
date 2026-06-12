#!/bin/sh
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
###Script to extract mean c1 VBM volumes from ROIs of the DKT.

#Made by Anastasia GdeT - 21 Apr 2024

#USAGE: ./ROIVols <c1_path>
#e.g.: ./ROIVols c1.nii.gz
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

module load fsl

c1="$1"
workingDir=${1%/*} #extracts path

if [[ $1 == *.gz ]]; then
    filename=${1%.*.*} #Extracts the string before the file extensions
    filename=`basename $filename`
elif [[ $1 == *.nii ]]; then
    filename=${1%.*}
    filename=`basename $filename`
else
    echo "Filename not recognizable!"
    exit 1
fi

echo "---------- LAUNCHING ROIVols FOR $filename ----------"

#Set up paths
SAKEDIR="/rds/general/user/afg21/home/Playground/PhD/sake"
atlas="${SAKEDIR}/ext/atlas/OASIS-TRT-20_jointfusion_DKT31_CMA_labels_in_MNI152_v2.nii.gz"
labels="${SAKEDIR}/ext/atlas/DKT_labels.csv"

echo -n "Preparing ROI volumes csv"
#Set up output ROI volumes csv
! > $workingDir/temp.csv
echo "roi,vol_mm^3" >> $workingDir/temp.csv

#Set up while loop to extract volume of each ROI as read from $labels
cat ${labels} | sed '1d' | while IFS=, read idx roi h l; do 
	
	#Produce ROI mask
	fslmaths $atlas -thr $idx -uthr $idx -bin "$workingDir/roimask.nii.gz"

	#Mask the c1 nifti with the ROI mask
	fslmaths $c1 -mas "$workingDir/roimask.nii.gz" "$workingDir/maskedc1.nii.gz"

	#Calculate the mean (for non-0 values) volume for the ROI
	ROImean=$(fslstats "$workingDir/maskedc1.nii.gz" -M)

	#Print output into a csv file
	echo "$roi,$ROImean" >> $workingDir/temp.csv
	
	echo -n ".";
	
done

echo "Done!"
echo "Transposing csv..."

!> $workingDir/ROIVols.csv

awk -F, '{
    for (i = 1; i <= NF; i++) {
        if (NR == 1) {
            header[i] = $i
        } else {
            data[i] = data[i] "," $i
        }
    }
}
END {
    for (i = 1; i <= NF; i++) {
        printf "%s,", header[i]
        print data[i]
    }
}' $workingDir/temp.csv | sed 's/^,//' | awk 'BEGIN {FS=OFS=","} {$2=""; sub(",,", ","); print}' >> $workingDir/ROIVols.csv

rm "$workingDir/roimask.nii.gz" "$workingDir/maskedc1.nii.gz" "$workingDir/temp.csv"

echo "Done!"
echo "Please find ROIVols.csv in $workingDir"

echo "---------- ROIVols FOR $filename complete! ----------"
