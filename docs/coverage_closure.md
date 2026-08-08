# new第7阶段：SVA与覆盖率收敛

## 验证范围

本阶段把覆盖率范围从计算核心扩展到完整 `axi_precoder_wrapper`，新增 AXI4-Stream、AXI4-Lite 和输出事务边界断言，并补充 AXI 功能覆盖模型。重点场景包括：

- AXI-Lite AW先到、W先到和AW/W同时到达；
- OKAY/SLVERR读写响应、非对齐地址、非法地址和不同WSTRB；
- AXI-Stream输入/输出反压，TLAST/TKEEP错误；
- Bank0/Bank1配置和双向commit；
- 忙期间commit pending以及事务内矩阵版本不变；
- 饱和与非饱和输出、4个天线编号和TLAST边界。

协议上不可能出现的交叉组合被标为忽略项，例如天线0至2携带TLAST，或天线3不携带TLAST。这些不是未覆盖功能，不能通过制造非法DUT输出来命中。

## 运行方法

在安装VCS和URG的服务器工程根目录执行：

```bash
COVERAGE=1 bash sim/run_vcs.sh
```

脚本从干净的仿真缓存开始，运行单元、核心、热更新、AXI wrapper和AXI压力回归，然后合并4个主要VDB。HTML入口为：

```text
build/vcs/coverage/report/dashboard.html
```

## 收敛结果

2026-08-08使用VCS O-2018.09-SP1完成的干净回归结果：

| 指标 | 覆盖率 |
|---|---:|
| 功能覆盖（GROUP） | 95.83% |
| RTL模块综合得分 | 82.38% |
| 行覆盖（模块定义） | 92.34% |
| 条件覆盖（模块定义） | 86.71% |
| 断言覆盖（模块定义） | 85.71% |
| Toggle覆盖（模块定义） | 64.77% |

全部testbench通过，回归日志没有断言失败。AXI主功能测试自身功能覆盖率为98.41%。

Toggle较低主要来自32位性能计数器的高位、地址和配置宽总线；短回归不可能自然翻转所有高位。当前不为了提高总分而加入数百万至数十亿周期的无功能价值激励。现阶段以功能覆盖超过95%、行覆盖超过90%、条件和断言覆盖超过85%作为合理收敛标准。

URG使用不同testbench顶层合并数据库时启用module flexible merge，因此旧版URG不显示合并后的FSM列。状态机行为已由核心功能覆盖点、事务边界断言和定向测试共同检查。
