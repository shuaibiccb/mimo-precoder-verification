# new第8阶段：UVM随机回归与通用双参考模型

## 完成内容

第8阶段移除了scoreboard对单位矩阵的依赖。AXI-Lite monitor现在重组AW、W和B通道，向scoreboard发布完整的成功写事务；scoreboard据此维护Bank0和Bank1两套4×4复数Q14矩阵。

第四个输入beat握手时，scoreboard锁存活动Bank和版本，并同时生成：

- Q14位精确结果：复数乘加、Q28到Q14舍入、16位饱和；
- 浮点结果：系数和输入反量化后的复数矩阵向量乘法，用于EVM分析。

输出逐beat检查实部、虚部、天线编号、TLAST、饱和标志和矩阵版本。commit发生在向量未完成期间时，参考模型将新Bank/版本延迟到当前向量最后一个输出之后生效。

## 随机场景

`precoder_random_test`包含：

- Bank0和Bank1的任意复数矩阵；
- 正数、负数、最大值和最小值输入；
- 随机输入间隔；
- 35%概率的输出反压；
- Bank0到Bank1、Bank1到Bank0两次忙时commit；
- 正常输出和饱和输出；
- 每个seed独立可复现。

测试至少观察到两次向量未完成期间的commit，否则主动失败。

## 运行方法

基础smoke test：

```bash
bash sim/run_uvm.sh
```

单个随机seed：

```bash
UVM_TEST=precoder_random_test SEED=20260808 VECTORS=12 bash sim/run_uvm.sh
```

多seed回归：

```bash
RUNS=20 VECTORS=12 BASE_SEED=20260808 bash sim/run_uvm_regression.sh
```

单seed日志默认位于 `build/vcs/uvm/run.log`，批量日志位于 `build/vcs/uvm/regression/seed_<seed>.log`。

## 验证结果

2026-08-08在VCS O-2018.09-SP1和UVM 1.2上完成：

```text
PASS: 20 UVM random seeds completed (240 vectors)
UVM_ERROR : 0
UVM_FATAL : 0
```

20个seed共验证240个任意矩阵输入向量和40次忙时commit。位精确模型全部匹配RTL。

浮点EVM不是RTL通过条件：位精确模型用于判断实现正确性，浮点模型用于观察定点量化和饱和损失。压力场景故意使用大系数和极值输入，因此部分向量的EVM较高；日志同时报告饱和输出数量和最大EVM，便于后续最坏数值场景分析。
