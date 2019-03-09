const PLCR = artifacts.require(`PLCRVoting.sol`)
const attrStore = artifacts.require(`AttributeStore.sol`)
const dll = artifacts.require(`DLL.sol`)
const XYOERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakable = artifacts.require(`XyStakableToken.sol`)
const SCSC = artifacts.require(`XyStakingConsensus.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PayOnD = artifacts.require(`XyPayOnDelivery.sol`)

const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`../config/testParams.json`))
const params = config.integrationTests
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

const setupBP = async function (stakable, consensus, erc20, bpAddress) {
  const stakeeTx = await stakable.mint(bpAddress)
  const stakee = stakeeTx.logs[0].args.tokenId
  console.log(`New Stakee`, stakee, bpAddress, stakeeTx.logs.args)

  await stakable.enableBlockProducer(stakee, true)

  await erc20.approve(consensus.address, 100000, { from: bpAddress })
  const stakingTx = await consensus.stake(stakee, 10000)
  const stakingId = stakingTx.logs[0].args.stakingId
  console.log(`New Staking Id`, stakingId)

  await consensus.activateStake(stakingId)
}
const printAddress = contracts => contracts.map(contract => console.log(`${contract.contractName}: ${contract.address}`))

module.exports = async function (deployer, network, [contractsOwner]) {
  console.log(`I am `, contractsOwner, network)
  await deployer.deploy(dll)
  await deployer.deploy(attrStore)

  await deployer.link(attrStore, PLCR)
  await deployer.link(dll, PLCR)

  const plcrVoting = await deployer.deploy(PLCR)
  const erc20 = await deployer.deploy(
    XYOERC20,
    100000000 * 1 ** 18,
    `XYO Token`,
    `XYO`,
    {
      from: contractsOwner
    }
  )
  const gov = await deployer.deploy(Governance)
  const stakableToken = await deployer.deploy(Stakable)

  const consensus = await deployer.deploy(
    SCSC,
    {
      from: contractsOwner
    }
  )
  const pOnD = await deployer.deploy(PayOnD, {
    from: contractsOwner
  })
  await pOnD.initialize(consensus.address, erc20.address)
  await plcrVoting.initialize(erc20.address)
  await consensus.initialize(
    erc20.address,
    stakableToken.address,
    gov.address
  )
  await gov.initialize(
    consensus.address,
    erc20.address,
    plcrVoting.address,
    parameters,
    {
      from: contractsOwner
    }
  )

  console.log(`INNITIALIZED WITH PARAMS`, parameters)
  await setupBP(stakableToken, consensus, erc20, contractsOwner)
  printAddress([SCSC, Governance, XYOERC20, PayOnD, Stakable])
}
