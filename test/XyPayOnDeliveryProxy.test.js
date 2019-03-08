const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const PayOnDelivery = Contracts.getFromLocal(`XyPayOnDelivery`)
const ERC20 = Contracts.getFromNodeModules(`openzeppelin-eth`, `ERC20`)

require(`chai`).should()

contract(`XyPayOnDelivery`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy for the EVM Package`, async () => {
    const proxy = await project.createProxy(PayOnDelivery)
    const result = await proxy.methods.numRequests().call()
    result.should.eq(`0`)
  })
})
