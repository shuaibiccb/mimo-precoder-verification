# 第20阶段：完整 AXI 顶层综合入口

## 本阶段完成内容

- DC 综合顶层由 `precoder_core` 切换为 `axi_precoder_wrapper`。
- 综合文件列表加入 AXI-Stream 输入/输出、AXI-Lite 寄存器、性能计数器和乱序缓冲区。
- DC 输出改为 `axi_precoder_wrapper_mapped.v/.sdc/.sdf` 及对应 DDC 文件。
- SDC 时钟和复位端口改为 wrapper 的 `aclk`、`aresetn`，时钟周期仍为 10 ns。
- Yosys 入口同步切换到 `axi_precoder_wrapper`，输出 `axi_precoder_wrapper_yosys.v`。

## 验证状态

本地工作区未安装 Yosys、Icarus 或 Design Compiler。服务器仓库已同步到本阶段提交，但当前非 EDA shell 的 PATH 中没有 `yosys`/`dc_shell`，所以尚未生成新的工艺库映射面积和时序数值。

在服务器加载 Design Compiler 环境后执行：

```text
export DC_TARGET_LIBRARY=/absolute/path/to/standard_cell.db; bash synth/run_dc.sh
```

执行完成后重点检查 `reports/generated/dc/check_design.rpt`、`qor.rpt`、`area.rpt`、`timing_max.rpt` 和 `constraints.rpt`。只有完整 wrapper 的 setup/hold 均满足，才能进入门级仿真和 SDF 反标。

