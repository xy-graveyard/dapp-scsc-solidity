import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"
import { request } from "http"

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)

const PayOnDelivery = artifacts.require(`XyPayOnDelivery.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const stripHexPrefix = require(`strip-hex-prefix`)
const erc20TotalSupply = 1000000

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

contract(
  `XyPayOnDelivery`,
  ([consensusOwner, erc20owner, parameterizerOwner, payOnDeliveryOwner, requestBe e]) => {
    let erc20
    let consensus
    let stakableToken
    let parameterizer
    let plcr
    let payOnD
    const diviners = [consensusOwner, erc20owner, parameterizerOwner]
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      parameterizer = await Governance.new({
        from: parameterizerOwner
      })
      plcr = await PLCR.new({
        from: parameterizerOwner
      })
      await plcr.init(erc20.address)
    })
    beforeEach(async () => {
      consensus = await StakingConsensus.new(
        diviners,
        erc20.address,
        stakableToken.address,
        parameterizer.address,
        {
          from: consensusOwner
        }
      )
      payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
        from: payOnDeliveryOwner
      })
    })
    describe(`Submitting Requests`, () => {
      it(`should create ipfs requests`, async () => {
        await payOnD.submitIPFSRequest('123', 0, 0, ).should.be.fulfilled
      })
    })
  }
)
