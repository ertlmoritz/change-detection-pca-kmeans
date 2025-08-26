# Unsupervised Change Detection in Satellite Images using PCA and K-Means

This repository provides a MATLAB implementation of the unsupervised change detection algorithm described in:

> T. Celik, "Unsupervised Change Detection in Satellite Images Using Principal Component Analysis and k-Means Clustering," *IEEE Geoscience and Remote Sensing Letters*, vol. 6, no. 4, pp. 772-776, Oct. 2009.

![Change Detection Demo](data/Brazil/progress.gif)


The algorithm combines **Principal Component Analysis (PCA)** with **K-Means clustering** to detect changes in multi-temporal satellite imagery. It is designed for analyzing already registered image sequences in different scenarios such as urbanization, deforestation, glacier melting, desiccation, or general change.

---

## Features

* PCA-based feature extraction from blockwise image differences
* K-Means clustering for binary change detection
* Scene-specific masks for common applications (urbanization, vegetation loss, glacier retreat, water changes)
* Visualization: overlays, cumulative change plots
* Optional GIF export of temporal evolution

---

## Repository Structure

```
change-detection-pca-kmeans/
├── src/
│   ├── changeDetectionPCAKMeans.m   # Main algorithm
│   └── loadRegisteredImages.m       # Loader for registered image sequences
│
├── examples/
│   └── demoUrbanization.m           # Example demo script
│
├── data/
│   └── urbanization/                # Example dataset (small registered images)
│
├── LICENSE
├── .gitignore
└── README.md
```

---

## Getting Started

### Requirements

* MATLAB R2021a or newer (Image Processing Toolbox recommended)

### Clone Repository

```bash
git clone https://github.com/moritz-ertl/change-detection-pca-kmeans.git
cd change-detection-pca-kmeans
```

### Run Example

In MATLAB:

```matlab
cd examples
run demoUrbanization.m
```

This will:

* Load images from `data/urbanization`
* Run the PCA+KMeans change detection
* Show cumulative change plots
* Overlay detected changes on the final image

---

## Usage

### Core function

```matlab
[fullChangeMaps, nValidPixels, cumChanges, relGrowth] = ...
    changeDetectionPCAKMeans(imgs, scene, 'Name', Value,...)
```

**Inputs:**

* `imgs` : cell array of RGB images (same size, pre-registered)
* `scene` : one of `'urbanization' | 'deforestation' | 'glacier melting' | 'desiccation' | 'general'`

**Name-Value options:**

* `'folderPath'` : path to save GIF (default: '')
* `'h'` : block size for PCA (default: 2)
* `'S'` : number of PCA components (default: 3)
* `'doPlot'` : show overlays (default: false)
* `'doGraph'` : plot cumulative change (default: false)
* `'delayTime'` : GIF frame delay in seconds (default: 1.0)

**Outputs:**

* `fullChangeMaps` : cell array of binary change masks
* `nValidPixels`   : number of valid pixels in analysis area
* `cumChanges`     : cumulative change ratio per time step
* `relGrowth`      : incremental change per step

### Loader function

```matlab
imgs = loadRegisteredImages(folderPath)
```

* Reads all `.png/.jpg/.tif` images from folder
* Sorts by `MM_YYYY` in filename
* Crops all images to common size
* Returns cell array of RGB images

---

## Example Output

* Detected change masks (red overlays)
* Cumulative change curve over time
* Optional animated GIF of progression

---

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.

---

## Citation

If you use this code, please cite the original paper:

```
@article{celik2009unsupervised,
  title={Unsupervised Change Detection in Satellite Images Using Principal Component Analysis and k-Means Clustering},
  author={Celik, Turgay},
  journal={IEEE Geoscience and Remote Sensing Letters},
  volume={6},
  number={4},
  pages={772--776},
  year={2009},
  publisher={IEEE}
}
```

---

## LICENSE (MIT)

```text
MIT License

Copyright (c) 2025 Moritz Ertl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## .gitignore (MATLAB)

```gitignore
# Ignore MATLAB autosave and backup files
*.asv
*.m~
*.mat~
*.fig~

# Ignore data if too large
data/

# Ignore system files
.DS_Store
Thumbs.db
```

