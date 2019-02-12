const PLCR = artifacts.require(`PLCRVoting.sol`)
const attrStore = artifacts.require(`AttributeStore.sol`)
const dll = artifacts.require(`DLL.sol`)
const safeERC20 = artifacts.require(`SafeERC20.sol`)
const Stakable = artifacts.require(`XyStakableToken.sol`)
const SCSC = artifacts.require(`XyStakingConsensus.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)

const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`../config/params.json`))
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
  params.xyUnstakeCooldown
]

module.exports = async function (deployer, network, [contractsOwner]) {
  await deployer.deploy(dll)
  await deployer.deploy(attrStore)

  await deployer.link(attrStore, PLCR)
  await deployer.link(dll, PLCR)

  const plcrVoting = await deployer.deploy(PLCR)
  const erc20 = await deployer.deploy(safeERC20, `XYO Token`, `XYO`, {
    from: contractsOwner
  })
  const gov = await Governance.new({
    from: contractsOwner
  })
  const stakableToken = await deployer.deploy(Stakable)

  const consensus = await SCSC.new(
    erc20.address,
    stakableToken.address,
    gov.address,
    {
      from: contractsOwner
    }
  )
  await plcrVoting.init(safeERC20.address)

  await gov.init(
    consensus.address,
    erc20.address,
    plcrVoting.address,
    parameters,
    {
      from: contractsOwner
    }
  )

  console.log(`Done linking`)
}
