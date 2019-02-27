<h1 align="center">
  <img alt="XY" src="https://www.xy.company/img/home/logo_xy.png" width="300">
</h1>

<p align="center">
  <a href="https://circleci.com/gh/XYOracleNetwork/tool-dapper-nodejs">
    <img alt="Circle Status" src="https://circleci.com/gh/XYOracleNetwork/dapp-scsc-solidity.svg?style=shield&circle-token=33a0b5f18bed34785e192f04e94a56151b69796b">
  </a>
  <a href="https://gitter.im/XYOracleNetwork/Dev">
    <img alt="Gitter Chat" src="https://img.shields.io/gitter/room/XYOracleNetwork/Stardust.svg">
  </a>
  <a href="http://commitizen.github.io/cz-cli/">
    <img alt="Commitizen friendly" src="https://img.shields.io/badge/web3-friendly-brightgreen.svg">
    </a>
    <a href="https://david-dm.org/xyoraclenetwork/tool-dapper-react" title="dependencies status"><img src="https://david-dm.org/xyoraclenetwork/dapp-scsc-solidity/status.svg"/></a>
  <a href="https://david-dm.org/xyoraclenetwork/dapp-scsc-solidity?type=dev" title="devDependencies status"><img src="https://david-dm.org/xyoraclenetwork/dapp-scsc-solidity/dev-status.svg"/></a>
    <a href="https://greenkeeper.io/" title="devDependencies status"><img src="https://badges.greenkeeper.io/XYOracleNetwork/dapp-scsc-solidity.svg"/></a>
</p>

<h3 align="center">
  The Smart Contract Library for XYO
</h3>
<p align="center">Made with  ❤️  by [<b>XY - The Persistent Company</b>] (https://xy.company)</p>

Table of Contents
-[Sections](#sections)
- [Title](#Simple-Consensus-Smart-Contract-Dapp-Library)
- [Short Description](#short-description)
- [Long Description](#long-description)
- [Security](#security)
- [Install](#install)
- [Usage](#usage)
- [Diviner Staking Walkthrough](#walkthrough)
- [API](#api)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)
- [Credits](#credits)

## Sections

### Simple Consensus Smart Contract Dapp Library _(dapp-scsc-solidity)_

[![BCH compliance](https://bettercodehub.com/edge/badge/XYOracleNetwork/dapp-scsc-solidity?branch=master&token=02d25ea6874c74a77ffefc6157e0253305509033)](https://bettercodehub.com/results/XYOracleNetwork/dapp-scsc-solidity)

### Short Description

> A Simple Consensus Smart Contract library for all nodes in XYO

### Long Description
This package has been built to streamline the dApp build process for anyone ready to integrate XYO into their project. Especially crucial in this library are the `XyGovernance` and `XyStakingConsensus` contracts. The `XyPayOnDelivery` contract is a solid example of the execution of all nodes in XYO, and is used with our [Payable on Delivery Demo](https://developers.xyo.network/docs/en/payable-demo/). The package contains contracts that are upgradeable (with the exception of the Parameterizer) so that you can fix security vulnerabilities and introduce new features without migrating all of the data unecessarily. 

### Install

**Requirements:**
- In the command line go ahead and install using `npm`
  ```bash
  npx zos link dapp-scsc-solidity
  ```
- Run

**Suggestions:**
- Familiarity with
  - Solidity
  - Web3
  - Truffle
  - Ganache

### Usage

**Requirements:**
- Watch this video on staking a node in XYO
- Check out [dApper](https://github.com/XYOracleNetwork/tool-dapper-react)
  - dApper allows you to interact with the smart contracts from the scsc library on the browser


**Suggestions:**
- Follow the walkthrough below to familiarize yourself with the scsc in the dApper environment. This is a good starting point to understanding how our scsc interacts with XYO.

### Walkthrough

### How to add stake on XYO Diviner

### Access our SCSC library through IPFS 

**use this hash `QmaHuJh3u5J4W8WYhJnfH1yZUWWwUaehsVLbUPMEd4ymqN`**

### Then direct your browser to use our dAppper tool

**with the hash**

`https://dapper.layerone.co/settings/QmaHuJh3u5J4W8WYhJnfH1yZUWWwUaehsVLbUPMEd4ymqN`

The contract will load, giving you access to the contracts through the contract simulator.

### Start with the XyERC20Token

### Connect your metamask wallet on the Kovan network

### Check your balance using the `balanceOf()` function from the ERC20 contract

**Once you have verified that you have enough balance to stake the diviner, select the XyStakingConsensus contract** This contract stores all the stake of the network

Approve the stake for the Diviner in the XyERC20 contract (make sure that you have the address for the XyStakingConsensus) using the `approve()` function.

Go through metamask to submit the transaction. You have now approved stake, let's keep going.

### Create a diviner

The diviner is represented by a **Stakable token**

- Mint one token with your wallet address by selecting the XyStakableToken and the address below

- Select the `mint()` function and paste your wallet address into the `beneficiary` field

- Confirm the transaction on metamask

This will produce one non-fungible token (ERC721). This is unique to this specific diviner.

Then select the `tokenByIndex()` function and enter `0` for your token address.

Copy the token address, this is **virtual id of your diviner**

### Return to the **XyStakingConsensusContract** and select its address below

- Select the `stake()` function 
- Paste the **diviner id** into the stakee field
- enter an amount to stake (make sure it is in your approved limits!)
- Click `execute`

### You have just successfully added stake to a diviner!

**note** you are the staker, and the **stakingId** is the ledger of the stake that you have in the diviner

To check out the data of the stake, select the `stakeData()` function, paste in the **stakingId** in the sole field.

You will now get a returned JSON object with your stake amount, the block it was staked on, the staker, and the stakee.

**Congratulations! You have activated stake on a diviner!**

### API

#### XyERC20Token

`transfer` 
- Sends a specific value of tokens from your XYO account to another

**parameters**
- `address _to`
- `uint256 _value `

`transferFrom`
- Sends a specific value of tokens from one (not yours) XYO address to another XYO address

**parameters**
- `address _from`
- `address _to`
- `uint256 _value`

**returns**
- `bool success`

`approve`
- Sets an allowance for tokens for another address **check out our staking walkthrough for an example**

**parameters**
- `address _spender`
- `uint256 _value`

**returns**
- `bool success`

`approveAndCall`
- Sets an allowance for tokens for another address with a notification for the other contract

*parameters*
- `address _spender`
- `uint _value`
- `bytes memory _extraData`

**returns**
`bool success` & `approval notification with _value and _extraData`

`burn`
- destroys tokens

**parameters**
-  `uint256 _value`

**returns**
`bool success`

`burnFrom`
- Destroys tokens from another account

**parameters**
- `address _from`
- `uint256 _value`

**returns**
`bool success`

#### XyStakableToken

**This contract is used to track ownership of stakable addresses in XYO**
**This contract is upgradeable**

`enableBlockProducer`
- Allows a contract governor to add and remove a block producer

*parameters*
- `uint stakee`
- `bool enable`

`mint`
- Mints a stakable address with the account has as the token id
**this emits a transfer event to the sender**

**parameters**
- `address beneficiary`

`burn`
- Burns a token (only a governor can do this)
- If the token belongs to a block producer, it deletes the token from its listing

**parameters**
- `uint stakee`

`exists`
- A method to view if a stakee exists

**parameters**
- `uint stakee`

`isBlockProducer`
- A method to view if a stakee is a block producer

**parameters**
- `uint stakee`

`numBlockProducers`
- A method to view the number of block producers

### Maintainers 

### Contributing

### License

Only for internal XY Company use at this time

### Credits

Package developed using [ZeppelinOS](https://zeppelinos.org/)

<p align="center">Made with  ❤️  by [<b>XY - The Persistent Company</b>] (https://xy.company)</p>
