# How to add stake on XYO Diviner

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

## Congratulations! You have activated stake on a diviner!



