# new第2阶段：AXI接口规格

## 1. 阶段目标

本阶段冻结 `precoder_core` 的AXI封装协议，为下一阶段实现
`axi_precoder_wrapper` 提供可执行的接口契约。

AXI不是用来替换核心内部接口。最终层次固定为：

```text
CPU / DMA
   |
AXI4-Lite + AXI4-Stream
   |
axi_precoder_wrapper
   |
现有 cfg/commit/in/out valid-ready 接口
   |
precoder_core
```

本阶段只定义规格，不修改已经完成综合和后布线验证的 `precoder_core`。

## 2. 第一版固定范围

- 4x4复数矩阵向量乘法；
- 16位有符号Q14实部和虚部；
- 固定4路并行复数MAC；
- AXI4-Stream输入和输出数据宽度为32位；
- AXI4-Lite地址和数据宽度为32位；
- AXI接口和计算核心共用一个时钟 `aclk`；
- 低有效复位 `aresetn` 直接连接核心 `rst_ni`；
- 只允许一个计算事务在途；
- 不包含CDC、异步FIFO、中断、8x8和12位模式。

## 3. 顶层模块边界

计划新增顶层：

```systemverilog
module axi_precoder_wrapper (...);
```

顶层包含三组接口：

1. AXI4-Stream slave：输入用户复数符号；
2. AXI4-Stream master：输出天线复数结果；
3. AXI4-Lite slave：配置矩阵、提交Bank、读取状态和计数器。

第一版不使用AXI transaction ID。当前核心只有一个事务在途，因此输出按输入顺序返回。

## 4. AXI4-Stream输入协议

### 4.1 信号

| 信号 | 方向 | 位宽 | 含义 |
|---|---|---:|---|
| `s_axis_tdata` | 输入 | 32 | 一个复数输入符号 |
| `s_axis_tkeep` | 输入 | 4 | 有效字节，合法值必须为 `4'b1111` |
| `s_axis_tvalid` | 输入 | 1 | 输入有效 |
| `s_axis_tready` | 输出 | 1 | wrapper可以接收输入 |
| `s_axis_tlast` | 输入 | 1 | 输入向量的最后一拍 |

数据布局固定为：

```text
s_axis_tdata[31:16] = signed real Q14
s_axis_tdata[15:0]  = signed imag Q14
```

### 4.2 向量边界

- 一个输入向量固定包含4拍；
- 第0、1、2拍的 `TLAST` 必须为0；
- 第3拍的 `TLAST` 必须为1；
- 只有 `TVALID && TREADY` 时才接收一拍；
- `TVALID && !TREADY` 时，发送方必须保持 `TDATA/TKEEP/TLAST` 稳定；
- wrapper不得在核心不能接收时提前吞掉输入数据。

`TLAST`提前或缺失时，wrapper仍把4拍数据送入核心，使行为与当前
`precoder_core` 保持一致，同时锁存对应错误状态。

`TKEEP != 4'b1111` 时仍完成AXI握手并记录错误；该拍 `TDATA` 按原值送入核心，
软件和验证环境不得把该事务视为合法计算结果。

### 4.3 核心映射

```text
in_valid_i = s_axis_tvalid
s_axis_tready = in_ready_o
in_real_i = s_axis_tdata[31:16]
in_imag_i = s_axis_tdata[15:0]
in_last_i = s_axis_tlast
```

## 5. AXI4-Stream输出协议

### 5.1 信号

| 信号 | 方向 | 位宽 | 含义 |
|---|---|---:|---|
| `m_axis_tdata` | 输出 | 32 | 一个复数天线输出 |
| `m_axis_tkeep` | 输出 | 4 | 固定为 `4'b1111` |
| `m_axis_tvalid` | 输出 | 1 | 输出有效 |
| `m_axis_tready` | 输入 | 1 | 下游可以接收 |
| `m_axis_tlast` | 输出 | 1 | 输出向量的最后一拍 |
| `m_axis_tuser` | 输出 | 11 | 天线编号、饱和标志和矩阵版本 |

数据布局固定为：

```text
m_axis_tdata[31:16] = signed real Q14
m_axis_tdata[15:0]  = signed imag Q14

m_axis_tuser[1:0]   = antenna_index
m_axis_tuser[2]     = saturated
m_axis_tuser[10:3]  = matrix_version
```

### 5.2 输出规则

- 一个输出向量固定包含4拍，天线编号依次为0、1、2、3；
- 只有天线3对应的拍允许 `TLAST=1`；
- `TVALID && !TREADY` 时，`TDATA/TKEEP/TLAST/TUSER` 必须保持稳定；
- wrapper不增加输出重排序，不缓存第二个计算事务；
- 输出反压直接传递给 `precoder_core.out_ready_i`。

### 5.3 核心映射

```text
m_axis_tvalid = out_valid_o
out_ready_i = m_axis_tready
m_axis_tdata = {out_real_o, out_imag_o}
m_axis_tlast = out_last_o
m_axis_tuser = {out_version_o, out_saturated_o, out_ant_idx_o}
```

## 6. AXI4-Lite协议

### 6.1 基本要求

- 地址宽度32位，数据宽度32位；
- 支持单拍读写，不支持burst；
- 同时最多保留一个未完成读事务和一个未完成写事务；
- AW和W通道可以任意先后到达，wrapper必须分别锁存后再执行写操作；
- `BVALID && !BREADY` 时必须保持 `BRESP` 稳定；
- `RVALID && !RREADY` 时必须保持 `RDATA/RRESP` 稳定；
- 只支持32位对齐地址；
- 矩阵写要求 `WSTRB=4'b1111`；
- 成功返回 `OKAY`，非法地址或非法操作返回 `SLVERR`。

### 6.2 寄存器表

| 地址 | 名称 | 属性 | 定义 |
|---:|---|---|---|
| `0x000` | `IP_ID` | RO | 固定为 `32'h4D50_5243`，ASCII `MPRC` |
| `0x004` | `IP_VERSION` | RO | 第一版固定为 `32'h0001_0000` |
| `0x008` | `CONTROL` | WO | bit0清性能计数器，bit1清错误状态，写1产生单周期脉冲 |
| `0x00C` | `STATUS` | RO | 核心状态与Bank完整状态 |
| `0x010` | `COMMIT` | WO | 提交矩阵Bank和版本 |
| `0x014` | `ACTIVE_INFO` | RO | 当前Bank、版本和pending信息 |
| `0x018` | `ERROR_STATUS` | RO/W1C | wrapper与核心错误锁存 |
| `0x020` | `CYCLE_COUNT` | RO | 复位后运行周期数 |
| `0x024` | `INPUT_VECTOR_COUNT` | RO | 已接收完整输入向量数 |
| `0x028` | `OUTPUT_VECTOR_COUNT` | RO | 已完成输出向量数 |
| `0x02C` | `INPUT_STALL_COUNT` | RO | `s_axis_tvalid && !s_axis_tready` 周期数 |
| `0x030` | `OUTPUT_STALL_COUNT` | RO | `m_axis_tvalid && !m_axis_tready` 周期数 |
| `0x034` | `SATURATION_COUNT` | RO | 完成握手且饱和的输出拍数 |
| `0x038` | `CFG_WRITE_COUNT` | RO | 成功写入的矩阵系数数 |
| `0x03C` | `COMMIT_COUNT` | RO | 成功接受的commit数 |
| `0x100`～`0x13C` | `BANK0_MATRIX` | WO | Bank0的16个复数系数 |
| `0x200`～`0x23C` | `BANK1_MATRIX` | WO | Bank1的16个复数系数 |

所有计数器为32位无符号回绕计数器。第一版不产生计数器溢出中断。

### 6.3 STATUS

```text
bit 0     busy
bit 1     matrix_complete
bit 2     commit_pending
bit 3     active_bank
bit 4     bank0_complete
bit 5     bank1_complete
bits31:6  reserved, read as zero
```

### 6.4 COMMIT

```text
bit 0      target_bank
bits 7:1   reserved, write as zero
bits 15:8  matrix_version
bits 30:16 reserved, write as zero
bit 31     request
```

写入时只有 `request=1` 才执行提交。目标Bank必须完整、符合核心当前Bank规则，
且核心能够接受commit。成功时向核心产生一次 `commit_valid_i` 握手并返回 `OKAY`；
否则不改变核心状态并返回 `SLVERR`。

### 6.5 ACTIVE_INFO

```text
bit 0      active_bank
bit 1      commit_pending
bits 9:2   active_version
bits31:10  reserved, read as zero
```

### 6.6 ERROR_STATUS

```text
bit 0  core_protocol_error
bit 1  input_early_tlast
bit 2  input_missing_tlast
bit 3  input_invalid_tkeep
bit 4  illegal_matrix_write
bit 5  illegal_commit
bit 6  axi_decode_error
bit 7  axi_alignment_or_strobe_error
bits31:8 reserved
```

错误位为sticky状态，置位后保持到 `aresetn=0`、写 `CONTROL.clear_errors=1`，
或对 `ERROR_STATUS` 对应位执行W1C清除。多个错误可以同时置位。

### 6.7 矩阵地址窗口

每个Bank包含16个32位系数，地址计算为：

```text
index = row * 4 + column
bank0_address = 0x100 + index * 4
bank1_address = 0x200 + index * 4
```

系数数据布局为：

```text
WDATA[31:16] = signed coefficient_real Q14
WDATA[15:0]  = signed coefficient_imag Q14
```

矩阵窗口第一版为只写窗口，不提供矩阵回读。读取矩阵窗口返回 `SLVERR`。
当核心 `cfg_ready_o=0` 时，写操作不进入核心，返回 `SLVERR` 并置位
`illegal_matrix_write`。

## 7. 复位语义

- `aresetn` 为低时，wrapper和 `precoder_core` 同时复位；
- 所有AXI `READY/VALID` 输出回到协议允许的空闲状态；
- 未完成AXI-Lite读写响应被取消；
- 未完成输入或输出向量被取消；
- 矩阵完整标志、Bank版本、错误状态和性能计数器清零；
- 复位释放后，不得输出复位前事务的残留数据。

第一版禁止只复位wrapper而不复位核心。

## 8. 性能与背压约束

- wrapper不得在AXI-Stream正常传输路径中人为插入气泡；
- 输入吞吐率受 `precoder_core.in_ready_o` 限制；
- 输出吞吐率受核心输出状态和下游 `m_axis_tready` 限制；
- 输出反压期间不得接受会超过核心容量的新事务；
- 第一版不承诺多个输入向量并行在途；
- 性能报告必须同时给出理论周期数、输入stall和输出stall实测值。

## 9. 下一阶段RTL拆分

下一阶段计划新增：

```text
rtl/axi_stream_input.sv
rtl/axi_stream_output.sv
rtl/axi_lite_regs.sv
rtl/performance_counters.sv
rtl/axi_precoder_wrapper.sv
```

是否合并子模块可以根据实现复杂度调整，但外部协议和寄存器地址不得静默改变。

## 10. 本阶段验收标准

- AXI wrapper与 `precoder_core` 的边界明确；
- 输入和输出数据位序唯一且无歧义；
- 4拍向量和 `TLAST` 规则明确；
- `TUSER` 中天线、饱和和版本字段明确；
- AXI-Lite AW/W独立通道行为明确；
- 矩阵地址、Bank、行列和复数数据映射明确；
- commit成功和失败条件明确；
- 错误位清除方式和性能计数方式明确；
- reset、背压和非法访问行为明确；
- 8x8、12位、CDC、中断和多事务并发明确排除在第一版之外。

满足以上条件后，new第2阶段完成，下一阶段进入 `axi_precoder_wrapper` RTL实现。
