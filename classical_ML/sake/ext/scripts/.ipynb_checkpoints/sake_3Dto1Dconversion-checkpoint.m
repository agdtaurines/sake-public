function sake_3Dto1Dconversion(atlas,output_txt)
%sake_3Dto1Dconversion - matlab script converting 3D nifti to 1D text file
    a=niftiread(atlas);
    fa=a(:);
    fid=fopen(output_txt, 'w');
    fprintf(fid,'%f\n',fa);
    fclose(fid)
end