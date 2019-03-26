import { time } from 'openzeppelin-test-helpers'

const coerceNumber = (val) => {
  if (val instanceof web3.utils.BN) return val.toNumber()
  if (typeof val === `number`) return val
  if (typeof val === `string`) return parseInt(val, 10)
  return -1
}
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
