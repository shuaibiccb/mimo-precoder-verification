# new第17阶段：AXI-Stream事务 ID 与端到端一致性

## 阶段目标

在已有 AXI-Stream 数据、`TLAST/TKEEP`、矩阵版本和 SVA 检查基础上增加独立的
8 位事务标识。`s_axis_tid` 在一个输入向量的所有拍必须保持一致；DUT 在第一拍握手
时锁存它，并在该向量的每个 `m_axis` 输出拍通过 `m_axis_tid` 原样返回。当前微架构
仍只允许一个事务在途，因此本阶段不引入乱序执行或第二个输入缓存。

## 接口契约

| 信号 | 位宽 | 规则 |
|---|---:|---|
| `s_axis_tid` | 8 | 输入事务 ID，向量内所有 beat 相同 |
| `m_axis_tid` | 8 | 对应输入事务 ID，向量内所有输出 beat 相同 |

`TID` 不占用既有 `TDATA` 和 `TUSER` 位，复位默认值为 `0`。输入在
`TVALID && TREADY` 握手时采样，输出在 `TVALID && TREADY` 握手时检查；输出反压期间
`TDATA/TKEEP/TLAST/TUSER/TID` 必须全部稳定。

## RTL实现

- `rtl/axi_stream_input.sv` 在向量第一拍锁存 `s_axis_tid`；
- `rtl/axi_precoder_wrapper.sv` 将锁存值连接到输出通道；
- `rtl/axi_stream_output.sv` 原样驱动 `m_axis_tid`；
- 不修改核心的计算、定点格式、量化策略和双 Bank 行为。

## 验证与验收

UVM transaction、driver、monitor 和 scoreboard 均携带并检查 TID。AXI SVA 增加
反压稳定性和向量内 TID 不变断言。阶段专用 `precoder_tid_test` 使用三个不同 ID 的
4x4 向量并覆盖输出反压；已有 `precoder_8x8_test` 和 `precoder_12bit_test` 使用
非零 ID，覆盖 8x8 与 Q1.10 路径。

验收必须同时满足：

1. 4x4、8x8、Q1.10、量化策略和随机回归中的 `UVM_ERROR=0`、`UVM_FATAL=0`；
2. TID mismatch 计数为 0，SVA 无 assertion failure；
3. 旧版定向测试将输入 TID 置 0 并继续通过；
4. 本文档、验证计划和 README 的阶段记录提交到 GitHub。
