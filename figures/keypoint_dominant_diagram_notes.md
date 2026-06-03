# KeypointDominantFusionNet CVPR diagrams

This directory now includes two code-grounded, editable SVG figures based on the
provided `KeypointDominantFusionNet` and `KeypointCentricLoss` implementation.

## Figures

- `keypoint_dominant_fusion_net_detailed.svg`
  - detailed network architecture,
  - VIS/IR inputs,
  - content cue extraction,
  - VIS and IR encoders at three scales,
  - `DominanceCrossAttention` blocks `ca1`, `ca2`, and `ca3`,
  - top fusion, decoder, RGB/IR-weight heads,
  - luminance fusion and color recovery.

- `keypoint_dominant_loss_backprop.svg`
  - training batch flow,
  - trainable `KeypointDominantFusionNet` block with a vector fire icon,
  - frozen `KeyNetResponse` block with a vector snowflake icon,
  - keypoint, gradient, source-anchor, and GT-anchor losses,
  - validation keypoint-retention metrics,
  - backpropagation and frozen-gradient boundaries.

The SVG files are intended for paper figure editing in vector tools such as Inkscape,
Illustrator, or directly in LaTeX/PDF conversion workflows.

## Preferred clean CVPR versions

After comparing the provided reference PDF against the implementation, the following
straight-line SVG/PDF pairs were added as the preferred paper-ready versions:

- `keypoint_dominant_network_cvpr_clean.svg` / `keypoint_dominant_network_cvpr_clean.pdf`
  - compact architecture figure with mostly orthogonal connectors,
  - faithful to the provided code and reference diagram,
  - intended as the main network figure.

- `keypoint_dominant_loss_backprop_cvpr_clean.svg` / `keypoint_dominant_loss_backprop_cvpr_clean.pdf`
  - compact loss/evaluation/backpropagation figure,
  - includes the requested fire icon on the trainable fusion network block,
  - includes the requested snowflake icon on the frozen KeyNet block.

## Download guidance for full visibility

If module box outlines disappear after download, the viewer/importer is likely ignoring
embedded SVG CSS. Use one of these options:

1. For CVPR/LaTeX submission, use the exported PDF files. They preserve fills, strokes,
   arrowheads, and text in a single-page vector format.
2. If SVG is required, download from GitHub using **Raw** or **Download raw file** rather
   than right-clicking the rendered preview.
3. For PowerPoint, Word, Google Docs, or other tools that sometimes strip CSS, use the
   portable inline-styled SVG copies:
   - `keypoint_dominant_network_cvpr_portable.svg`
   - `keypoint_dominant_loss_backprop_cvpr_portable.svg`

The `*_cvpr_clean.svg` files remain editable source SVGs, while the `*_cvpr_portable.svg`
files are optimized for robust download/import visibility.
