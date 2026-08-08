# RTL接口名称参考表

本文档对应当前 rtl 目录中的全部SystemVerilog模块。默认参数为：数据16位Q14、累加器40位、矩阵版本8位。

## 1. 顶层 axi_precoder_wrapper

### 参数

| 名称 | 类型 | 默认值 | 作用 |
|---|---|---:|---|
| DATA_WIDTH | int | 16 | 实部/虚部数据位宽 |
| ACC_WIDTH | int | 40 | MAC累加器位宽 |
| VERSION_WIDTH | int | 8 | 矩阵版本号位宽 |

### 时钟与复位

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| aclk | 输入 | 1 | AXI和计算核心共用时钟 |
| aresetn | 输入 | 1 | 低有效异步复位，同时复位wrapper和核心 |

### 运行时模式

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| mode_8x8 | 内部 | 1 | AXI-Lite `MODE`寄存器镜像；0=4x4，1=8x8 |
| format_12 | 内部 | 1 | AXI-Lite `FORMAT`寄存器镜像；0=Q1.14，1=Q1.10 |
| truncate_mode | 内部 | 1 | AXI-Lite `QUANT_CTRL` bit0；1=直接截断，0=最近值舍入 |
| wrap_mode | 内部 | 1 | AXI-Lite `QUANT_CTRL` bit1；1=回绕，0=饱和 |

### AXI4-Stream输入

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| s_axis_tdata | 输入 | 32 | [31:16]实部，[15:0]虚部 |
| s_axis_tkeep | 输入 | 4 | 有效字节，合法值为 4'b1111 |
| s_axis_tvalid | 输入 | 1 | 上游声明数据有效 |
| s_axis_tready | 输出 | 1 | wrapper可以接收数据 |
| s_axis_tlast | 输入 | 1 | 4x4为第4拍、8x8为第8拍的最后一拍 |

### AXI4-Stream输出

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| m_axis_tdata | 输出 | 32 | [31:16]实部，[15:0]虚部 |
| m_axis_tkeep | 输出 | 4 | 固定为 4'b1111 |
| m_axis_tvalid | 输出 | 1 | 输出数据有效 |
| m_axis_tready | 输入 | 1 | 下游可以接收数据 |
| m_axis_tlast | 输出 | 1 | 4x4天线3、8x8天线7输出拍为1 |
| m_axis_tuser | 输出 | 12 | [1:0]天线编号低位，[2]饱和，[10:3]版本，[11]天线编号高位 |

### AXI4-Lite写通道

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| s_axil_awaddr | 输入 | 32 | 写地址，4字节对齐 |
| s_axil_awvalid | 输入 | 1 | 写地址有效 |
| s_axil_awready | 输出 | 1 | 接收写地址 |
| s_axil_wdata | 输入 | 32 | 写数据 |
| s_axil_wstrb | 输入 | 4 | 写字节使能，矩阵写必须全1 |
| s_axil_wvalid | 输入 | 1 | 写数据有效 |
| s_axil_wready | 输出 | 1 | 接收写数据 |
| s_axil_bresp | 输出 | 2 | 00=OKAY，10=SLVERR |
| s_axil_bvalid | 输出 | 1 | 写响应有效 |
| s_axil_bready | 输入 | 1 | 主机接收写响应 |

### AXI4-Lite读通道

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| s_axil_araddr | 输入 | 32 | 读地址，4字节对齐 |
| s_axil_arvalid | 输入 | 1 | 读地址有效 |
| s_axil_arready | 输出 | 1 | 接收读地址 |
| s_axil_rdata | 输出 | 32 | 读返回数据 |
| s_axil_rresp | 输出 | 2 | 00=OKAY，10=SLVERR |
| s_axil_rvalid | 输出 | 1 | 读响应有效 |
| s_axil_rready | 输入 | 1 | 主机接收读响应 |

## 2. AXI封装内部模块

### axi_stream_input

文件：rtl/axi_stream_input.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| aclk / aresetn | 输入 | 1 / 1 | 时钟和低有效异步复位 |

| s_axis_tdata | 输入 | 32 | AXI输入复数 |
| s_axis_tkeep | 输入 | 4 | AXI有效字节 |
| s_axis_tvalid / s_axis_tready | 输入/输出 | 1 / 1 | AXI输入握手 |
| s_axis_tlast | 输入 | 1 | 输入尾标志 |
| core_valid_o / core_ready_i | 输出/输入 | 1 / 1 | 核心输入握手 |
| core_real_o / core_imag_o | 输出 | 16 signed | 送给核心的复数 |
| core_last_o | 输出 | 1 | 送给核心的尾标志 |
| input_vector_pulse_o | 输出 | 1 | 当前模式完整输入向量事件 |
| early_tlast_pulse_o | 输出 | 1 | 提前TLAST错误事件 |
| missing_tlast_pulse_o | 输出 | 1 | 缺失TLAST错误事件 |
| invalid_tkeep_pulse_o | 输出 | 1 | 非法TKEEP错误事件 |

### axi_stream_output

文件：rtl/axi_stream_output.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| core_valid_i / core_ready_o | 输入/输出 | 1 / 1 | 核心输出握手 |
| core_real_i / core_imag_i | 输入 | 16 signed | 核心输出复数 |
| core_ant_idx_i | 输入 | 3 | 天线编号 |
| core_last_i | 输入 | 1 | 核心尾标志 |
| core_saturated_i | 输入 | 1 | 饱和标志 |
| core_version_i | 输入 | 8 | 矩阵版本 |
| m_axis_tdata | 输出 | 32 | 打包后的AXI输出 |
| m_axis_tkeep | 输出 | 4 | 固定全1 |
| m_axis_tvalid / m_axis_tready | 输出/输入 | 1 / 1 | AXI输出握手 |
| m_axis_tlast | 输出 | 1 | AXI输出尾标志 |
| m_axis_tuser | 输出 | 12 | 天线、饱和、版本元数据 |
| output_vector_pulse_o | 输出 | 1 | 完整输出向量事件 |
| saturation_pulse_o | 输出 | 1 | 饱和输出事件 |

### performance_counters

文件：rtl/performance_counters.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| aclk / aresetn | 输入 | 1 / 1 | 时钟和复位 |
| clear_i | 输入 | 1 | 清零所有计数器 |
| input_vector_i / output_vector_i | 输入 | 1 / 1 | 输入/输出向量事件 |
| input_stall_i / output_stall_i | 输入 | 1 / 1 | 输入/输出阻塞事件 |
| saturation_i | 输入 | 1 | 饱和事件 |
| cfg_write_i / commit_i | 输入 | 1 / 1 | 配置写和commit事件 |
| cycle_count_o | 输出 | 32 | 周期计数 |
| input_vector_count_o | 输出 | 32 | 输入向量计数 |
| output_vector_count_o | 输出 | 32 | 输出向量计数 |
| input_stall_count_o | 输出 | 32 | 输入阻塞计数 |
| output_stall_count_o | 输出 | 32 | 输出阻塞计数 |
| saturation_count_o | 输出 | 32 | 饱和计数 |
| cfg_write_count_o | 输出 | 32 | 配置写计数 |
| commit_count_o | 输出 | 32 | commit计数 |

## 3. 原有计算核心模块

### precoder_core

文件：rtl/precoder_core.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| clk_i / rst_ni | 输入 | 1 / 1 | 时钟和低有效异步复位 |
| cfg_valid_i / cfg_ready_o | 输入/输出 | 1 / 1 | 矩阵系数写握手 |
| cfg_bank_i | 输入 | 1 | 目标Bank |
| cfg_row_i / cfg_col_i | 输入 | 3 / 3 | 4x4或8x8行列索引 |
| cfg_real_i / cfg_imag_i | 输入 | 16 signed / 16 signed | Q14复数系数 |
| bank_complete_o | 输出 | 2 | 两个Bank完整标志 |
| matrix_complete_o | 输出 | 1 | 当前活动Bank完整 |
| commit_valid_i / commit_ready_o | 输入/输出 | 1 / 1 | Bank版本提交握手 |
| commit_bank_i | 输入 | 1 | 目标Bank |
| commit_version_i | 输入 | 8 | 新矩阵版本 |
| commit_pending_o | 输出 | 1 | 忙时等待提交 |
| active_bank_o | 输出 | 1 | 当前活动Bank |
| active_version_o | 输出 | 8 | 当前矩阵版本 |
| in_valid_i / in_ready_o | 输入/输出 | 1 / 1 | 输入符号握手 |
| in_real_i / in_imag_i | 输入 | 16 signed / 16 signed | 输入复数Q14 |
| in_last_i | 输入 | 1 | 输入尾标志 |
| out_valid_o / out_ready_i | 输出/输入 | 1 / 1 | 输出结果握手 |
| out_real_o / out_imag_o | 输出 | 16 signed / 16 signed | 输出复数Q14 |
| out_ant_idx_o | 输出 | 3 | 天线编号0～3或0～7 |
| out_last_o | 输出 | 1 | 输出尾标志 |
| out_saturated_o | 输出 | 1 | 饱和标志 |
| out_version_o | 输出 | 8 | 本事务矩阵版本 |
| busy_o | 输出 | 1 | 核心忙标志 |
| protocol_error_o | 输出 | 1 | 输入TLAST协议错误 |

### matrix_storage

文件：rtl/matrix_storage.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| clk_i / rst_ni | 输入 | 1 / 1 | 时钟和复位 |
| write_en_i | 输入 | 1 | 写入系数 |
| write_bank_i | 输入 | 1 | 写入Bank |
| write_row_i / write_col_i | 输入 | 3 / 3 | 写入行列 |
| write_real_i / write_imag_i | 输入 | 16 signed / 16 signed | 写入复数系数 |
| read_bank_i | 输入 | 1 | 读取Bank |
| read_row_group_i / read_col_i | 输入 | 1 / 3 | 8x8行组（0～3/4～7）和列 |
| row0_real_o～row3_real_o | 输出 | 16 signed | 四行实部系数 |
| row0_imag_o～row3_imag_o | 输出 | 16 signed | 四行虚部系数 |
| complete_o | 输出 | 2 | 两个Bank完整状态 |

### symbol_buffer

文件：rtl/symbol_buffer.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| clk_i / rst_ni | 输入 | 1 / 1 | 时钟和复位 |
| write_en_i | 输入 | 1 | 写入符号 |
| write_idx_i | 输入 | 2 | 写入索引0～3 |
| write_real_i / write_imag_i | 输入 | 16 signed / 16 signed | 输入复数Q14 |
| read_idx_i | 输入 | 2 | 读取索引 |
| read_real_o / read_imag_o | 输出 | 16 signed / 16 signed | 当前符号复数 |

### complex_mac

文件：rtl/complex_mac.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| clk_i / rst_ni | 输入 | 1 / 1 | 时钟和复位 |
| clear_i | 输入 | 1 | 清零累加器 |
| enable_i | 输入 | 1 | 允许乘累加 |
| a_real_i / a_imag_i | 输入 | 16 signed | 矩阵系数 |
| b_real_i / b_imag_i | 输入 | 16 signed | 输入符号 |
| acc_real_o / acc_imag_o | 输出 | 40 signed | Q28累加结果 |

### complex_mult

文件：rtl/complex_mult.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| a_real_i / a_imag_i | 输入 | 16 signed | 复数A |
| b_real_i / b_imag_i | 输入 | 16 signed | 复数B |
| p_real_o / p_imag_o | 输出 | 33 signed | Q28复数乘积 |

### fixed_round_sat

文件：rtl/fixed_round_sat.sv

| 接口名 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| acc_i | 输入 | 40 signed | Q28累加结果 |
| data_o | 输出 | 16 signed | 舍入缩放后的Q14结果 |
| saturated_o | 输出 | 1 | 是否发生饱和 |

## 4. 命名与握手速查

| 后缀/字段 | 含义 |
|---|---|
| _i | 模块输入 |
| _o | 模块输出 |
| valid && ready | 一次握手/传输成立 |
| last | 向量最后一拍 |
| real / imag | 复数实部/虚部 |
| cfg | 矩阵系数配置 |
| commit | Bank和版本提交 |
| active | 当前使用的Bank或版本 |
| pending | 等待安全边界生效 |
| pulse | 单周期事件 |
| count | 计数器数值 |

核心握手信号分别是：cfg_valid_i/cfg_ready_o、commit_valid_i/commit_ready_o、in_valid_i/in_ready_o、out_valid_o/out_ready_i。AXI输入握手是 s_axis_tvalid && s_axis_tready，AXI输出握手是 m_axis_tvalid && m_axis_tready。valid为1且ready为0时，发送方必须保持数据和附加信息稳定。
