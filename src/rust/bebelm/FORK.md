# Curated BebeLM fork

This directory began as a vendored copy of
[`maximecb/bebelm`](https://github.com/maximecb/bebelm), whose MIT licence and
copyright notices remain in force. It is maintained here as the native CPU
model-integration layer for Rbebelm.

It is deliberately not a generic GGUF runner. A GGUF container does not define
the model graph, tokenizer contract, cache semantics, tensor names, or all
required CPU kernels. Each supported profile therefore has a closed metadata
and tensor validation contract, purpose-built forward implementation, and
tests against its published reference behavior.

Current profiles are:

- `lfm2moe`: the upstream LFM2.5-8B-A1B generation profile, exposed through
  `BebelModel`;
- `lfm2`: the LFM2.5-ColBERT-350M late-interaction encoder, exposed separately
  through `ColbertModel` with bidirectional attention, token projections, and
  MaxSim scoring.

Adding a new CPU model means adding a complete profile and an external oracle
test. It does not mean accepting an arbitrary `general.architecture` value or
trying to infer unsupported tensors at runtime.
