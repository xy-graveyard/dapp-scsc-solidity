import { time } from 'openzeppelin-test-helpers'

const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`./config/testParams.json`))

const coerceNumber = (val) => {
  if (val instanceof web3.utils.BN) return val.toNumber()
  if (typeof val === `number`) return val
  if (typeof val === `string`) return parseInt(val, 10)
  return -1
}

export const parameters = params => [
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

export async function latestBlock () {
  return coerceNumber(await time.latestBlock())
}

export async function advanceBlock () {
  return time.advanceBlock()
}

export async function advanceToBlock (number) {
  const blockNumber = await latestBlock()
  if (blockNumber >= number) {
    return number
  }
  await advanceBlock()
  return advanceToBlock(number)
}
