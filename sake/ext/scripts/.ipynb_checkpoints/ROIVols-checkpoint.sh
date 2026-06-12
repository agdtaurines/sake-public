#!/bin/sh
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
###Script to extract mean c1 volumes from ROIs of an atlas.
#Note - script was designed to deal with atlases where ROIs don't necessarily increase incrementally.
#Note - script requires matlab.

#Made by Anastasia GdeT - 28 Feb 2024

#USAGE: ./ROIVols <c1_path> <atlas_path>
#e.g.: ./ROIVols c1.nii.gz atlas.nii.gz
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

c1="$1"
atlas="$2"
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

#Produce new indexes for atlas
#Use matlab to convert 3D nifti to 1D array in a txt file

echo "Running matlab to convert 3D nifti to 1D array in a txt file..."
module load matlab/R2020a > /dev/null 2>&1
out="$workingDir/flat_atlas.txt"
matlab -nodisplay -nosplash -nodesktop -r "a=niftiread(\"$atlas\");fa=a(:);fid=fopen(\"$out\", 'w');fprintf(fid,'%f\n',fa);fclose(fid);exit"


#Take the flattened atlas, sort it, and print out only the unique values (sed removes first line - the 0s)
cat $workingDir/flat_atlas.txt | sort -n | uniq | sed '1d' | nl > $workingDir/idx.txt

#Find max idx of atlas
max_idx=$( cat $workingDir/idx.txt | sed '$!d' | while read new old; do echo "$new"; done )

echo "Preparing ROI volumes csv..."
#Set up output ROI volumes csv
! > $workingDir/ROIVols.csv
echo "idx,roi,vol_mm^3" >> $workingDir/ROIVols.csv

#Set up while loop, sequentially going from 1 to $max_idx to extract volume of each ROI
cat $workingDir/idx.txt | while read idx roi; do

	echo ".....[$idx/$max_idx]....."
	
	#Produce ROI mask
	fslmaths $atlas -thr $roi -uthr $roi -bin "$workingDir/roimask.nii.gz"

	#Mask the c1 nifti with the ROI mask
	fslmaths $c1 -mas "$workingDir/roimask.nii.gz" "$workingDir/maskedc1.nii.gz"

	#Calculate the mean (for non-0 values) volume for the ROI
	ROImean=$(fslstats "$workingDir/maskedc1.nii.gz" -M)

	#Print output into a csv file
	echo "$idx,$roi,$ROImean" >> $workingDir/ROIVols.csv

done

rm "$workingDir/roimask.nii.gz" "$workingDir/maskedc1.nii.gz" "$workingDir/flat_atlas.txt" "$workingDir/idx.txt"

echo "Done!"
echo "Please find ROIVols.csv in $workingDir"

echo "---------- ROIVols FOR $filename complete! ----------"
