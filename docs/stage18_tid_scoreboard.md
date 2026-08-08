# new第18阶段：按事务 ID 的 scoreboard 跟踪

## 阶段目标

第17阶段已经验证单个向量内部的 `TID` 稳定以及输入到输出的端到端传递。本阶段把
scoreboard 的事务生命周期显式化：每个完整输入向量在接受时登记 `TID`，在最后一个
输出 beat 握手时完成登记，并检查重复接受、未知输出、重复完成和向量内 ID 变化。
这为后续真正支持多事务在途或乱序输出保留了验证接口，但当前 RTL 仍保持单事务架构。

## 实现

- `tb/uvm/precoder_uvm_pkg.sv` 增加 256 项 `outstanding_tid` 表；
- 增加 accepted/completed 计数以及 duplicate/unknown/mismatch 错误计数；
- 输出最后一拍清除对应 ID，允许同一 ID 在完成后再次使用；
- reset 通过虚拟 AXI-Stream 接口清空事务表和参考模型运行状态；
- 新增 `precoder_tid_scoreboard_test`，使用 4 个不同 ID、输出反压和完整向量回归。

## 验收标准

服务器执行：

```bash
UVM_TEST=precoder_tid_scoreboard_test VECTORS=4 SEED=20260812 bash sim/run_uvm.sh
```

必须看到 `[PHASE18]`，并同时满足 `UVM_ERROR=0`、`UVM_FATAL=0`、
`accepted=4`、`completed=4`，以及所有 ID 错误计数为 0、事务表清空。完整回归脚本
`sim/run_uvm_regression.sh` 已包含本测试，并将其 SVA 数据库合并到报告。

## 边界

本阶段没有修改 RTL 数据通路，也没有宣称已经支持乱序执行；ID 表的意义是让验证环境
先具备事务级契约，后续如果引入并发缓存，可以直接把按序比较扩展为按 ID 匹配。
