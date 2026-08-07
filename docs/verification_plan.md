# 验证计划框架

## 第一阶段模型测试

- 定点格式转换和二进制补码边界；
- 正数与负数的半值舍入；
- 正负边界值以及越界值的饱和处理；
- 纯实数、纯虚数和一般复数乘法；
- 单位矩阵、零矩阵、对角矩阵和随机矩阵；
- 使用相同随机种子时，测试向量可以稳定复现；
- 随机测试中的输出范围和 EVM 不变量检查。

## 后续 RTL 验证目标

- RTL 输出与 `model.fixed_model` 进行逐位精确比较；
- 输出发生反压时，数据和控制信息保持稳定；
- 分别在输入、计算、舍入和输出阶段施加复位；
- 检查向量长度和末尾标志是否正确；
- 在向量边界原子提交矩阵 Bank 切换；
- 检查输入向量与矩阵版本之间的因果关系；
- 检查延迟和吞吐率是否符合设计上限；
- 完成功能覆盖率和代码覆盖率闭环。

## 第二阶段 RTL 单元验证结果

第二阶段使用 Python 位精确模型生成独立黄金向量，并由 SystemVerilog testbench 自动判分：

- `tb_complex_mult.sv`：覆盖零、单位值、纯实/纯虚、最大最小值和随机复数乘法；
- `tb_complex_mac.sv`：覆盖异步复位、保持、清零优先级、单次累加和连续 4 次随机累加；
- `tb_fixed_round_sat.sv`：覆盖正负半值、正负饱和边界、40 位极值和随机累加器输入；
- `scripts/run_rtl_tests.py`：自动生成向量、编译、运行并汇总三个测试；
- `sim/run_vcs.sh`：用于服务器上的 VCS 兼容性回归。

默认随机规模下，三个模块合计检查 3531 个输入或时序检查点。最终交付回归使用 10000 个随机输入规模再次验证。

## 第三阶段核心级验证

核心测试由 5 个定向场景和可配置数量的随机场景组成：

- 零矩阵、单位矩阵、对角矩阵、单非零系数矩阵和饱和压力矩阵；
- 16 个矩阵地址全部写入并检查完整标志；
- 每个输入符号前插入确定性随机间隔；
- 每个输出施加 0～3 个周期的反压；
- 反压期间使用过程式检查保证 payload 稳定；
- 事务中途异步复位，检查事务取消和矩阵清空；
- 提前 `in_last`，检查粘滞协议错误标志；
- 每个输出的数值、饱和标志、天线编号和末尾标志逐项比较；
- 服务器 VCS 回归额外绑定端口级 SVA。

核心期望结果由 `precoder_fixed_int()` 独立生成，SystemVerilog testbench 不重复实现矩阵乘法算法。

## 第四阶段热更新验证

`tb_precoder_hot_update.sv` 在输出反压期间写入并提交 Bank1，检查第一个事务仍使用旧 Bank/版本，提交在最后一个输出握手后原子生效，第二个事务使用新 Bank 和版本 `8'h2A`。测试同时观察 `commit_pending_o`、`active_bank_o`、`active_version_o` 和 `out_version_o`。

## 波形导出

默认回归不生成波形。VCS 脚本设置 `WAVES=1` 时定义 `FSDB` 并加载 Verdi PLI，将波形写入 `build/vcs/waves/`；本地脚本使用 `--waves` 定义 `VCD`。Verdi 中建议观察状态机、Bank/版本信号、输入输出握手、索引计数器和累加结果。

## 第五阶段断言与覆盖率闭环

新增断言覆盖配置、输入、commit 和输出在 `valid && !ready` 时的 payload 稳定性，检查忙时活动 Bank 写保护、commit 目标合法性、pending commit 的事务边界以及 `out_last` 规则。功能覆盖率记录 Bank0/Bank1、完整状态、空闲/忙提交、版本更新、反压、饱和、协议错误、天线输出和关键交叉场景。

服务器运行 `COVERAGE=1 bash sim/run_vcs.sh` 生成 VDB 数据库并自动使用 `urg` 汇总 HTML 报告。脚本会在核心级 VDB 或 `dashboard.html` 缺失时失败退出。Windows 快速回归仍使用 Icarus，不编译 VCS 专用 covergroup。

## 第六阶段覆盖率驱动补测

根据首轮 URG 基线补充 Bank0→Bank1 忙时提交、Bank1→Bank0 空闲回切、空闲零版本提交和回切后的端到端结果检查。版本覆盖点按零、低非零和高非零三类建模；输出元数据交叉覆盖排除“天线0～2带 `last`”和“天线3不带 `last`”两类协议不可达组合，避免无意义 bin 人为拉低覆盖率。

## new第3阶段 AXI wrapper RTL验证

`tb/axi/tb_axi_precoder_wrapper.sv` 对第一版AXI封装执行定向自检，覆盖：

- AXI4-Lite AW/W通道以两种先后顺序独立到达；
- IP标识、状态、活动Bank、错误状态和性能计数器读取；
- 通过Bank0/Bank1地址窗口配置单位矩阵；
- AXI4-Stream 4拍输入输出、`TKEEP`、`TLAST`和`TUSER`映射；
- 输出反压期间payload和sideband稳定；
- 提前/缺失`TLAST`、非法`TKEEP`、非法commit和非法地址错误锁存；
- `ERROR_STATUS` W1C、性能计数器清零和Bank版本commit。

服务器执行 `bash sim/run_vcs.sh` 时会同时运行原有单元/核心回归和该wrapper测试。

## new第4阶段 定向AXI接口验证

`tb/axi/tb_axi_precoder_stress.sv` 在基础功能测试之外，增加以下协议压力场景：

- 复位期间取消未完成的AXI-Lite读写，并检查READY/VALID回到空闲状态；
- `BREADY=0`时保持`BVALID/BRESP`稳定；
- `RREADY=0`时保持`RVALID/RDATA/RRESP`稳定；
- 非对齐地址、部分`WSTRB`、未知寄存器和矩阵窗口读访问均返回`SLVERR`；
- 检查错误状态中的decode/alignment位，并通过CONTROL清错；
- AXI-Stream完整4拍向量、输出反压期间payload稳定以及天线编号/`TLAST`检查。

该测试与原有 `tb_axi_precoder_wrapper.sv` 一起由 `sim/run_vcs.sh` 自动编译运行。
