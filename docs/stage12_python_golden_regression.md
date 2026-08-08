# new第12阶段：NumPy黄金模型与UVM端到端联动

## 阶段目的

当前UVM scoreboard已经有一套SystemVerilog位精确参考模型。本阶段再增加一条独立的Python/NumPy参考路径：Python在本地生成矩阵、调制符号和期望输出，服务器上的UVM只读取固定格式文本，不执行Python。这样RTL输出必须同时通过两种不同实现的参考检查，可以降低参考模型和DUT共用同一错误的风险。

## 为什么服务器不需要Python 3.10

`model/`和`scripts/generate_uvm_golden_vectors.py`只在本地Windows Python 3.13.9、NumPy 2.2.4环境运行。生成结果以ASCII文本和JSON清单提交到工程；服务器只使用VCS、UVM和标准SystemVerilog `$fscanf`读取文本。因此服务器现有的Python 3.6.8、没有NumPy的环境不会影响本阶段。

本地生成命令：

```powershell
python -m scripts.generate_uvm_golden_vectors --blocks 20 --vectors-per-block 50 --seed 20260808 --output tb/vectors/stage12_golden_vectors.txt --manifest tb/vectors/stage12_manifest.json
```

## 黄金文件内容

数据集有20个独立数据块，每块50个向量。每个数据块包含：

- 一个QPSK、16QAM或64QAM调制配置；
- 两套独立的4x4 Q1.14矩阵；
- Bank0的25个向量和Bank1的25个向量；
- Bank1版本号以及切换位置；
- 每个向量的Q1.14输入、4个Q1.14期望输出、4个饱和标志；
- Python计算出的实现EVM和端到端EVM。

Python生成器使用NumPy向量化Q14乘法、Q28累加、远离零舍入和16位饱和，并逐向量用 `model.fixed_model.precoder_fixed_int()` 进行标量交叉检查。清单记录数据规模、QAM分布、EVM统计、NumPy版本和黄金文件SHA-256：

```text
ec6c58eab59e592276ff2fe59aa8f41445698fd27b4862c32c25020aaddde7f8
```

## UVM检查流程

`precoder_python_golden_test` 从 `GOLDEN_FILE` 读取指定的 `DATASET_INDEX`：

1. 通过AXI-Lite写入Bank0和Bank1矩阵；
2. 发送Bank0的25个向量；
3. 第25个向量输入握手后立即提交Bank1，检查忙时原子切换；
4. 发送Bank1的25个向量；
5. 对每个输出拍比较实部、虚部、天线编号、`TLAST`、饱和标志和矩阵版本；
6. 将UVM scoreboard计算的实现EVM与Python记录值比较，误差容限为 `1e-9`；
7. 检查Python比较数量、scoreboard比较数量和忙时commit数量。

## 运行方法

单个数据块：

```bash
GOLDEN_FILE=tb/vectors/stage12_golden_vectors.txt DATASET_INDEX=0 VECTORS=50 UVM_TEST=precoder_python_golden_test bash sim/run_uvm.sh
```

完整回归：

```bash
RUNS=20 VECTORS=50 BASE_SEED=20260808 bash sim/run_python_golden_regression.sh
```

脚本在仿真前用 `sha256sum` 检查黄金文件和JSON清单一致，然后为每个数据块使用不同的VCS随机种子，随机化输入间隔、输出反压和AXI-Lite响应延迟。回归结束后自动合并SVA覆盖率。

## 正式结果

服务器正式VCS回归检查1000个向量，`UVM_ERROR=0`、`UVM_FATAL=0`，Python逐拍比较和EVM比较不一致数均为0。调制分布为：

| 调制 | 向量数 | 最大实现EVM | 最大端到端EVM |
|---|---:|---:|---:|
| QPSK | 350 | `1.623119e-4` | `4.121774e-4` |
| 16QAM | 350 | `2.003280e-4` | `5.985688e-4` |
| 64QAM | 300 | `1.751830e-4` | `4.174858e-4` |

服务器报告位置：

```text
build/vcs/uvm/python_golden/summary.csv
build/vcs/uvm/python_golden/summary.md
build/vcs/uvm/python_golden/sva_report/dashboard.html
```

本阶段完成的是4x4、Q1.14数据通路的独立参考闭环；8x8、12位模式和可配置round/saturation/truncation仍属于后续扩展，不应由本阶段结果宣称已经支持。
