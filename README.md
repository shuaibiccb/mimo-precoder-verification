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
- 第三阶段：4x4 预编码核心和基础自检 testbench；
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

## 下一步

第三阶段将使用 4 路并行复数 MAC 实现 4x4 预编码核心，加入输入缓存、计算控制状态机和简单 `valid/ready` 流接口，并使用当前三个单元回归作为底层保护。
