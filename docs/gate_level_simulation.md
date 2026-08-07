# 综合后门级仿真

本阶段使用 Design Compiler 生成的 `precoder_core_mapped.v`、SMIC55 RVT 标准单元 Verilog 模型和现有核心测试平台，验证综合网表的逻辑功能。

在服务器工程根目录运行：

```bash
bash sim/run_gate_vcs.sh
```

脚本执行 `precoder_core` 主回归和热更新回归，编译与运行日志写入 `build/vcs/`。默认标准单元模型为：

```text
/cad/eda_lib/smic55nm_2020/SCC55NLL_VHS_STDCELL/SCC55NLL_VHS_RVT_lib_V2.1/SCC55NLL_VHS_RVT_V2.1/SCC55NLL_VHS_RVT_V2p1/verilog/scc55nll_vhs_rvt.v
```

如模型或映射网表位于其他位置，可分别设置 `SMIC55_VERILOG_MODEL` 和 `DC_MAPPED_NETLIST`。

当前流程定义 `functional`，关闭标准单元 `specify` 延迟，属于零延迟门级功能仿真。它用于检查综合网表和 RTL 测试期望是否一致，不替代布局布线、CTS 后基于寄生参数与 SDF 的时序仿真。

DC 综合脚本同时生成 `reports/generated/dc/precoder_core_mapped.sdf`。使用综合后最大延迟 SDF 运行门级回归：

```bash
SDF=1 bash sim/run_gate_vcs.sh
```

该 SDF 来自布局布线前的线负载估计，只用于验证反标流程和综合后时序行为。最终签核仍应使用布局布线、CTS 和寄生参数提取后生成的 SDF。
