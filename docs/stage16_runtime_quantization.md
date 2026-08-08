# new第16阶段：运行时量化策略配置

## 阶段目标

在第15阶段运行时选择 Q1.14/Q1.10 的基础上，把项目最初定位中的
`round/saturation/truncation` 变成可配置且可验证的控制路径。默认行为保持
原有最近值舍入和饱和，不改变已有软件的结果。

## QUANT_CTRL 寄存器

AXI4-Lite 地址为 `0x048`，复位值为 `0`：

| 位 | 名称 | 说明 |
|---:|---|---|
| 0 | `truncate` | 1 直接截断，0 最近值舍入 |
| 1 | `wrap` | 1 低位回绕，0 超范围饱和 |
| 31:2 | 保留 | 必须写 0 |

只有核心空闲且没有 pending commit 时允许修改。非法写返回 `SLVERR`，事务
开始时锁存两个策略位，保证一个向量不会在计算中途混用不同量化策略。

## RTL 实现

- `rtl/axi_lite_regs.sv` 增加寄存器写入、读回、保留位检查和忙时保护。
- `rtl/axi_precoder_wrapper.sv` 连接控制寄存器和核心。
- `rtl/precoder_core.sv` 在事务开始锁存策略。
- `rtl/fixed_round_sat.sv` 支持最近值舍入/截断以及饱和/回绕两条输出路径。

## UVM 验证

`precoder_quantization_test` 使用满幅 Q1.14 对角矩阵和输入，依次检查默认
舍入+饱和、截断+饱和、舍入+回绕及忙时写保护。阶段日志必须包含
`[PHASE16] runtime quantization checked`，同时 `UVM_ERROR=0`、
`UVM_FATAL=0`，SVA 统计应为4个输入向量和4个输出向量。

服务器单行命令：

```bash
UVM_TEST=precoder_quantization_test VECTORS=4 SEED=20260819 bash sim/run_uvm.sh
```
