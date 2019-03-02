const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const PayOnDelivery = Contracts.getFromLocal(`XyPayOnDelivery`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)

require(`chai`).should()

contract(`XyPayOnDeliveryProxy`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy`, async () => {
    const proxy = await project.createProxy(PayOnDelivery, {
      initMethod: `initialize`,
      initArgs: [
        `0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1`,
        `0x9561c133dd8580860b6b7e504bc5aa500f0f06a7`,
        `0x9561c133dd8580860b6b7e504bc5aa500f0f06a7`
      ]
    })
    const result = await proxy.methods.numRequests().call()
    result.should.eq(`number of requests`)
  })

  it(`should create a proxy for the EVM package`, async () => {
    const proxy = await project.createProxy(ERC20, { contractName: `XyPayOnDelivery`, packageName: `openzeppelin-eth` })
    const result = await proxy.methods.numRequests().call()
    result.should.eq(`number of requests`)
  })
})
