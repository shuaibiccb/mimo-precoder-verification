# 可重配置 MIMO 预编码加速器

本项目用于从零实现一个位精确、可重配置的 MIMO 预编码加速器，并为其搭建 SystemVerilog/UVM 验证环境。核心计算为复数矩阵向量乘法：

```text
x = W @ s
```

其中，`W` 是预编码矩阵，`s` 是用户或数据层符号向量，`x` 是各发送天线的输出向量。

## 第一阶段内容

当前第一阶段已经完成，建立了后续 RTL 设计和验证共同遵循的可执行规格，包括：

- 4x4 复数矩阵向量运算；
- NumPy 浮点参考模型；
- 有符号、位精确的定点参考模型；
- 确定性随机测试向量生成器；
- 量化、补码、复数乘法、累加、舍入和饱和处理；
- 单元测试和 10,000 组随机 4x4 用例测试；
- 可直接提供给 RTL testbench 使用的 JSON 测试向量。

`docs/specification.md` 和 `model/fixed_model.py` 共同定义第一版 RTL 的黄金行为。后续 RTL 与参考模型不一致时，应先根据规格判断设计或模型是否存在问题。

## 定点格式

第一版模型采用以下配置：

- 符号实部和虚部：16 位有符号数，14 个小数位；
- 矩阵系数实部和虚部：16 位有符号数，14 个小数位；
- 标量乘积：32 位，28 个小数位；
- 复数乘积：33 位，28 个小数位；
- 累加器实部和虚部：40 位，28 个小数位；
- 输出实部和虚部：16 位，14 个小数位；
- 舍入方式：最近值舍入，恰好半值时远离零；
- 溢出方式：输出饱和，不允许静默回绕。

详细约定参见 `docs/specification.md` 和 `docs/fixed_point.md`。

## 环境要求

- Python 3.10 或更高版本
- NumPy
- Icarus Verilog 12 或其他支持 SystemVerilog 2012 的仿真器

Python 依赖通过 `requirements.txt` 安装。Windows 本地 RTL 回归脚本会优先从 `PATH` 查找 `iverilog` 和 `vvp`，也会自动识别 winget 默认安装位置 `C:\iverilog\bin`。

## 快速开始

安装项目依赖：

```powershell
python -m pip install -r requirements.txt
```

在项目根目录运行全部自动测试：

```powershell
python -m unittest discover -s model/tests -v
```

生成 100 组固定随机种子的 RTL 测试向量：

```powershell
python -m model.generate_vectors --count 100 --seed 20260730 --output build/vectors.json
```

分别运行浮点模型和位精确定点模型示例：

```powershell
python -m model.floating_model
python -m model.fixed_model
```

## 目录结构

```text
mimo-precoder/
├── docs/                 项目规格、定点格式和验证计划
├── model/                浮点模型、位精确模型和向量生成器
│   └── tests/            模型自动测试
├── rtl/                  后续阶段的 RTL 代码
├── tb/                   后续阶段的 UVM 验证环境
├── sim/                  仿真文件清单和运行脚本
├── synth/                综合脚本与约束
├── reports/              覆盖率、回归和综合报告
├── scripts/              项目辅助脚本
└── build/                自动生成的测试向量等临时产物
```

## 项目路线

- 第一阶段：规格、浮点模型、位精确定点模型和测试，已完成；
- 第二阶段：复数乘法器、复数 MAC、舍入与饱和 RTL，已完成；
- 第三阶段：4x4 预编码核心和基础自检 testbench，已完成；
- 第四阶段：流式接口、配置接口和矩阵双缓冲；
- 第五阶段：UVM、SVA、功能覆盖率、随机回归和 PPA 分析；
- 扩展阶段：4x4/8x8 动态配置、EVM 分析和最坏定点误差搜索。

## 当前验证结果

第一阶段共包含 13 项自动测试，并使用固定随机种子完成 10,000 组 4x4 随机矩阵向量测试。测试覆盖：

- 正负数与补码边界；
- 半值舍入；
- 正向和负向饱和；
- 复数乘法；
- 单位矩阵和手工可计算场景；
- 输出范围与有限值检查；
- 测试向量的随机种子可复现性。

当前测试结果为：

```text
Ran 13 tests
OK
```

## 第二阶段 RTL 单元回归

第二阶段已经实现并独立验证以下三个基础 RTL 模块：

1. `complex_mult.sv`：位精确复数乘法器；
2. `complex_mac.sv`：带清零和使能控制的复数累加器；
3. `fixed_round_sat.sv`：定点舍入与饱和输出模块。

本地运行全部 RTL 单元测试：

```powershell
python -m scripts.run_rtl_tests
```

调整随机用例数量和随机种子：

```powershell
python -m scripts.run_rtl_tests --random-count 10000 --seed 20260803
```

脚本会自动生成黄金向量、调用 Icarus Verilog 编译三个 testbench，并自动报告 PASS/FAIL。在安装了 VCS 的 Linux 服务器上可以运行：

```bash
bash sim/run_vcs.sh
```

运行 VCS 脚本前，需要保证服务器已经加载可用的 VCS 环境，并且 `vcs -ID` 能正常执行。若命令提示找不到 `vcs1`，说明 `VCS_HOME` 指向了不完整或错误的安装目录，应先修复服务器工具环境。

## 第三阶段 4x4 预编码核心

第三阶段使用 4 路并行复数 MAC 实现完整的 4x4 预编码计算：

- `matrix_storage.sv` 保存 16 个复数矩阵系数并跟踪配置完整性；
- `symbol_buffer.sv` 缓存一个包含 4 个复数符号的输入向量；
- `precoder_core.sv` 用 4 个计算周期并行完成 4 根天线的乘累加；
- 使用简单配置接口和 `valid/ready` 输入输出接口；
- 支持输入随机间隔、输出反压、异步复位取消和错误 `in_last` 检测；
- `tb_precoder_core.sv` 从 Python 黄金文件读取完整矩阵、符号和期望输出；
- `precoder_core_sva.sv` 提供输出稳定、末尾标志和复位行为断言。

统一命令会同时运行三个基础单元测试和预编码核心测试：

```powershell
python -m scripts.run_rtl_tests --random-count 1000 --seed 20260804
```

## 下一步

第四阶段已完成：矩阵存储支持 Bank0/Bank1 双缓冲、完整标志、版本号和原子 `commit`。事务开始时锁存 Bank 与版本，保证不会混用两代矩阵；忙期间提交会延迟到最后一个输出握手后生效。`tb_precoder_hot_update.sv` 覆盖输出反压期间更新 Bank1 的场景。testbench 支持 `FSDB`/`VCD` 波形，服务器运行 `WAVES=1 bash sim/run_vcs.sh` 可生成 FSDB，随后使用 Verdi 打开 `build/vcs/waves/*.fsdb`。

## 第五阶段：断言与覆盖率闭环

第五阶段扩充了四组流式/配置接口断言，并新增 `tb/coverage/precoder_core_coverage.sv`。覆盖率模型统计 Bank 配置、commit 上下文、版本更新、输出反压、饱和、协议错误、4 个天线输出及关键交叉场景。

服务器启用覆盖率回归：

```bash
COVERAGE=1 bash sim/run_vcs.sh
```

脚本会检查两个核心级 VDB 数据库并自动调用 URG，报告生成在 `build/vcs/coverage/report/dashboard.html`。当前先完成自检 testbench、SVA 和覆盖率闭环；AXI 接口加入后，再将现有 task 迁移为 UVM agent。

首轮覆盖率基线用于指导定向补测。当前热更新回归已扩展为 Bank0→Bank1 忙时提交、Bank1→Bank0 空闲回切及零/低非零/高非零版本覆盖，并从交叉覆盖中排除协议不可达的 `last` 组合。

## 第七阶段：综合与 PPA 基线

`synth/` 提供 Yosys 可综合性检查和 Design Compiler 工艺映射脚本，默认以 `precoder_core` 为顶层、100 MHz 为第一版时钟目标。Yosys 用于无工艺库的结构/资源基线；DC 必须通过 `DC_TARGET_LIBRARY` 指定服务器上的标准单元 `.db`，生成面积、时序、约束和资源报告。详细使用方法见 `docs/synthesis.md`。

## new第3阶段：AXI wrapper RTL

`axi_precoder_wrapper.sv` 在已验证的 `precoder_core` 外增加32位AXI4-Stream输入/输出和32位AXI4-Lite控制接口，核心内部的简单 `valid/ready` 接口保持不变。AXI-Lite寄存器模块支持矩阵配置、Bank commit、状态/错误读取、W1C清错和性能计数器；流接口模块检查4拍向量的 `TLAST/TKEEP` 并直接传递背压。接口细节见 `docs/axi_interface.md`，定向测试已加入服务器统一VCS回归。

## new第4阶段：定向AXI接口验证

新增 `tb/axi/tb_axi_precoder_stress.sv`，验证AXI-Lite读写响应在反压时保持稳定，覆盖复位取消、非对齐/非法地址、部分字节写、错误状态清除，以及AXI-Stream输出反压和元数据边界。该压力测试已纳入 `sim/run_vcs.sh`。

## new第5阶段：UVM AXI验证平台

`tb/uvm/` 提供基于UVM 1.2的AXI-Lite、AXI-Stream输入和AXI-Stream输出agent，以及基础environment和smoke test。测试通过AXI-Lite写入单位矩阵，发送4拍输入向量，并由输出monitor检查4个输出transaction的元数据。服务器执行 `bash sim/run_uvm.sh`，详细结构见 `docs/uvm_testbench.md`。

## new第6阶段：Scoreboard与双参考模型

UVM environment新增scoreboard，接收输入/输出monitor事务，使用Q14位精确参考规则逐拍比较结果，同时计算浮点EVM。阶段6日志必须包含 `UVM scoreboard checked 4 output beats` 且 `UVM_ERROR/UVM_FATAL`均为0。

## new第7阶段：SVA断言与覆盖率收敛

完整AXI wrapper已接入协议断言和功能覆盖模型，覆盖读写通道顺序与反压、流接口反压、非法TLAST/TKEEP、双Bank commit、忙期间pending、版本原子切换和饱和输出。服务器执行 `COVERAGE=1 bash sim/run_vcs.sh` 后，报告入口为 `build/vcs/coverage/report/dashboard.html`。当前干净回归达到功能覆盖95.83%、RTL模块行覆盖92.34%、条件覆盖86.71%和断言覆盖85.71%，详细结果与指标解释见 `docs/coverage_closure.md`。
