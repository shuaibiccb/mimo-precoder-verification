# Core-only physical implementation

The reproducible flow is in `pnr/run_icc.sh`. It uses ICC O-2018.06-SP5 and the SMIC55 RVT Milkyway/TLU+ package on the server. The flow imports the DC netlist and SDC, creates a 65% core floorplan, runs placement, CTS, power rings/straps, filler insertion, preroutes standard-cell power rails, and route optimization.

The verified TT setup is:

- Technology: `scc55nll_vhs_10m_8ic_2tmc_alpa1.tf`
- RC corners: `StarRC_55LLULP_1P10M_8Ic_2TMc_ALPA1_RCMAX/RCMIN.tluplus`
- Cell timing library: `scc55nll_vhs_rvt_tt_v1p2_25c_basic.db`
- Signal clock: `core_clk`, 10 ns period

The final server run produced:

- Post-route setup slack: `+2.15 ns`
- Post-route hold slack: approximately `+0.10 ns`
- Setup/hold violating paths: `0`
- Routed-net DRC violations: `0`
- Open routed nets: `0`
- LVS shorts/opens: `0/0`
- Cell area reported by ICC: `71867.520234 um^2`
- Post-route artifacts: `reports/generated/icc/precoder_core_postroute.v`, `precoder_core_postroute_sim.v`, `.sdf`, `.spef.max`, `.spef.min`

`precoder_core_postroute.v` retains power/ground and filler instances for physical checks. Use `precoder_core_postroute_sim.v` for SDF simulation because the foundry logic model does not define the physical-only `FDCAPVHS*` filler cells; the SDF contains no timing entries for those fillers.

Run independent post-route STA with:

```bash
bash pnr/run_pt_postroute.sh
```

PrimeTime independently reported setup slack `+2.15 ns`, hold slack `+0.10 ns`, and zero violating paths using the extracted SPEF.

Run the final post-route SDF gate regression with:

```bash
bash sim/run_postroute_gate_vcs.sh
```

The verified run annotated the ICC SDF with zero errors and zero warnings. Both `precoder_core` (15 cases and 60 output comparisons) and `precoder_hot_update` passed. Runtime reset checks wait for one active clock edge before sampling reset state so that the same test remains valid with real post-route propagation delay.

The physical check still reports the package's native TF/ITF min-width and min-spacing mismatch warnings (`TLUP-004/TLUP-005`) and one floorplan grid warning (`PSYN-523`). These are documented process-package warnings; the final route and LVS checks reported no errors.
