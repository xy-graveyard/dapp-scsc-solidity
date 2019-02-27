const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const stakableToken = Contracts.getFromLocal(`XyStakableToken`)
const ERC20 = Contracts.getFromNodeModules(`openzeppelin-eth`, `ERC20`)

require(`chai`).should()

contract(`XyStakableToken`, () => {
  beforeEach(async () => {
    this.project = await TestHelper()
  })

  it(`should create a proxy`, async () => {
    const proxy = await this.project.createProxy(stakableToken)
    const result = await proxy.methods.mint(`0xffcf8fdee72ac11b5c542428b35eef5769c409f0`).call()
    result.should.eq(true)
  })

  it(`should create a proxy for the EVM package`, async () => {
    const proxy = await this.project.createProxy(ERC20, { contractName: `XyStakableToken`, packageName: `openzeppelin-eth` })
    const result = await proxy.methods.mint(`0xffcf8fdee72ac11b5c542428b35eef5769c409f0`).call()
    result.should.eq(true)
  })
})
