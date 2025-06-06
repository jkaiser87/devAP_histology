# devAP_histology

This repository is a fork of [petersaj/AP_histology](https://github.com/petersaj/AP_histology), adapted to support both adult and **developmental mouse brain atlases** for aligning histological data and reconstructing 3D volumes.  

---

## 🆕 Key Adaptations

- 🗺️ **Allen Mouse Brain Atlas** — pre-processed and included directly, based on Wang Q, et al., 2020 [https://doi.org/10.1016/j.cell.2020.04.007](https://doi.org/10.1016/j.cell.2020.04.007))
- 👶 **Developmental Mouse Brain Atlas (P4–P14)** — based on Kronman et al., 2024 ([DOI: 10.1038/s41467-024-53254-w](https://doi.org/10.1038/s41467-024-53254-w))
- 📁 Standardized processing of files (redacted some functions from the original APhist, eg scaling of images)
- 💾 Large files managed with **Git LFS** for reliable download and version control

---

## ⚙️ Requirements

- MATLAB (2020 or later recommended)
- Git LFS (see below)

### 🔧 MATLAB Setup

This repo uses Git Large File Storage (LFS) to manage large atlas files (e.g., .npy atlas files.
Before cloning or pulling this repo, please run the following once:
``` bash
git lfs install
```

Then clone the repository to download files
``` bash
git clone https://github.com/jkaiser87/devAP_histology.git
```

If you skip git lfs install, you’ll only get pointer files and not the actual data.

--- 

This repository includes the atlases in compressed `.zip` format to reduce file size and stay within GitHub limits.

After cloning the repo, unzip the following files manually:

- `allenAtlas.zip` → becomes `allenAtlas/`
- `devAtlas.zip` → becomes `devAtlas/`

Make sure both folders are placed in the root directory of the repo so the pipeline can locate them correctly.

---

Now add the folder to your **MATLAB path** for the scripts to run correctly.

In MATLAB:
```matlab
addpath(genpath('C:\Path\To\devAP_histology'))
savepath
```

Replace C:\Path\To\devAP_histology with the actual location of the cloned folder.
Alternatively, use Home > Set Path > Add with Subfolders… in the MATLAB GUI.

## Running devAP_histology

To run the pipeline with a selected atlas, open MATLAB and call:

```matlab
AP_histology("P4")   % uses the P4 developmental atlas
AP_histology("P14")  % uses the P14 developmental atlas
AP_histology()       % defaults to the adult Allen atlas
```

### Note on Developmental Atlas Alignment

The auto-alignment procedure (AP_histology) was originally optimized for adult mouse brains using the Allen CCF. While the same framework has been extended to the developmental atlas (devCCF), automatic alignment often performs less reliably on P4–P14 slices due to differences in brain morphology, lower tissue contrast, and less well-defined landmarks.

- Carefully check alignment outputs
- Use manual adjustments or supplemental landmarks (e.g., bregma points, anatomical ROIs) if needed


# Atlas Sources and Credits

### Allen Mouse Brain Atlas
Wang Q, et al. (2020).
**The Allen Mouse Brain Common Coordinate Framework: A 3D Reference Atlas**. *Cell*.
[DOI: 0.1016/j.cell.2020.04.007](https://doi.org/10.1016/j.cell.2020.04.007)

### Developmental Mouse Brain Atlas (P4–P14)  
Kronman, F.N., et al. (2024).  
**A Common Coordinate Framework for the Developing Mouse Brain**. *Nature Communications*.  
[DOI: 10.1038/s41467-024-53254-w](https://doi.org/10.1038/s41467-024-53254-w)


## License

This project is released under the [MIT License](LICENSE), as inherited from the original [AP_histology](https://github.com/petersaj/AP_histology).
