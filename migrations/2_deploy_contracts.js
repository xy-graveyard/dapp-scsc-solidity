const PLCR = artifacts.require(`PLCRVoting.sol`)
const attrStore = artifacts.require(`AttributeStore.sol`)
const dll = artifacts.require(`DLL.sol`)
const XYOERC20 = artifacts.require(`XyFaucet.sol`)
const BlockProducer = artifacts.require(`XyBlockProducer.sol`)
const SCSC = artifacts.require(`XyStakingConsensus.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PayOnD = artifacts.require(`XyPayOnDelivery.sol`)
const base58 = require(`bs58`)
const fs = require(`fs`)

const config = JSON.parse(fs.readFileSync(`../config/testParams.json`))
const params = config.integrationTests
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

const isMatrixDeploy = true
const totalSupply = 10000000000
const stakeAmt = 10000

module.exports = async function (deployer, network, [contractsOwner, bp2]) {
  console.log(`I am `, contractsOwner, network)

  await deployer.deploy(dll)
  await deployer.deploy(attrStore)
  await deployer.link(attrStore, PLCR)
  await deployer.link(dll, PLCR)
  const plcrVoting = await deployer.deploy(PLCR)
  const erc20 = await deployer.deploy(XYOERC20, totalSupply, `XYO Token`, `XYO`, { from: contractsOwner })
  const gov = await deployer.deploy(Governance)
  const blockProducerInstance = await deployer.deploy(BlockProducer)
  const consensus = await deployer.deploy(SCSC)
  const pOnD = await deployer.deploy(PayOnD)

  await blockProducerInstance.initialize()
  await pOnD.initialize(consensus.address, erc20.address)
  await plcrVoting.initialize(erc20.address)
  await gov.initialize(
    erc20.address,
    plcrVoting.address,
    parameters
  )
  await consensus.initialize(erc20.address, blockProducerInstance.address, gov.address)

  console.log(`INNITIALIZED WITH PARAMS`, parameters)

  printAddress([SCSC, Governance, XYOERC20, PayOnD, BlockProducer])

  await setupBP(blockProducerInstance, consensus, erc20, contractsOwner, contractsOwner)

  if (isMatrixDeploy) {
    await erc20.approve(erc20.address, (totalSupply - stakeAmt * 2) * 1 ** 18)
  } else {
    await setupBP(blockProducerInstance, consensus, erc20, bp2, contractsOwner)
    await addRequest(pOnD, contractsOwner)
  }
}

const getBytes32FromIpfsHash = ipfsListing => `0x${base58
  .decode(ipfsListing)
  .slice(2)
  .toString(`hex`)}`

const printAddress = contracts => contracts.map(contract => console.log(`${contract.contractName}: ${contract.address}`))

const setupBP = async function (
  stakable,
  consensus,
  erc20,
  bpAddress,
  ercOwner
) {
  await stakable.create(bpAddress)
  console.log(`Created BP Stakee ${bpAddress}`)

  if (bpAddress !== ercOwner) {
    await erc20.transfer(bpAddress, stakeAmt, {
      from: ercOwner
    })
  }
  console.log(`Approving SCSC ${consensus.address} from BP Stakee ${bpAddress}`)

  const allowance = await erc20.allowance(bpAddress, consensus.address)
  const curAllowance = allowance.toNumber()
  await erc20.approve(consensus.address, curAllowance + stakeAmt, {
    from: bpAddress
  })
  console.log(`Staking BP Stakee ${bpAddress}`)

  const stakingTx = await consensus.stake(bpAddress, stakeAmt, {
    from: bpAddress
  })
  const stakingId = stakingTx.logs[0].args.stakingId
  console.log(`Activating BP Stakee ${bpAddress}`)

  await consensus.activateStake(stakingId, { from: bpAddress })
  console.log(`Activated BP Stakee ${bpAddress} stake id: ${stakingId}`)
}

const addRequest = async function (pOnD, requesterAddress) {
  const IpfsHash = `QmZyycMiLogkpoA2C8Nz44KCvFbY6vZBAkYKUBz8hMab7Q`
  const bytesStr = getBytes32FromIpfsHash(IpfsHash)
  const tx = await pOnD.requestPayOnDelivery(
    web3.utils.padLeft(bytesStr, 64),
    0,
    0,
    0,
    requesterAddress,
    { from: requesterAddress }
  )
  console.log(`Submitted Request`, tx.logs[0].args.requestId)
  return true
}
