# 综合与 PPA 基线

本阶段以 `precoder_core` 为综合顶层。时钟约束初始设为 100 MHz（10 ns），时钟不确定度为 0.2 ns，输入/输出延迟各为 1 ns。该约束用于建立第一版基线，不代表最终芯片接口预算。

其中建立时间不确定度为 0.2 ns；综合阶段使用理想时钟，保持时间不确定度单独设为 0.05 ns，避免把完整的建立时间裕量错误地同时作为保持时间要求。完成布局布线和时钟树综合后，必须使用实际时钟延迟与偏斜重新进行保持时间分析和修复。

## Yosys 可综合性检查

```bash
bash synth/run_yosys.sh
```

Yosys 不依赖工艺库，适合检查层次、锁存器/多驱动等结构问题，并给出通用逻辑资源统计。报告和网表生成在 `reports/generated/`。Yosys 的通用单元数量不能直接换算为流片面积。

## Design Compiler 工艺映射

综合前必须选择服务器上合法授权的标准单元 `.db`：

```bash
export DC_TARGET_LIBRARY=/absolute/path/to/standard_cell.db
bash synth/run_dc.sh
```

输出包括 `check_design.rpt`、`qor.rpt`、`area.rpt`、最大/最小时序报告、约束违例、资源/引用统计和映射后网表。面积和最大频率必须同时注明标准单元库、PVT 角、时钟约束和 DC 版本，否则数字没有可比性。

## 报告判读

- `check_design.rpt`：首先确认没有多驱动、未连接关键端口或不可综合结构；
- `timing_max.rpt`：建立时间裕量必须非负，负值表示目标周期未满足；
- `timing_min.rpt`：检查保持时间路径；
- `area.rpt`：记录组合、时序和总单元面积，并识别 16x16 乘法器的资源占比；
- `references.rpt` / `resources.rpt`：确认综合后仍对应 4 路复数 MAC 架构；
- `constraints.rpt`：所有违例都需要解释或修复。

首次综合完成后，应记录工艺库、目标周期、WNS、TNS、总面积、寄存器数和乘法器映射结果，再根据关键路径决定是否为复数乘法器增加流水级。
