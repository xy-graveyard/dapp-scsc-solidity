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
require(`chai`)
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
    let parameterizer
    let plcr
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      plcr = await PLCR.new({
        from: plcrOwner
      })
      await plcr.initialize(erc20.address)
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
      beforeEach(async () => {
      })

      // Put this first to ensure test does not conflict with proposals already made.
      it(`should not allow a NOOP reparameterization`, async () => {

      })

      it(`should add a new reparameterization proposal`, async () => {

      })

      it(`should not allow a reparameterization for a proposal that already exists`, async () => {

      })

      it(`should revert if token transfer from user fails`, async () => {

      })
    })
  }
)
