# Stage 13: Runtime-selectable 4x4 and 8x8 mode

Stage 13 extends the precoder IP while keeping reset-time software compatibility.
The reset default is 4x4; software selects 8x8 by writing `1` to the AXI4-Lite
`MODE` register at `0x040`. The mode register can only be changed while the
core is idle and no matrix commit is pending.

## Datapath

- Each matrix bank stores 8x8 complex Q1.14 coefficients (64 entries).
- The existing four complex MAC lanes are retained.
- In 4x4 mode, one input vector has four beats and produces four outputs.
- In 8x8 mode, one input vector has eight beats and produces eight outputs.
  The four MAC lanes calculate rows 0..3 and then rows 4..7 in two groups.
- The active bank and matrix version are still latched at transaction start;
  a pending bank commit takes effect only after the final output handshake.

## AXI changes

The matrix windows are mode-dependent:

```text
Bank0: 0x100 + (row * 8 + col) * 4, rows/columns 0..7
Bank1: 0x200 + (row * 8 + col) * 4, rows/columns 0..7
```

`m_axis_tuser` is now 12 bits. Its fields are:

```text
[1:0]  antenna index low bits
[2]    saturation flag
[10:3] matrix version
[11]   antenna index bit 2
```

The 4x4 field layout remains backward-compatible. `TLAST` is asserted on
antenna 3 in 4x4 mode and antenna 7 in 8x8 mode.

`IP_VERSION` is `32'h0002_0000` for this interface revision.

## Verification evidence

`tb/axi/tb_axi_precoder_8x8.sv` configures both 8x8 banks, checks the MODE
register, verifies 8-beat input and output packets, checks antenna/TLAST/TUSER
metadata, exercises output backpressure, and proves that a busy mode write is
rejected while a pending bank commit activates at the transaction boundary.
