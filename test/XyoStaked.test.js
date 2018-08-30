// import assertRevert from 'openzeppelin-solidity/test/helpers/assertRevert'
// import {advanceBlock} from 'openzeppelin-solidity/test/helpers/advanceToBlock'
// import EVMRevert from 'openzeppelin-solidity/test/helpers/EVMRevert'
import { ec } from 'elliptic'
import { keccak256 } from 'js-sha3'

const EC = ec
const ecc = new EC(`secp256k1`)

const XyoStaked = artifacts.require(`XyoStaked.sol`)
const StandardToken = artifacts.require(`StandardToken.sol`)

const BN = _x_ => web3.toBigNumber(_x_)

// const FW = _x_ => BN(web3.fromWei(BN(_x_)));

const TW = _x_ => BN(web3.toWei(BN(_x_)))

// const CMP = (_x_, _y_) => BN(_x_).eq(BN(_y_));

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

  it(`create contracts`, async () => {
    token = await StandardToken.new(TW(10000000), { from: contractCreator, gasPrice: 0 })
    console.log(`StandardToken Created: `, token.address)
    xyoStake = await XyoStaked.new(token.address, 30, { from: contractCreator, gasPrice: 0 })
    console.log(`XyoStaked Created: `, xyoStake.address)
  })

  it(`should claim a new node`, async () => {
    const v = BN(signedDatagram.recoveryParam + 27)
    const r = BN(`${signedDatagram.r}`)
    const s = BN(`${signedDatagram.s}`)
    // console.log(`hashedAddresses: 0x${nodeAddress.toString(`hex`)}, 0x${v.toString(`16`)}, 0x${r.toString(`16`)}, 0x${s.toString(`16`)}`)
    // const { logs } =
    await xyoStake.claim(BN(`0x${nodeAddress.toString(`hex`)}`), v, r, s, { from: owner1 })
    // console.log(`logs: ${JSON.stringify(logs)}`)
  })

  /* it(`should stake a new node`, async () => {
    const { logs } = await xyoStake.stake(nodeAddress, TW(10), { from: owner1 })
    console.log(logs)
  }) */

  /* it ('should be able to retrieve the hash after stored', async function _() {
        let storedHash = 'QmfM2r8seH2GiRaC4esTjeraXEachRt8ZsSeGaWTPLyMoG'
        await this.vault.storeInVault('TEST', storedHash, {from: dataOwner})
        let hash = await this.vault.getVaultContents('TEST')
        hash.should.be.equal(storedHash)
    })

    it ('should be able to convert string to uint', async function _() {
        let result = await this.vault.encodeShortString("Test Vault")
        let result2 = await this.vault.encodeShortString("Test Vault2")
        let result3 = await this.vault.encodeShortString("TEST Vault")
        let result4 = await this.vault.encodeShortString("TESty Vault")
        result.should.be.bignumber.not.equal(result2).not.equal(result3).not.equal(result4)
    }) */
})
