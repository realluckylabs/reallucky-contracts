# 真抽奖
[English](README.md)
## 简介
这是[真抽奖](https://app.reallucky.io)项目的智能合约代码，代码保证与线上部署的[合约](https://bscscan.com/address/0xbbb1381e648c66ca10d2bb1ccea46993eef556c8)100%吻合，没有任何修改。
同时合约的源码也已经在bscscan.com上进行了[源码验证](https://bscscan.com/address/0xbbb1381e648c66ca10d2bb1ccea46993eef556c8#code)
## 部署详情
币安智能链

    0xbbb1381e648c66ca10d2bb1ccea46993eef556c8
# 入门指南

## 先决条件
- 安装Node.js版本建议18以上
- 使用npm或yarn包管理器
## 初始化环境

### 安装hardhat及项目依赖

```shell
npm install -D
```
### 项目根目录创建账户环境文件.env
```shell
DEPLOYER_PK='你的部署账户的私钥，去掉0x'
GOV_PK='你的治理账户的私钥，去掉0x'
#测试账户一共有10个，请自行补充
TEST_1_PK='你的测试账户1的私钥，去掉0x'
...
TEST_10_PK='你的测试账户10的私钥，去掉0x'
```
### 如果启用GasReport请在hardat.config.ts中填写相应的api key
```shell
...
gasReporter: {
    ...
    coinmarketcap:'[Your coinmarketcap.com api-key]',
    gasPriceApi:'https://api.bscscan.com/api?module=proxy&action=eth_gasPrice&apikey=[Your bscscan.com api-key]'
    ...
  }
...
```
## 用法
### 本地测试

ChainLink VRF

>本地测试需要自行部署ChainLink的VRF模拟合约，并自行模拟回填操作，具体操作见[官方文档](https://docs.chain.link/vrf/v2/subscription/examples/test-locally)

开启本地bsc测试环境
```shell
#在项目根目录下打开一个终端，执行
npx hardhat node --fork bsc
```
运行命令
```shell
#同样在项目根目录下打开第二个终端，即可运行hardhat的命令

#编译sol文件
npx hardhat compile

#执行scripts下的ts脚本，使用本地环境
npx hardhat run ./scripts/deploy_raffle.ts --network localhost

#如果想使用其他的环境则在--network后面制定环境别名即可，环境别名在hardhat.config.ts的config中定义
#例如想在bsctest上部署和执行合约可以执行
npx hardhat run ./scripts/deploy_raffle.ts --network bsctest
```

运行测试脚本
```shell
#同样在项目根目录下打开第三个终端，即可运行hardhat的测试命令
#执行test下的ts脚本，使用本地环境
npx hardhat test ./test/RaffleRush.ts --network localhost

#如果想使用其他的环境则在--network后面制定环境别名即可，环境别名在hardhat.config.ts的config中定义
#例如想在bsctest上测试可以执行
npx hardhat test ./test/RaffleRush.ts --network bsctest
```

### 主网部署
**部署前**

>需要你在ChainLink的后台创建订阅，然后将订阅id和coordinator地址填写到部署脚本中  
>scripts/deploy_raffle.ts  
>[官方文档](https://docs.chain.link/vrf/v2/subscription)

部署合约
```shell
npx hardhat run ./scripts/deploy_raffle.ts --network bsc
```
控制台打印的合约地址即为你本次部署的合约地址

**部署后**
> 记得将打印的部署地址添加到ChainLink的消费者列表里