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
  `XyPayOnDelivery`,
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
      governance = await Governance.new({
        from: governanceOwner
      })
      governance.init(governanceResolver,
        erc20.address,
        plcr.address,
        parameters, { from: governanceOwner })
    })
    describe(`Proposing an action`, () => {
      it(`should allow proposing a new action when minDeposit is 0`, async () => {
        await governance.proposeNewAction(1, 50, 0).should.be.fulfilled
      })
      it(`should not allow proposing a new action on stakee if one is in progress`, async () => {
        await governance.proposeNewAction(1, 50, 0).should.be.fulfilled
        await governance.proposeNewAction(1, 50, 0).should.not.be.fulfilled
      })
    })
  }
)
