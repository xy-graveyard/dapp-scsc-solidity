import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"
import { request } from "http"
import { expect } from 'chai'

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)
const PayOnDeliveryMock = artifacts.require(`XyPayOnDeliveryMock.sol`)

const PayOnDelivery = artifacts.require(`XyPayOnDelivery.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock2.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Parameterizer = artifacts.require(`XyParameterizer.sol`)
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
  params.xyWeiMiningMin,
  params.xyXYORequestBountyMin,
  params.xyStakeCooldown,
  params.xyUnstakeCooldown,
  params.xyProposalsEnabled
]
const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

contract(
  `XyParameterizer`,
  ([
    governanceOwner,
    governanceResolver,
    erc20owner,
    plcrOwner
  ]) => {
    let erc20
    let governance
    let plcr
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      plcr = await PLCR.new({
        from: plcrOwner
      })
      await plcr.init(erc20.address)
    })
    beforeEach(async () => {
      parameterizer = await Parameterizer.new({
        from: governanceOwner
      })
      await parameterizer.initialize(governanceResolver,
        erc20.address,
        plcr.address,
        parameters, { from: governanceOwner })
    })
    describe(`Function: proposeReparameterization`, (accounts) => {
      const [proposer, secondProposer] = accounts
      const pMinDeposit = bigTen(paramConfig.pMinDeposit)

      let token
      let parameterizer

      beforeEach(async () => {
        const { paramProxy, tokenInstance } = await utils.getProxies()
        parameterizer = paramProxy
        token = tokenInstance

        await utils.approveProxies(accounts, token, false, parameterizer, false)
      })

      // Put this first to ensure test does not conflict with proposals already made.
      it(`should not allow a NOOP reparameterization`, async () => {
        // Get value to be reparameterized.
        const voteQuorum = await parameterizer.get.call(`voteQuorum`)

        try {
          await utils.as(proposer, parameterizer.proposeReparameterization, `voteQuorum`, voteQuorum.toString())
        } catch (err) {
          assert(utils.isEVMException(err), err.toString())
          return
        }
        assert(false, `Performed NOOP reparameterization`)
      })

      it(`should add a new reparameterization proposal`, async () => {
        const applicantStartingBalance = await token.balanceOf.call(proposer)

        const receipt = await parameterizer.proposeReparameterization(`pVoterQuorum`, 51)

        const propID = utils.getReceiptValue(receipt, `propID`)
        const paramProposal = await parameterizer.proposals.call(propID)

        assert.strictEqual(paramProposal[6].toString(10), `51`, `The reparameterization proposal ` +
          `was not created, or not created correctly.`)

        const applicantFinalBalance = await token.balanceOf.call(proposer)
        const expected = applicantStartingBalance.sub(pMinDeposit)
        assert.strictEqual(
          applicantFinalBalance.toString(10), expected.toString(10),
          `tokens were not properly transferred from proposer`
        )
      })

      it(`should not allow a reparameterization for a proposal that already exists`, async () => {

      })

      it(`should revert if token transfer from user fails`, async () => {

      })
    })
  }
)
