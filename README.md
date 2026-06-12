# sake-public

Systematic benchmarking of T1-MRI preprocessing pipelines and classical machine learning models against 3D CNNs for Alzheimer's disease classification — the **S**wiss **A**rmy **K**nif**E** for brain MRI research.

This repository accompanies the IEEE Healthcom 2026 paper:

> **Classical MRI Pipelines Rival Deep Learning for Dementia Classification: A Benchmarking Study**
> Anastasia Gailly de Taurines, Payam Barnaghi, Ben Glocker, Fiona Kekwick, Alexander Capstick, Paresh Malhotra
> *IEEE International Conference on E-health Networking, Application & Services (Healthcom), 2026*

---

## Overview

We systematically benchmark six widely used T1-weighted MRI preprocessing pipelines — **FSL**, **SPM**, **CAT12**, **FreeSurfer**, **FastSurfer**, and **SynthSeg** — combined with seven classical ML classifiers (SVM, Random Forest, Logistic Regression, Naïve Bayes, kNN, XGBoost, MLP), against three standard 3D CNN architectures (**ResNet18**, **ResNet50**, **DenseNet121**) for binary CN vs. AD classification.

Models are trained and evaluated on **1,701 participants from ADNI**, with external validation of the best-performing approaches on **575 participants from AIBL**. The framework evaluates classification performance, interpretability (SHAP / Grad-CAM), computational efficiency, and generalisability.

**Key finding:** Classical pipelines — particularly **CAT12 + XGBoost** (AUCROC: 96.1 ± 1.0%) — match or exceed 3D CNN baselines (ResNet50 AUCROC: 94.1 ± 1.4%) while requiring a fraction of the computational resources and offering substantially greater interpretability via SHAP analysis.

---

## Repository Structure

```
sake-public/
├── LICENSE
├── README.md
├── classical_ml/
│   ├── SAKE_run-analysis.ipynb      # Classical ML preprocessing, training & evaluation
│   ├── SAKE_functions.py            # Auxiliary functions for the notebook
│   └── sake/                        # Swiss Army KnifE: T1 MRI preprocessing pipelines
│                                    # (FSL, SPM, CAT12, FreeSurfer, FastSurfer, SynthSeg)
└── deep_learning/
    ├── CNN-run.ipynb                # CNN training & evaluation notebook
    ├── SAKE_train.py                # CNN training script (PyTorch Lightning)
    └── preproc.sh                   # Bash script: Biobank-protocol T1 preprocessing
```

---

## Data Access

This repository does **not** include MRI data. Access must be requested independently:

- **ADNI** (Alzheimer's Disease Neuroimaging Initiative): [adni.loni.usc.edu](https://adni.loni.usc.edu)
- **AIBL** (Australian Imaging, Biomarker & Lifestyle study): [aibl.csiro.au](https://aibl.csiro.au)

After downloading, participants with an MCI diagnosis at the time of their selected scan were excluded. Only the most recent T1 scan per participant was used.

---

## Installation

### Classical ML environment

```bash
conda env create -f envs/classical_ml_environment.yml
conda activate sake-classical
```

Key dependencies: Python 3.12.4, scikit-learn 1.5.1, XGBoost, SHAP, pandas, numpy, scipy, matplotlib, seaborn, bayesian-optimization.

External neuroimaging toolboxes must be installed separately (see links below):

| Pipeline | Version | Link |
|---|---|---|
| FSL | v6.0.5.1 | https://fsl.fmrib.ox.ac.uk |
| SPM12 | v7771 | https://www.fil.ion.ucl.ac.uk/spm |
| CAT12 | v2560 | https://neuro-jena.github.io/cat |
| FreeSurfer | v7.4.0 | https://surfer.nmr.mgh.harvard.edu |
| FastSurfer | v2.4.2 | https://github.com/Deep-MI/FastSurfer |
| SynthSeg | v2.0 | https://github.com/BBillot/SynthSeg |

### Deep Learning environment

```bash
conda env create -f envs/deep_learning_environment.yml
conda activate sake-dl
```

Key dependencies: Python 3.12.12, PyTorch 2.2.2+cu121, Lightning 2.2.0, MONAI 1.5.2, TorchIO 0.19.6, torchmetrics, wandb, tqdm.

> **Hardware note:** CNN training was conducted on an NVIDIA A100 80 GB GPU. A CUDA-capable GPU is strongly recommended.

---

## Usage

### 1. T1 MRI Preprocessing (Classical ML)

Preprocessing scripts for all six pipelines are contained in the `classical_ml/sake/` folder. Each pipeline is applied following its standard workflow to extract cortical and subcortical regional morphometric features. Features are extracted using the DKT atlas (FSL, SPM, FastSurfer, CAT12) or DK atlas (FreeSurfer, SynthSeg).

### 2. Classical ML Training & Evaluation

Open and run `classical_ml/SAKE_run-analysis.ipynb`. This notebook covers:

- Feature loading and z-score normalisation (training-set parameters only)
- Three feature selection strategies: no selection, L1 (Lasso), MRMR
- Bayesian hyperparameter optimisation (nested 5-fold CV)
- Classification threshold moving via Youden's Index
- Repeated Monte-Carlo cross-validation (5 seeds, 85/15 train/test split, stratified by diagnosis and sex)
- Performance evaluation: accuracy, AUCROC, precision, sensitivity, specificity, F1
- SHAP interpretability analysis

### 3. T1 MRI Preprocessing (CNN)

```bash
bash deep_learning/preproc.sh
```

Applies the UK Biobank protocol: skull stripping and bias-field correction (FSL), non-linear registration to MNI152 1 mm standard space, resampling to 2 mm isotropic resolution (109×109×109 voxels), and per-subject z-scoring.

### 4. CNN Training

```bash
python deep_learning/SAKE_train.py \
    --csv_train /path/to/train.csv \
    --csv_test /path/to/test.csv \
    --model resnet50 \
    --seed 42
```

Or use the interactive `deep_learning/CNN-run.ipynb` notebook. Training uses the Adam optimiser (lr=0.001, weight_decay=1e-4), binary cross-entropy loss, up to 100 epochs with early stopping (patience=20) based on validation AUCROC. Data augmentation is applied via TorchIO (random gamma, Gaussian noise, simulated motion, bias field, random affine, elastic deformation; p=0.5 per transform).

---

## Results Summary

### ADNI (primary cohort, n=1,701)

| Approach | Best combination | AUCROC | Accuracy |
|---|---|---|---|
| Classical ML | CAT12 + XGBoost (no feat. selection) | 96.1 ± 1.0% | 90.7 ± 1.5% |
| Classical ML | CAT12 + LR (no feat. selection) | 96.1 ± 0.7% | — |
| CNN | ResNet50 | 94.1 ± 1.4% | 85.9 ± 4.5% |
| CNN | DenseNet121 | 94.0 ± 1.0% | 83.1 ± 5.7% |

### AIBL (external validation, n=575)

| Approach | Best combination | AUCROC |
|---|---|---|
| Classical ML (CAT12) | XGBoost + MRMR | 96.5 ± 1.9% |
| CNN | ResNet50 (trained from scratch) | 84.5 ± 7.2% |

Values are mean ± SD across 5 Monte-Carlo cross-validation seeds.

---

## Citation

If you use this code, please cite:

```bibtex
@inproceedings{gaillyde taurines2026sake,
  title     = {Classical MRI Pipelines Rival Deep Learning for Dementia Classification: A Benchmarking Study},
  author    = {Gailly de Taurines, Anastasia and Barnaghi, Payam and Glocker, Ben and Kekwick, Fiona and Capstick, Alexander and Malhotra, Paresh},
  booktitle = {IEEE International Conference on E-health Networking, Application \& Services (Healthcom)},
  year      = {2026}
}
```

---

## Acknowledgements

Data used in preparation of this work were obtained from the Alzheimer's Disease Neuroimaging Initiative (ADNI) database (adni.loni.usc.edu). As such, the investigators within the ADNI contributed to the design and implementation of ADNI and/or provided data but did not participate in analysis or writing of this report. Data collection and sharing for this project was funded by the Alzheimer's Disease Neuroimaging Initiative (ADNI) (National Institutes of Health Grant U01 AG024904) and DOD ADNI (Department of Defense award number W81XWH-12-2-0012).

Data were also obtained from the Australian Imaging, Biomarker & Lifestyle (AIBL) study of ageing.

---

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file included in this repository.
