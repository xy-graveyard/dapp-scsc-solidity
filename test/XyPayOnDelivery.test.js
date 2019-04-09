import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"
import { request } from "http"
import { advanceBlock } from "./utils.test"

const abi = require(`ethereumjs-abi`)
const { toBuffer } = require(`ethereumjs-util`)

const PayOnDelivery = artifacts.require(`XyPayOnDelivery.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock2.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyBlockProducerMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const stripHexPrefix = require(`strip-hex-prefix`)
const erc20TotalSupply = 1000000
const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`./config/testParams.json`))
const params = config.paramDefaults
const parameters = [
  params.pMinDeposit,
  params.pApplyStageSec,
  params.pCommitStageSec,
  params.pRevealStageSec,
  params.pDispensationPct,
  params.pVoteSuccessRate,
  params.pVoteQuorum,
  params.xyStakeSuccessPct,
  params.xyWeiMiningMin,
  params.xyXYORequestBountyMin,
  params.xyStakeCooldown,
  params.xyUnstakeCooldown,
  params.xyProposalsEnabled,
  params.xyBlockProducerRewardPct
]
require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

contract(
  `XyPayOnDelivery`,
  ([
    consensusOwner,
    erc20owner,
    parameterizerOwner,
    payOnDeliveryOwner,
    stakableTokenOwner,
    stakableContractOwner,
    payOnDeliveryBeneficiary,
    responseSubmitter
  ]) => {
    let erc20
    let consensus
    let stakableToken
    let parameterizer
    let plcr
    let payOnD
    const diviners = [consensusOwner, erc20owner]
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })

      plcr = await PLCR.new({
        from: parameterizerOwner
      })

      await plcr.initialize(erc20.address)
      stakableToken = await Stakeable.new(diviners, {
        from: stakableContractOwner
      })
    })
    beforeEach(async () => {
      parameterizer = await Governance.new({
        from: parameterizerOwner
      })
      await parameterizer.initialize(
        erc20.address,
        plcr.address,
        parameters,
        { from: parameterizerOwner }
      )
      consensus = await StakingConsensus.new(
        diviners,
        erc20.address,
        stakableToken.address,
        parameterizer.address,
        {
          from: consensusOwner
        }
      )

      await parameterizer.initializeGovernor(consensus.address)
      await advanceBlock()
    })
    describe(`Submitting Requests`, () => {
      beforeEach(async () => {
        payOnD = await PayOnDelivery.new({
          from: payOnDeliveryOwner,
          gas: 6721975
        })
        await payOnD.initialize(consensus.address, erc20.address, {
          gas: 6721975
        })
      })
      it(`should create requests`, async () => {
        await payOnD.requestPayOnDelivery(`0x123`, 0, 0, 0, payOnDeliveryBeneficiary, { gas: 6721975 })
          .should.be.fulfilled
      })
      it(`should not allow duplicate requests`, async () => {
        await payOnD.requestPayOnDelivery(`0x123`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.requestPayOnDelivery(`0x123`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.not.be.fulfilled
      })

      it(`should escrow funds for pay on delivery`, async () => {
        await erc20.approve(payOnD.address, 90, { from: erc20owner })
        await payOnD.requestPayOnDelivery(
          `0x123`,
          0,
          20,
          90,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.be.fulfilled
        const balanceXyo = await erc20.balanceOf(payOnD.address)
        balanceXyo.toNumber().should.be.equal(20)
        const balanceEth = await web3.eth.getBalance(payOnD.address)
        Number(balanceEth).should.be.equal(90)
      })
      it(`should fail if not enough funds for mining costs`, async () => {
        await parameterizer.ownerSet(`xyXYORequestBountyMin`, 100, {
          from: parameterizerOwner
        })
        await parameterizer.ownerSet(`xyWeiMiningMin`, 100, {
          from: parameterizerOwner
        })
        await erc20.approve(payOnD.address, 500, { from: erc20owner })
        await erc20.approve(consensus.address, 500, { from: erc20owner })
        await payOnD.requestPayOnDelivery(
          `0x123`,
          20,
          90,
          0,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.requestPayOnDelivery(
          `0x1232`,
          200,
          90,
          0,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.requestPayOnDelivery(
          `0x1233`,
          90,
          200,
          0,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.requestPayOnDelivery(
          `0x1253`,
          300,
          200,
          0,
          payOnDeliveryBeneficiary,
          { value: 400, from: erc20owner }
        ).should.be.fulfilled
      })
      it(`should store requests in array`, async () => {
        await erc20.approve(payOnD.address, 500, { from: erc20owner })

        await payOnD.requestPayOnDelivery(`0x123`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.requestPayOnDelivery(`0x2`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        const requestId = web3.utils.randomHex(32)
        await payOnD.requestPayOnDelivery(
          requestId,
          0,
          10,
          100,
          payOnDeliveryBeneficiary,
          {
            from: erc20owner,
            value: 100
          }
        ).should.be.fulfilled
        await payOnD.requestPayOnDelivery(`0x4`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.requestPayOnDelivery(`0x5`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        const numReqs = await payOnD.numRequests()
        numReqs.toNumber().should.be.equal(5)
        const req2 = await payOnD.requests(2)
        req2.requestId.should.be.equal(requestId)
        req2.beneficiary.should.be.equal(payOnDeliveryBeneficiary)
        req2.asker.should.be.equal(erc20owner)
        req2.xyoPayment.toNumber().should.be.equal(10)
        req2.weiPayment.toNumber().should.be.equal(100)
        req2.responseAt.toNumber().should.be.equal(0)
      })
    })
    describe(`submitting responses`, async () => {
      beforeEach(async () => {
        payOnD = await PayOnDelivery.new({
          from: payOnDeliveryOwner
        })
        await payOnD.initialize(consensus.address, erc20.address)

        await erc20.approve(payOnD.address, 500, { from: erc20owner })

        await payOnD.requestPayOnDelivery(`0x1`, 0, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
      })

      it(`should only allow responses from SCSC`, async () => {
        const byteResponses = new Uint8Array(1)
        byteResponses[0] = 1

        const packedBytes = `0x${abi
          .solidityPack([`bytes`], [byteResponses])
          .toString(`hex`)}`

        await payOnD.submitResponse(`0x1`, 1, packedBytes).should.not.be.fulfilled
        await consensus.submitResponse(`0x1`, 1, packedBytes, payOnD.address, {
          from: responseSubmitter
        }).should.be.fulfilled
      })
    })
  }
)
