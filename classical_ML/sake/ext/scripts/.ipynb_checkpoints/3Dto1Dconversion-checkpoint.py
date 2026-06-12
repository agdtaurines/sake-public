###Python script converting 3D nifti to 1D text file

print("~~~~~ Running 3Dto1Dconversion ~~~~~")

import os
import sys

# Check if numpy and nibabel are installed, if not, install them
try:
    import numpy as np
except ImportError:
    os.system("pip install numpy")
    import numpy as np

try:
    import nibabel as nib
except ImportError:
    os.system("pip install nibabel")
    import nibabel as nib

def nifti_to_1d_vector(input_file, output_file):
    # Load NIfTI file
    img = nib.load(input_file)
    data = img.get_fdata()

    # Reshape into 1D vector
    vector_data = np.ravel(data)

    # Save 1D vector to text file
    np.savetxt(output_file, vector_data, fmt='%d')

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py input_nifti_file output_text_file")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    nifti_to_1d_vector(input_file, output_file)
    print("Conversion complete!")