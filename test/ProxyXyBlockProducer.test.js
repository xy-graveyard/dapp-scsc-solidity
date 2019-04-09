const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const stakableToken = Contracts.getFromLocal(`XyBlockProducer`)

require(`chai`).should()

contract(`ProxyXyBlockProducer`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy for the EVM package and not just bring in any stakee`, async () => {
    const proxy = await project.createProxy(stakableToken)
    const result = await proxy.methods.exists(`0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1`).call()
    result.should.eq(false)
  })
})
