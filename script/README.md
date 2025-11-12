# Deployment Scripts

BSTTokenMultiVesting 合约部署和管理脚本。

## 脚本列表

| 脚本 | 功能 | 使用场景 |
|------|------|----------|
| `DeployAndSetupVesting.s.sol` | 部署合约 + 添加初始schedules | 首次部署，一次性完成所有配置 |
| `DeployBSTTokenMultiVesting.s.sol` | 仅部署合约 | 需要分步操作 |
| `AddSchedules.s.sol` | 添加vesting schedules | 添加新的schedules（部署前后都可用）|
| `SetStartTime.s.sol` | 设置开始时间 | 需要指定未来某个时间开始vesting |
| `StartVesting.s.sol` | 启动vesting | 准备就绪后启动vesting |

## 快速开始

### 1. 准备环境

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件
PRIVATE_KEY=your_private_key
RPC_URL=your_rpc_url
BST_TOKEN_ADDRESS=0x...
```

### 2. 配置 schedules

编辑 `DeployAndSetupVesting.s.sol` 中的 `setupSchedules()` 函数，或参考 `schedules.example.json`。

### 3. 部署和配置

```bash
# 方式一：一键部署（推荐）
forge script script/DeployAndSetupVesting.s.sol --rpc-url $RPC_URL --broadcast

# 方式二：分步部署
forge script script/DeployBSTTokenMultiVesting.s.sol --rpc-url $RPC_URL --broadcast
forge script script/AddSchedules.s.sol --rpc-url $RPC_URL --broadcast
```

### 4. 转账 token

```bash
# 将 token 转到 vesting 合约
cast send $BST_TOKEN_ADDRESS "transfer(address,uint256)" $VESTING_CONTRACT $TOTAL_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### 5. 启动 vesting

```bash
# （可选）设置未来开始时间
export START_TIMESTAMP=1735689600
forge script script/SetStartTime.s.sol --rpc-url $RPC_URL --broadcast

# 启动 vesting
forge script script/StartVesting.s.sol --rpc-url $RPC_URL --broadcast
```

## 详细文档

查看 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 了解详细的部署指南和注意事项。

## 测试

```bash
# 运行所有测试
forge test --match-contract BSTTokenMultiVesting -vv

# 运行特定测试
forge test --match-test testAddSchedule -vvvv
```

## 文件说明

- **DeployAndSetupVesting.s.sol**: 部署 + 初始化脚本（推荐用于首次部署）
- **DeployBSTTokenMultiVesting.s.sol**: 简单部署脚本
- **AddSchedules.s.sol**: 添加 schedules 脚本
- **SetStartTime.s.sol**: 设置开始时间脚本
- **StartVesting.s.sol**: 启动 vesting 脚本
- **schedules.example.json**: 配置文件示例
- **DEPLOYMENT_GUIDE.md**: 详细部署指南
- **README.md**: 本文件

## 注意事项

⚠️ **重要**：
- 在主网部署前，务必先在测试网测试
- 确保合约有足够的 token 余额再调用 `startVesting()`
- 保管好私钥，不要提交到版本控制系统
- 生产环境建议使用多签钱包作为 owner

## 常见问题

**Q: 如何修改已添加的 schedule？**
A: 在 vesting 开始前可以调用 `updateSchedule()` 或 `removeSchedule()`。

**Q: Vesting 开始后还能添加新的 schedule 吗？**
A: 可以，使用 `AddSchedules.s.sol` 脚本添加即可。

**Q: 第一期什么时候解锁？**
A: Cliff 期结束后立即解锁第一期，不需要再等 30 天。

**Q: 如何计算总需要的 token 数量？**
A: 每个 schedule 的总量 = `numberOfPeriods * amountPerPeriod`，所有 schedules 加总即可。

## 支持

如有问题，请查看 [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) 或联系开发团队。
