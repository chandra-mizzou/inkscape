# KPFuse v4 dominant high-GPU network diagram

This directory contains a publication-oriented vector block diagram:

- `kpfuse_v4_dominant_high_gpu_network.svg`

## Scope

The current checkout did not contain the KPFuse source code or a literal `kpfuse_v4`
implementation. The diagram is therefore an editable CVPR-style draft that captures a
typical KPFuse-style dual-modality fusion network:

1. paired modality inputs,
2. modality stems / token embedding,
3. a dominant high-capacity GPU branch,
4. a keypoint/detail-preserving branch,
5. dominance-gated cross fusion,
6. FPN-style decoder and fused output,
7. optional high-GPU training/deployment context.

If the exact implementation becomes available, update the SVG labels and repeated block
counts (`DHB x N`, pyramid scales, losses, and branch names) to match the code.
