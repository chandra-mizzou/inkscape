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
