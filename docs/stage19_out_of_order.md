# 第19阶段：AXI-Stream 事务乱序完成

## 目标

在保留已有单 MAC 计算核心的前提下，允许最多两笔完整输入向量暂存在 RTL 中，并依据 `TID` 选择较小 ID 先送入核心。这样后接受的事务可以先完成，输出包内部仍保持连续且不交错。

## RTL 实现

- `rtl/axi_stream_reorder_buffer.sv` 放在 `axi_stream_input` 与 `precoder_core` 之间。
- 每个槽保存最多 8 个复数采样、`TID` 和向量长度。
- `0x04C` 为 `REORDER_CTRL`：bit0 为使能；读回 bit0 为使能、bit1 为 busy、bit3:2 为当前槽占用数。
- 复位和默认配置下乱序关闭，输入直接旁路到原计算核心，保证前 18 阶段行为不变。
- 缓冲区非空时锁住矩阵、commit、MODE、FORMAT 和量化配置，避免排队事务使用错误的 Bank 或定点上下文。
- wrapper 在事务真正开始送入核心的第一个握手周期锁存 TID，再由 `axi_stream_output` 贯穿整个输出包。

## 验证方法

`precoder_out_of_order_test` 完成以下检查：

1. 写 `0x04C=1` 并回读使能状态。
2. 先发送 `TID=0xB0`，再发送 `TID=0x20`。
3. 在输出背压下检查完成顺序为 `0x20 -> 0xB0`。
4. 每个输出 beat 与按 TID 保存的位精确参考结果、矩阵版本、饱和标志和 EVM 逐项比较。
5. 检查 AXI-Lite 配置冻结、输入/输出计数均为 2，以及无重复、未知和泄漏 ID。

运行入口：

```text
UVM_TEST=precoder_out_of_order_test SVA_COVERAGE=1 bash sim/run_uvm.sh
```

完整回归脚本也会合并 `precoder_out_of_order.vdb` 到 SVA 覆盖率报告。
