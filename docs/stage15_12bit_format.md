# Stage 15: Runtime Q1.10 and Q1.14 Formats

Stage 15 adds a runtime-selectable fixed-point format while preserving the
existing 16-bit AXI field widths and the default 4x4/8x8 behavior.

## Format contract

| FORMAT | Internal format | Fraction bits | Valid coefficient bits |
|---:|---|---:|---:|
| 0 | signed Q1.14 | 14 | all 16 bits |
| 1 | signed Q1.10 | 10 | low 12 bits; upper 4 bits are sign extension |

The AXI-Lite `FORMAT` register is at offset `0x044`. Reset selects Q1.14.
Software may change the format only while the core is idle and no matrix
commit is pending. A format change invalidates both matrix-bank completeness
flags, so the matrix must be written again before a transaction can start.

For Q1.10, matrix writes must sign-extend bit 11 into bits 15:12. Input
symbols use the same sign-extension rule. Outputs are calculated with the
latched transaction format, rounded and saturated from the wider accumulator,
then sign-extended back into the 16-bit AXI data field.

## RTL changes

- `rtl/axi_lite_regs.sv`: FORMAT register, readback, idle-only write protection,
  and matrix invalidation request.
- `rtl/matrix_storage.sv`: clears bank completeness after a format change.
- `rtl/precoder_core.sv`: latches format at transaction start and implements
  Q1.10 rounding/saturation and sign-extension checks.
- `rtl/axi_precoder_wrapper.sv`: connects the format control path.

## Verification

The UVM scoreboard selects Q1.14 or Q1.10 reference arithmetic dynamically.
`precoder_12bit_test` checks register readback, busy-time write protection,
sign extension, 8x8 matrix reload, output metadata, and end-to-end fixed-point
results. The server result for seed `20260815` was:

```text
12-bit Q1.10 8x8 reference checked 1 vector, max EVM=1.110557e-03
UVM_ERROR : 0
UVM_FATAL : 0
PASS: precoder_12bit_test completed with seed 20260815
```

The normal 4x4 UVM smoke test also passed after the format changes. Use the
following commands on the VCS server for a short regression:

```bash
UVM_TEST=precoder_12bit_test VECTORS=1 SEED=20260815 bash sim/run_uvm.sh
RUNS=2 VECTORS=2 BASE_SEED=20260815 bash sim/run_uvm_regression.sh
```

## Completion criteria

Stage 15 is complete when both formats pass the UVM scoreboard with zero
errors/fatals, illegal format writes are rejected, matrices are reloaded after
a format change, and the GitHub commit is present in the formal server clone.
