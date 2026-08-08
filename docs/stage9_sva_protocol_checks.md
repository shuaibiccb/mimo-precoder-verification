# new第9阶段：SVA断言与协议、内部控制检查

## 阶段目标

本阶段把SVA正式接入UVM随机回归。第8阶段的scoreboard负责判断数值结果是否正确；本阶段的断言负责检查握手协议、输出事务边界、矩阵版本一致性和双Bank安全切换。

## 检查范围

`tb/assertions/axi_precoder_sva.sv`绑定到`axi_precoder_wrapper`，检查：

- AXI-Stream输入和输出在反压期间保持payload与元信息稳定；
- 输出TKEEP、TLAST、天线编号和事务内版本一致；
- AXI-Lite B/R响应必须对应已经接受的AW/W或AR请求；
- B/R响应码只能是OKAY或SLVERR；
- 合法UVM输入必须是四拍向量，最后一拍才允许TLAST。

`tb/assertions/precoder_core_sva.sv`绑定到`precoder_core`，检查：

- MAC只在计算事务中使能，清零只发生在新向量开始；
- 一个向量计算期间使用的Bank和版本保持不变；
- 输出版本必须来自当前事务锁存的版本；
- 输出最后一拍必须是天线3；
- commit只能作用于已完成且非active的Bank；
- 忙时commit必须保持pending到安全边界；
- 完成的向量数不能超过已接受的向量数。

AXI-Lite driver增加了读响应反压。随机测试还会在前一个向量尚未完成时提交下一个输入，从而实际触发输入和输出反压场景。AW/W/AR稳定性属于主设备侧约束，不在DUT断言得分中重复统计；monitor仍检查每个响应都有对应请求。

## 回归命令

单个seed：

```bash
SVA_COVERAGE=1 UVM_TEST=precoder_random_test SEED=20260808 VECTORS=12 bash sim/run_uvm.sh
```

20个seed并生成断言覆盖率报告：

```bash
RUNS=20 VECTORS=12 BASE_SEED=20260808 bash sim/run_uvm_regression.sh
```

报告入口：

```text
build/vcs/uvm/regression/sva_report/dashboard.html
```

## 正式回归结果

- 20个随机seed全部通过；
- 共检查240个随机矩阵向量和40次忙时commit；
- 每个seed均完成Bank0到Bank1、Bank1到Bank0切换；
- 11个cover property全部命中；
- URG断言覆盖率为97.30%；
- `UVM_ERROR = 0`、`UVM_FATAL = 0`、SVA failure为0。

## 验收标准

- 所有seed无UVM或SVA错误；
- 每个seed观察到至少2次忙时commit和2次Bank切换；
- AXI和core checker的cover property全部命中；
- URG断言覆盖率达到90%以上。

