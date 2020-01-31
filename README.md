[logo]: https://cdn.xy.company/img/brand/XYO_full_colored.png

[![logo]](https://xyo.network)

![](https://github.com/XYOracleNetwork/dapp-scsc-solidity/workflows/CI/badge.svg)
[![BCH compliance](https://bettercodehub.com/edge/badge/XYOracleNetwork/dapp-scsc-solidity?branch=master&token=02d25ea6874c74a77ffefc6157e0253305509033)](https://bettercodehub.com/results/XYOracleNetwork/dapp-scsc-solidity) [![Known Vulnerabilities](https://snyk.io/test/github/XYOracleNetwork/dapp-scsc-solidity/badge.svg)](https://snyk.io/test/github/XYOracleNetwork/dapp-scsc-solidity)

<h3 align="center">
  The Smart Contract Library for XYO
</h3>

Table of Contents

- [Title](#Simple-Consensus-Smart-Contract-Dapp-Library)
- [Description](#description)
- [Security](#security)
- [Install](#install)
- [Usage](#usage)
- [Diviner Staking Walkthrough](#walkthrough)
- [API](#api)
- [Maintainers](#maintainers)
- [Contributing](#contributing)
- [License](#license)
- [Credits](#credits)

### Simple Consensus Smart Contract Dapp Library _(dapp-scsc-solidity)_

## Description

This package has been built to streamline the dApp build process for anyone ready to integrate XYO into their project. Especially crucial in this library are the `XyGovernance` and `XyStakingConsensus` contracts. The `XyPayOnDelivery` contract is a solid example of the execution of all nodes in XYO, and is used with our [Payable on Delivery Demo](https://developers.xyo.network/docs/en/payable-demo/). The package contains contracts that are upgradeable (with the exception of the Parameterizer) so that you can fix security vulnerabilities and introduce new features without migrating all of the data unecessarily. 

## Install

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

- Mint one token with your wallet address by selecting the XyBlockProducer and the address below

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

## API

### XyERC20Token

`transfer` 
- Sends a specific value of tokens from your XYO account to another

- **parameters**
  - `address _to`
  - `uint256 _value `

`transferFrom`
- Sends a specific value of tokens from one (not yours) XYO address to another XYO address

- **parameters**
  - `address _from`
  - `address _to`
  - `uint256 _value`

- **returns**
  - `bool success`

`approve`
- Sets an allowance for tokens for another address **check out our staking walkthrough for an example**

- **parameters**
  - `address _spender`
  - `uint256 _value`

- **returns**
  - `bool success`

`approveAndCall`
- Sets an allowance for tokens for another address with a notification for the other contract

- **parameters**
  - `address _spender`
  - `uint _value`
  - `bytes memory _extraData`

- **returns**
  - `bool success` & `approval notification with _value and _extraData`

`burn`
- destroys tokens

- **parameters**
  -  `uint256 _value`

- **returns**
  - `bool success`

`burnFrom`
- Destroys tokens from another account

- **parameters**
  - `address _from`
  - `uint256 _value`

- **returns**
  - `bool success`

#### XyBlockProducer

**This contract is used to track ownership of stakable addresses in XYO**
**This contract is upgradeable**

`enableBlockProducer`
- Allows a contract governor to add and remove a block producer

- **parameters**
  - `uint stakee`
  - `bool enable`

`mint`
- Mints a stakable address with the account has as the token id
**this emits a transfer event to the sender**

- **parameters**
  - `address beneficiary`

`burn`
- Burns a token (only a governor can do this)
- If the token belongs to a block producer, it deletes the token from its listing

- **parameters**
  - `uint stakee`

`exists`
- A method to view if a stakee exists

- **parameters**
  - `uint stakee`

- **returns**
  - `stakee`

`isBlockProducer`
- A method to view if a stakee is a block producer

- **parameters**
  - `uint stakee`

- **returns**
  - `stakee from the blockProducersIndex`

`numBlockProducers`
- A method to view the number of block producers

- **returns**
  - `number of block producers`

#### XYStakingConsensus

**Manages the stake for multiple clients in a decentralized consensus**
**This contract is upgradeable**

`getLatestBlock`
- Returns the latest block submitted on the chain

- **returns**
  - `uint _latest`

`withdrawRewardRequest`
- Withdraw reward balance 

- **parameters**
  - `uint xyoBounty`

- **returns**
  - `uint requestId`

`submitRequest`
- Escrows eth and XYO to ensure that it covers the answer mining cost
- Stores the new request in the request pool and emits the submission

- **parameters**
  - `uint request`
  - `uint xyoBounty`
  - `address xyoSender`
  - `IXyRequester.RequestType requestType`

`submitBlock`
- Submits a new block at the consensus blockchain, with a verified stake over 51% and returns weiMining for successful creation. 

- **parameters**
  - `uint blockProducer`
  - `uint previousBlock`
  - `uint[] memory _requests`
  - `bytes32 payloadData`
  - `bytes memory responses`
  - `address[] memory signers`
  - `bytes32[] memory sigR`
  - `bytes32[] memory sigS`
  - `uint8[] memory sigV`

- **returns**
  -  `uint (newBlock)`

`numRequests`
- A method to view the number of requests in the consensus block

- **returns**
  - `requestChain.length`

`numBlocks`
- A method to view the number of blocks in the consensus chain

- **returns**
  - `blockChain.length`

`XyPayOnDelivery`
- A Payment on delivery contract, check out our [Payable On Delivery Demo](https://developers.xyo.network/docs/en/payable-demo/) to see how it works
- **This contract is upgradeable**

`requestPayOnDelivery`
- Called by the client to request an intersection question (is the item delivered?)

- **parameters**
  - `uint requestId`
  - `uint xyoBounty`
  - `uint xyoPayOnDelivery`
  - `uint weiPayOnDelivery`
  - `address payable beneficiary`

`submitResponse`
- Called by SCSC, if there is an intersection, executes a transfer to beneficiary and deletes the request from the request pool

- **parameters**
  - `uint requestId`
  - `IXyRequester.RequestType`
  - `bytes memory responseData`

`payOnDelivery`
- This contract is called in `submitResponse` with the request Id and who needs to be paid. In the `submitResponse` contract that is the beneficiary. This contract is a refunding mechanism that is utilized as a payment mechanism upon successful completion of a request/response.

- **parameters**
  - `uint requestId`
  - `address payable payee`

`numRequests`
- Gets the number of requests currently in play

- **returns**
  - `requests.length`

## Maintainers 

- Kevin Weiler
- Phillip Lorenzo

## Contributing

If you'd like to contribute to the SCSC as a developer or just run the project from source the directions below should help you get started.

First, clone the repository. And set the branch to the develop branch

```sh
  git clone -b develop https://github.com/XYOracleNetwork/dapp-scsc-solidity
```

Then change working directory to that of the repository

```sh
  cd dapp-scsc-solidity
```

Download dependencies

```sh
  yarn install
```

After installing, go ahead and open in your favorite text editor, ours is [Visual Studio Code](https://code.visualstudio.com/)

```sh
 ➜ dapp-scsc-solidity code .
```

Execute these truffle steps:

Set up a local Ganache instance 

```sh
ganache-cli --port 8545 --deterministic < if you want to set the networkID --networkId idNumber>
```
Using the deterministic flag is a good way to keep consistent when in `development` mode

**keep this terminal window open!**

**In another terminal window (or tab)**

Compile the contracts

```sh
truffle compile
```

Migrate the contracts 

```sh
truffle migrate
```

You will see transactions for each contract in your Ganache instance and their addressess

Test the contracts

```sh
truffle test
```

Ganache will work again executing transactions while executing the unit tests.
**Note** if you did not `compile` or `migrate`, no worries, this command will do that for you. 

We recommend testing after any revisions you make to contracts. 

If you would like to know more about how the contracts are upgradeable, read the [PROXY.md](PROXY.md) file.

## Developer Guide

Developers should conform to git flow workflow. Additionally, we should try to make sure
every commit builds. Commit messages should be meaningful serve as a meta history for the
repository. Please squash meaningless commits before submitting a pull-request.

## License

See the [LICENSE](LICENSE) file for license details.

## Credits

Made with 🔥and ❄️ by [XYO](https://www.xyo.network)

Package developed using [ZeppelinOS](https://zeppelinos.org/)