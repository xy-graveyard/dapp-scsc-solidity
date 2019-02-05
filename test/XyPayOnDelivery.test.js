import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"
import { request } from "http"

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)
const PayOnDeliveryMock = artifacts.require(`XyPayOnDeliveryMock.sol`)

const PayOnDelivery = artifacts.require(`XyPayOnDelivery.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock2.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const stripHexPrefix = require(`strip-hex-prefix`)
const erc20TotalSupply = 1000000
const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`./config/testParams.json`))
const params = config.paramDefaults
const parameters = [
  params.pMinDeposit,
  params.pApplyStageLen,
  params.pCommitStageLen,
  params.pRevealStageLen,
  params.pDispensationPct,
  params.pVoteQuorum,
  params.xyStakeQuorumPct,
  params.xyEthMiningCost,
  params.xyXYOMiningCost,
  params.xyStakeCooldown,
  params.xyUnstakeCooldown
]
const should = require(`chai`)
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
      stakableToken = await Stakeable.new(stakableTokenOwner, diviners, {
        from: stakableContractOwner
      })
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
      await parameterizer.init(
        consensus.address,
        erc20.address,
        plcr.address,
        parameters,
        { from: parameterizerOwner }
      )
    })
    describe(`Submitting Requests`, () => {
      beforeEach(async () => {
        payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
          from: payOnDeliveryOwner
        })
      })
      it(`should create ipfs requests`, async () => {
        await payOnD.submitPayOnDelivery(`123`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
      })
      it(`should not allow duplicate ipfs requests`, async () => {
        await payOnD.submitPayOnDelivery(`123`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.submitPayOnDelivery(`123`, 0, 0, payOnDeliveryBeneficiary)
          .should.not.be.fulfilled
      })

      it(`should escrow funds for pay on delivery`, async () => {
        await erc20.approve(payOnD.address, 90, { from: erc20owner })
        await payOnD.submitPayOnDelivery(
          `123`,
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
        await parameterizer.ownerSet(`xyXYOMiningCost`, 100, {
          from: parameterizerOwner
        })
        await parameterizer.ownerSet(`xyEthMiningCost`, 100, {
          from: parameterizerOwner
        })
        await erc20.approve(payOnD.address, 500, { from: erc20owner })
        await erc20.approve(consensus.address, 500, { from: erc20owner })
        await payOnD.submitPayOnDelivery(
          `123`,
          20,
          90,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.submitPayOnDelivery(
          `1232`,
          200,
          90,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.submitPayOnDelivery(
          `1233`,
          90,
          200,
          payOnDeliveryBeneficiary,
          { value: 90, from: erc20owner }
        ).should.not.be.fulfilled
        await payOnD.submitPayOnDelivery(
          `1253`,
          300,
          200,
          payOnDeliveryBeneficiary,
          { value: 400, from: erc20owner }
        ).should.be.fulfilled
      })
      it(`should store requests in array`, async () => {
        await erc20.approve(payOnD.address, 500, { from: erc20owner })

        await payOnD.submitPayOnDelivery(`123`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.submitPayOnDelivery(`2`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.submitPayOnDelivery(
          `3`,
          10,
          100,
          payOnDeliveryBeneficiary,
          {
            from: erc20owner,
            value: 100
          }
        ).should.be.fulfilled
        await payOnD.submitPayOnDelivery(`4`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        await payOnD.submitPayOnDelivery(`5`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
        const numReqs = await payOnD.numRequests()
        numReqs.toNumber().should.be.equal(5)
        const req2 = await payOnD.requests(2)
        req2.ipfs.toNumber().should.be.equal(3)
        req2.beneficiary.should.be.equal(payOnDeliveryBeneficiary)
        req2.asker.should.be.equal(erc20owner)
        req2.xyoPayment.toNumber().should.be.equal(10)
        req2.weiPayment.toNumber().should.be.equal(100)
        req2.responseAt.toNumber().should.be.equal(0)
      })
    })
    describe(`submitting responses`, async () => {
      beforeEach(async () => {
        payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
          from: payOnDeliveryOwner
        })

        await erc20.approve(payOnD.address, 500, { from: erc20owner })

        await payOnD.submitPayOnDelivery(`1`, 0, 0, payOnDeliveryBeneficiary)
          .should.be.fulfilled
      })

      it(`should only allow responses from SCSC`, async () => {
        const byteResponses = new Uint8Array(1)
        byteResponses[0] = 1

        const packedBytes = `0x${abi
          .solidityPack([`bytes`], [byteResponses])
          .toString(`hex`)}`

        await payOnD.submitResponse(`1`, 1, packedBytes).should.not.be.fulfilled
        await consensus.submitResponse(`1`, 1, packedBytes, payOnD.address, {
          from: responseSubmitter
        }).should.be.fulfilled
      })
    })
  }
)
