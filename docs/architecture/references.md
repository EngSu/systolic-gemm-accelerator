# Foundational references

## UC Berkeley Gemmini

Official repository: https://github.com/ucb-bar/gemmini

Study: its PE/Tile/Mesh hierarchy; `MeshWithDelays`; parameterization of tileRows, tileColumns, meshRows, meshColumns; OS vs WS datapath control; scratchpad and accumulator; DMA and test strategy.

Use these as architectural case studies, not as a Verilog implementation to copy. Gemmini is written in Chisel and targets the Chipyard/RISC-V ecosystem.

## Google TPU v1

Original paper: Norman P. Jouppi et al., *In-Datacenter Performance Analysis of a Tensor Processing Unit*, ISCA 2017.
https://www.cs.cmu.edu/afs/cs/academic/class/15740-f18/www/papers/isca17-jouppi-tpu.pdf

Study: the 256×256 systolic matrix multiply unit, 8-bit multiply/accumulate datapaths, weight preloading, diagonal wavefront propagation, accumulators, unified buffer and the necessity of keeping the array supplied with data.

Do not generalize TPU v1 design details to all later TPU generations.

## Engineering interpretation

Our project's OS and WS implementations are two distinct datapaths for the same matrix-product contract. The first milestone is correct behavior; later study evaluates storage, scheduling, resource use, frequency and performance. Keep control, memory and physical timing details separately traceable to source material.
