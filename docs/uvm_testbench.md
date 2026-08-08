# new第5阶段：UVM AXI验证平台

## 阶段目标

本阶段为 `axi_precoder_wrapper` 建立最小可运行的UVM 1.2验证平台。重点是形成可复用的transaction、sequencer、driver、monitor、agent、environment和test层次，并完成第一条端到端UVM用例。

完整位精确scoreboard、矩阵版本tracker和Python双参考模型属于new第6阶段，不在本阶段重复实现。

## 文件结构

```text
tb/uvm/
├── axi_stream_if.sv       AXI4-Stream SystemVerilog interface
├── axi_lite_if.sv         AXI4-Lite SystemVerilog interface
├── precoder_uvm_pkg.sv    UVM transaction、agent、sequence、env和test
└── tb_precoder_uvm.sv     DUT顶层、时钟复位和virtual interface配置
```

服务器运行脚本：

```text
sim/run_uvm.sh
```

## UVM组件层次

```text
uvm_test_top (precoder_base_test)
└── env (precoder_env)
    ├── lite_agent
    │   ├── sequencer
    │   ├── driver
    │   └── monitor
    ├── stream_in_agent
    │   ├── sequencer
    │   ├── driver
    │   └── monitor
    ├── stream_out_agent
    │   ├── ready driver
    │   └── monitor
    └── output_fifo
```

## Transaction

### axi_lite_item

包含读写类型、地址、写数据、WSTRB、AW/W先后顺序、读回数据和AXI响应。driver根据 `w_first` 覆盖AW先到和W先到两种合法顺序。

### axi_stream_in_item

表示一拍输入复数，包含16位有符号实部、16位有符号虚部、TKEEP和TLAST。

### axi_stream_out_item

由输出monitor生成，包含输出实部、虚部、天线编号、饱和标志、矩阵版本和TLAST。

## 第一条UVM测试

`precoder_base_test` 执行以下流程：

1. 等待低有效复位释放；
2. 启动 `matrix_config_sequence`，通过AXI-Lite向Bank0写入4x4单位矩阵；
3. 写地址和写数据交替采用AW先到、W先到；
4. 启动 `input_vector_sequence`，发送4拍Q14输入向量；
5. 输出agent持续接收AXI4-Stream结果；
6. 从analysis FIFO取出4个输出transaction；
7. 检查天线编号为0、1、2、3；
8. 检查只有第4拍TLAST为1；
9. 检查输出矩阵版本为复位默认值0；
10. 通过UVM objection正常结束测试。

## 运行方法

服务器项目根目录执行一行命令：

```bash
bash sim/run_uvm.sh
```

通过标志包括：

```text
UVM AXI smoke test received 4 output beats
UVM_ERROR : 0
UVM_FATAL : 0
PASS: UVM AXI smoke test completed
```

编译日志位于 `build/vcs/uvm/compile.log`，运行日志位于 `build/vcs/uvm/run.log`。
