# BSTTokenMultiVesting Deployment Guide

本指南介绍如何部署和配置 BSTTokenMultiVesting 合约。

## 准备工作

### 1. 配置环境变量

创建 `.env` 文件：

```bash
PRIVATE_KEY=your_private_key_here
RPC_URL=your_rpc_url_here
BST_TOKEN_ADDRESS=0x...  # BST token 合约地址
```

### 2. 确保有足够的 gas

确保部署账户有足够的原生代币支付 gas 费用。

## 部署方式

### 方式一：部署并初始化（推荐）

使用 `DeployAndSetupVesting.s.sol` 一次性完成部署和添加初始 schedules。

#### 步骤：

1. **编辑配置**

   打开 `script/DeployAndSetupVesting.s.sol`，修改 `setupSchedules()` 函数：

   ```solidity
   function setupSchedules() internal pure returns (ScheduleConfig[] memory) {
       ScheduleConfig[] memory schedules = new ScheduleConfig[](3);

       schedules[0] = ScheduleConfig({
           beneficiary: 0x1111111111111111111111111111111111111111,
           cliffDuration: 0,           // 0天锁定期
           numberOfPeriods: 12,        // 12个周期（每个周期30天）
           amountPerPeriod: 1000 * 1e18  // 每个周期1000个token
       });

       schedules[1] = ScheduleConfig({
           beneficiary: 0x2222222222222222222222222222222222222222,
           cliffDuration: 90,          // 90天锁定期
           numberOfPeriods: 24,        // 24个周期
           amountPerPeriod: 500 * 1e18   // 每个周期500个token
       });

       // 添加更多 schedules...

       return schedules;
   }
   ```

2. **运行部署脚本**

   ```bash
   forge script script/DeployAndSetupVesting.s.sol --rpc-url $RPC_URL --broadcast -vvvv
   ```

3. **转账 token 到合约**

   脚本会输出需要转账的 token 总量：

   ```bash
   # 使用 cast 或其他方式转账
   cast send $BST_TOKEN_ADDRESS "transfer(address,uint256)" $VESTING_CONTRACT $TOTAL_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

4. **（可选）设置开始时间**

   如果想要设置未来的开始时间：

   ```bash
   # 设置 START_TIMESTAMP 环境变量
   export START_TIMESTAMP=1735689600  # Unix timestamp

   forge script script/SetStartTime.s.sol --rpc-url $RPC_URL --broadcast
   ```

5. **启动 vesting**

   ```bash
   forge script script/StartVesting.s.sol --rpc-url $RPC_URL --broadcast
   ```

### 方式二：分步部署

适用于需要分多次添加 schedules 或需要更灵活配置的情况。

#### 步骤：

1. **部署合约**

   ```bash
   forge script script/DeployBSTTokenMultiVesting.s.sol --rpc-url $RPC_URL --broadcast
   ```

   记录输出的合约地址，添加到 `.env`：
   ```bash
   VESTING_CONTRACT=0x...
   ```

2. **添加 schedules（第一批）**

   编辑 `script/AddSchedules.s.sol` 中的 `setupSchedules()` 函数，然后运行：

   ```bash
   forge script script/AddSchedules.s.sol --rpc-url $RPC_URL --broadcast
   ```

3. **添加更多 schedules（可选）**

   可以多次运行 `AddSchedules.s.sol`，每次添加不同的 schedules。

4. **转账 token 到合约**

   ```bash
   cast send $BST_TOKEN_ADDRESS "transfer(address,uint256)" $VESTING_CONTRACT $TOTAL_AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
   ```

5. **启动 vesting**

   ```bash
   forge script script/StartVesting.s.sol --rpc-url $RPC_URL --broadcast
   ```

## 脚本说明

### DeployAndSetupVesting.s.sol
- **功能**：部署合约并添加初始 schedules
- **适用场景**：首次部署，需要一次性添加所有初始 schedules
- **环境变量**：`PRIVATE_KEY`, `RPC_URL`, `BST_TOKEN_ADDRESS`

### DeployBSTTokenMultiVesting.s.sol
- **功能**：仅部署合约
- **适用场景**：需要分步操作或稍后再添加 schedules
- **环境变量**：`PRIVATE_KEY`, `RPC_URL`, `BST_TOKEN_ADDRESS`

### AddSchedules.s.sol
- **功能**：向已部署的合约添加 schedules
- **适用场景**：
  - 首次部署后添加 schedules
  - 在 vesting 开始后添加新的 schedules
  - 分批添加 schedules
- **环境变量**：`PRIVATE_KEY`, `RPC_URL`, `VESTING_CONTRACT`

### SetStartTime.s.sol
- **功能**：设置或修改 vesting 开始时间
- **适用场景**：需要在未来某个特定时间开始 vesting
- **限制**：只能在 vesting 开始前调用
- **环境变量**：`PRIVATE_KEY`, `RPC_URL`, `VESTING_CONTRACT`, `START_TIMESTAMP`

### StartVesting.s.sol
- **功能**：启动 vesting
- **适用场景**：所有 schedules 添加完毕，token 已转入合约
- **环境变量**：`PRIVATE_KEY`, `RPC_URL`, `VESTING_CONTRACT`, `BST_TOKEN_ADDRESS`

## 重要说明

### 关于 Cliff 和 Period

- **Cliff（锁定期）**：从 vesting 开始到可以领取第一笔 token 的等待时间
  - Cliff = 0：vesting 开始时立即解锁第一期
  - Cliff > 0：等待 cliff 期结束后，立即解锁第一期

- **Period（周期）**：固定为 30 天
  - 每个周期解锁 `amountPerPeriod` 数量的 token
  - Cliff 结束后，第一期立即解锁，之后每 30 天解锁一期

### 示例

```solidity
ScheduleConfig({
    beneficiary: 0x123...,
    cliffDuration: 90,          // 90天锁定期
    numberOfPeriods: 12,        // 12个周期
    amountPerPeriod: 1000 * 1e18  // 每期1000 tokens
})
```

**时间线**：
- Day 0: Vesting 开始
- Day 0-90: Cliff 期，无法领取
- Day 90: Cliff 结束，第1期（1000 tokens）立即解锁
- Day 120: 第2期（1000 tokens）解锁
- Day 150: 第3期（1000 tokens）解锁
- ...
- Day 420: 第12期（1000 tokens）解锁，全部解锁完毕

**总量**：12 × 1000 = 12,000 tokens

### 余额检查

- **添加 schedule 时**：不检查合约余额
- **启动 vesting 时**：检查合约余额是否 >= totalAllocatedAmount
- **建议**：在调用 `startVesting()` 前确保合约有足够余额

### Gas 优化建议

- 如果需要添加大量 schedules，建议使用 `batchAddSchedules()` 函数
- 可以在脚本中手动调用 `batchAddSchedules()` 而不是多次调用 `addSchedule()`

## 验证合约

部署后验证合约：

```bash
forge verify-contract --chain-id <chain_id> --compiler-version v0.8.17 <contract_address> src/BSTTokenMultiVesting.sol:BSTTokenMultiVesting --constructor-args $(cast abi-encode "constructor(address,address)" $BST_TOKEN_ADDRESS $OWNER_ADDRESS)
```

## 测试

在主网部署前，建议在测试网测试：

```bash
# 运行所有测试
forge test --match-contract BSTTokenMultiVesting

# 运行特定测试
forge test --match-test testAddSchedule -vvvv
```

## 故障排除

### 错误："Insufficient contract balance"
- **原因**：合约余额不足
- **解决**：转账足够的 token 到合约地址

### 错误："Vesting already started"
- **原因**：尝试修改已开始的 vesting
- **解决**：只能在 vesting 开始前修改 schedules 或 start time

### 错误："OwnableUnauthorizedAccount"
- **原因**：使用的账户不是合约 owner
- **解决**：使用 owner 账户的私钥

## 安全建议

1. **私钥安全**：不要将私钥提交到版本控制系统
2. **测试先行**：先在测试网部署和测试
3. **余额核对**：确保转账的 token 数量与 totalAllocatedAmount 一致
4. **多签钱包**：生产环境建议使用多签钱包作为 owner
5. **审计**：重要合约部署前进行安全审计

## 常用命令

```bash
# 查看合约状态
cast call $VESTING_CONTRACT "isStarted()" --rpc-url $RPC_URL
cast call $VESTING_CONTRACT "totalAllocatedAmount()" --rpc-url $RPC_URL
cast call $VESTING_CONTRACT "startTime()" --rpc-url $RPC_URL

# 查看合约余额
cast call $BST_TOKEN_ADDRESS "balanceOf(address)" $VESTING_CONTRACT --rpc-url $RPC_URL

# 查看用户的 schedules 数量
cast call $VESTING_CONTRACT "getUserScheduleCount(address)" $USER_ADDRESS --rpc-url $RPC_URL
```
