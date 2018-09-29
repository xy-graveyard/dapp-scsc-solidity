import { ec } from 'elliptic'
import { keccak256 } from 'js-sha3'

const EC = ec
const ecc = new EC(`secp256k1`)

const XyoStaked = artifacts.require(`XyoStaked.sol`)
const StandardToken = artifacts.require(`StandardToken.sol`)

const BN = _x_ => web3.toBigNumber(_x_)

const TW = _x_ => BN(web3.toWei(BN(_x_)))

const nodeAddressFromKey = (key) => {
  const publicKey = key.getPublic()
  const fullKey = `${publicKey.x.toString(16, 32)}${publicKey.y.toString(16, 32)}`
  console.log(`fullKey: ${typeof fullKey}`)
  console.log(`fullKey: ${fullKey}`)
  const fullKeyBuffer = Buffer.from(fullKey.toString(16, 64), `hex`)
  console.log(`fullKeyBuffer: ${fullKeyBuffer.toString(`hex`)}`)
  console.assert(Buffer.isBuffer(fullKeyBuffer), `nodeAddressFromKey: fullKeyBuffer is not a Buffer`)
  const fullHash = keccak256(fullKeyBuffer)
  console.log(`FullHash: ${JSON.stringify(fullHash)}`)
  const address = fullHash.slice(fullHash.length - 40)
  return Buffer.from(address, `hex`)
}

const hashFromAddresses = (address1, address2) => {
  console.log(`hashFromAddreses: ${JSON.stringify(address1)}:${JSON.stringify(address2)}`)
  const hash = keccak256(Buffer.concat(
    [
      Buffer.from(address1, `hex`),
      Buffer.from(address2, `hex`)
    ]
  ))
  return Buffer.from(hash, `hex`)
}

const sign = (data, key) => {
  console.assert(Buffer.isBuffer(data), `sign: Data is not a Buffer`)
  const privateKey = Buffer.from(key.getPrivate(), `hex`)
  console.assert(Buffer.isBuffer(privateKey), `sign: privateKey is not a Buffer`)
  const msg = Buffer.from(data, `hex`)
  console.log(`signlen: ${msg.length}`)
  console.log(`sign: ${msg.toString(`hex`)}`)
  return ecc.sign(msg, key)
}

/* const createEccKey = () => {
  const privateHexString = `0dbbe8e4ae425a6d2687f1a7e3ba17bc98c673636790f1b8ad91193c05875ef1`
  const privBuffer = Buffer.from(privateHexString, `hex`)
  console.log(`createEccKey:privBuffer: ${privBuffer.toString(`hex`)}`)
  const key = ecc.keyFromPrivate(privBuffer)
  console.log(`createEccKey:privateKey: ${key.getPrivate().toString(16, 32)}`)
  return key
} */

const createEccKey = () => ecc.genKeyPair()

contract(`XyoStaked`, ([contractCreator, owner1]) => {
  console.log(`owner1: ${JSON.stringify(owner1)}`)
  const nodeKey = createEccKey()
  console.log(`Key: ${nodeKey.getPrivate().toString(16, 32)}`)
  const nodeAddress = nodeAddressFromKey(nodeKey)
  console.log(`nodeAddress: ${nodeAddress.toString(`hex`)}`)
  const hashedAddresses = hashFromAddresses(owner1.slice(2), nodeAddress.toString(`hex`))
  console.log(`hashedAddresses: ${hashedAddresses.toString(`hex`)}`)
  const signedDatagram = sign(hashedAddresses, nodeKey)
  console.log(`signedDatagram: ${JSON.stringify(signedDatagram)}`)

  let token = null
  let xyoStake = null

  const nodeAddressNumber = BN(`0x${nodeAddress.toString(`hex`)}`)

  it(`create contracts`, async () => {
    token = await StandardToken.new(TW(10000000), { from: contractCreator, gasPrice: 0 })
    console.log(`StandardToken Created: `, token.address)
    await token.transfer(owner1, TW(100), { from: contractCreator })
    const tokensForOwner1 = await token.balanceOf(owner1)
    console.log(`Tokens for Owner1: `, tokensForOwner1.toString(10))
    xyoStake = await XyoStaked.new(token.address, 1, { from: contractCreator, gasPrice: 0 })
    console.log(`XyoStaked Created: `, xyoStake.address)
  })

  it(`should claim a new node`, async () => {
    const v = BN(signedDatagram.recoveryParam + 27)
    const r = BN(`${signedDatagram.r}`)
    const s = BN(`${signedDatagram.s}`)
    // console.log(`hashedAddresses: 0x${nodeAddress.toString(`hex`)}, 0x${v.toString(`16`)}, 0x${r.toString(`16`)}, 0x${s.toString(`16`)}`)
    // const { logs } =
    await xyoStake.claim(nodeAddressNumber, v, r, s, { from: owner1 })
    // console.log(`logs: ${JSON.stringify(logs)}`)
  })

  it(`approve tokens for staking`, async () => {
    const { logs } = await token.approve(xyoStake.address, TW(10), { from: owner1 })
    console.log(`logs: ${JSON.stringify(logs)}`)
    const allowance = await token.allowance(owner1, xyoStake.address)
    console.log(`allowance: ${allowance}`)
  })

  it(`should stake a new node`, async () => {
    const { logs } = await xyoStake.stake(nodeAddressNumber, TW(10), { from: owner1 })
    console.log(`logs: ${JSON.stringify(logs)}`)
  })

  it(`length should be 1`, async () => {
    const len = await xyoStake.length()
    console.log(`len: ${len}`)
    assert.equal(parseInt(len, 10), 1, `len(${len}) should be 1`)
  })

  it(`should have nothing available to withdraw`, async () => {
    const result = await xyoStake.availableToWithdraw(owner1, { from: owner1 })
    console.log(`result: ${result}`)
    assert.equal(parseInt(result, 10), 0, `result(${parseInt(result, 10)}) should = 0`)
  })

  it(`should have stake request`, async () => {
    const requestsLen = await xyoStake.getStakeRequestsLen()
    console.log(`requestsLen: ${requestsLen}`)
    const request = await xyoStake.stakeRequests(0)
    console.log(`request: ${JSON.stringify(request)}`)
    assert.equal(BN(request[0]).toString(16, 20), nodeAddress.toString(`hex`), `request.node(${BN(request[0]).toString(16, 20)}) should = nodeAddress(${nodeAddress.toString(`hex`)})`)
    assert.equal(request[1].toString(10), TW(10).toString(10), `request.amount(${request[1].toString(10)}) should = TW(10)(${TW(10).toString(10)})`)
  })

  it(`should process one request`, async () => {
    const result = await xyoStake.process({ from: owner1 })
    console.log(`result: ${result}`)
    assert.equal(parseInt(result, 10), 1, `result(${parseInt(result, 10)}) should = 1`)
  })

  it(`should have stake`, async () => {
    const address0 = await xyoStake.get(0)
    console.log(`address0: ${address0}`)
    const node = await xyoStake.nodes(address0)
    console.log(`node: ${node}`)
    assert.equal(BN(node[1]).toString(16), nodeAddress.toString(`hex`), `node(${BN(node[1]).toString(16)}) should = nodeAddress(${nodeAddress.toString(`hex`)})`)
    assert.equal(BN(node[0]).toString(16), BN(owner1).toString(16, 20), `owner(${BN(node[0]).toString(16)}) should = owner1(${BN(owner1).toString(16, 20)})`)
  })
})
