# devAP_histology

This repository is a fork of [petersaj/AP_histology](https://github.com/petersaj/AP_histology), adapted to support both adult and **developmental mouse brain atlases**.  
It has been further modified to integrate smoothly with the related repositories in this GitHub profile:

- 🧠 [CELL3D](https://github.com/jkaiser87/CELL3D) — for processing and visualizing 3D cell coordinate data  
- 🧠 [VOL3D](https://github.com/jkaiser87/VOL3D) — for plotting and analyzing traced injection volumes in 3D

These tools are designed to work together for comprehensive anatomical reconstruction and analysis.

---

## Key Adaptations

- **Allen Mouse Brain Atlas** — pre-processed and included directly, based on Wang Q, et al., 2020 [https://doi.org/10.1016/j.cell.2020.04.007](https://doi.org/10.1016/j.cell.2020.04.007))
- **Developmental Mouse Brain Atlas (P4–P14)** — based on Kronman et al., 2024 ([DOI: 10.1038/s41467-024-53254-w](https://doi.org/10.1038/s41467-024-53254-w))
- Standardized processing of files (redacted some functions from the original APhist, eg scaling of images)
- Large files managed with **Git LFS** for reliable download and version control

---

# Requirements

- MATLAB (2020 or later recommended)
- [`npy-matlab`](https://github.com/kwikteam/npy-matlab) (for reading `.npy` files)
- Git LFS (see below)


## Folder Setup

This repository  uses Git Large File Storage (LFS) to manage large atlas files (e.g., .npy atlas files.
Before cloning or pulling this repo, please run the following once:
``` bash
git lfs install
```

Then clone the repository to download files
``` bash
# Replace with your own path
cd /path/to/your/folder
git clone https://github.com/jkaiser87/devAP_histology.git
```

If you skip git lfs install, you’ll only get placeholder pointer files instead of usable atlas data.

--- 
## Atlas Setup

This repository includes the atlases in compressed .zip format to reduce storage load.
After cloning, manually unzip the following files:

    allenAtlas.zip → unzips to allenAtlas/

    devAtlas.zip → unzips to devAtlas/

Make sure both folders are extracted to the root of the repo (same level as README.md), so the pipeline can find them.

---

## Required Dependency: npy-matlab

This pipeline uses `.npy` files (NumPy format) for some atlas data.  
To read these in MATLAB, you must install the [`npy-matlab`](https://github.com/kwikteam/npy-matlab) toolbox.

1. Clone or download the repository:

```bash
# Recommended: clone into the devAP_histology folder
cd /path/to/devAP_histology
git clone https://github.com/kwikteam/npy-matlab.git
```
Alternatively, download and extract it from GitHub manually.

---

## Add folder to MATLAB Path
After cloning, add the repo and its dependencies to your MATLAB path.

In MATLAB:
```matlab
addpath(genpath('C:\Path\To\devAP_histology'))
addpath(genpath('C:\Path\To\npy-matlab'))  % if cloned elsewhere
savepath
```

Or, in the MATLAB GUI:
Go to Home > Set Path > Add with Subfolders…, select the folder(s), and click Save.

--- 

# Running devAP_histology

To run the pipeline with a selected atlas, open MATLAB and call:

```matlab
AP_histology("P4")   % uses the P4 developmental atlas
AP_histology("P14")  % uses the P14 developmental atlas
AP_histology()       % defaults to the adult Allen atlas
```

## Note on Developmental Atlas Alignment

The auto-alignment procedure (AP_histology) was originally optimized for adult mouse brains using the Allen CCF. While the same framework has been extended to the developmental atlas (devCCF), automatic alignment often performs less reliably on P4–P14 slices due to differences in brain morphology, lower tissue contrast, and less well-defined landmarks.

- Carefully check alignment outputs
- Use manual adjustments or supplemental landmarks (e.g., bregma points, anatomical ROIs) if needed


# Atlas Sources and Credits

## Allen Mouse Brain Atlas
Wang Q, et al. (2020).
**The Allen Mouse Brain Common Coordinate Framework: A 3D Reference Atlas**. *Cell*.
[DOI: 0.1016/j.cell.2020.04.007](https://doi.org/10.1016/j.cell.2020.04.007)

## Developmental Mouse Brain Atlas (P4–P14)  
Kronman, F.N., et al. (2024).  
**A Common Coordinate Framework for the Developing Mouse Brain**. *Nature Communications*.  
[DOI: 10.1038/s41467-024-53254-w](https://doi.org/10.1038/s41467-024-53254-w)


## License

This project is released under the [MIT License](LICENSE), as inherited from the original [AP_histology](https://github.com/petersaj/AP_histology).
