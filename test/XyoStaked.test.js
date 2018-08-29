import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
import {advanceBlock} from 'openzeppelin-solidity/test/helpers/advanceToBlock'
import EVMRevert from 'openzeppelin-solidity/test/helpers/EVMRevert'
const XyoStaked = artifacts.require('XyoStaked.sol')
const StandardToken = artifacts.require('StandardToken.sol')

const crypto = require('crypto')
const hash = crypto.createHash('sha256')

const BN = (_x_) => {
  return web3.toBigNumber(_x_);
};

const FW = (_x_) => {
  return BN(web3.fromWei(BN(_x_)));
};

const TW = (_x_) => {
  return BN(web3.toWei(BN(_x_)));
};

const CMP = (_x_, _y_) => {
  return BN(_x_).eq(BN(_y_));
};

contract('XyoStaked', ([contractCreator, owner1, node1]) => {

    beforeEach(async function _ () {
        this.token = await StandardToken.new(TW(10000000), {from: contractCreator, gasPrice: 0})
        console.log("StandardToken Created ", this.token.address)
        this.xyoStake = await XyoStaked.new(this.token.address, 30, {from: contractCreator, gasPrice: 0})
        console.log("XyoStaked Created ", this.xyoStake.address)
    })

    it ('should claim a new node', async () => {

        hash.update(node1)
        const h = hash.digest()

        const { logs }  = await this.xyoStake.claim(node1, v, r, s, {from: owner1})
    })

    it ('should stake a new node', async () => {
        const { logs }  = await this.xyoStake.stake(node1, TW(10), {from: owner1})
    })

    /*it ('should be able to retrieve the hash after stored', async function _() {
        let storedHash = 'QmfM2r8seH2GiRaC4esTjeraXEachRt8ZsSeGaWTPLyMoG'
        await this.vault.storeInVault('TEST', storedHash, {from: dataOwner})
        let hash = await this.vault.getVaultContents('TEST')
        hash.should.be.equal(storedHash)
    })

    it ('should be able to convert string to uint', async function _() {
        let result = await this.vault.encodeShortString("Test Vault")
        let result2 = await this.vault.encodeShortString("Test Vault2")
        let result3 = await this.vault.encodeShortString("TEST Vault")
        let result4 = await this.vault.encodeShortString("TESty Vault")
        result.should.be.bignumber.not.equal(result2).not.equal(result3).not.equal(result4)
    })*/

})
