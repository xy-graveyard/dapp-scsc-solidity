const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const Governance = Contracts.getFromLocal(`XyGovernance`)
const ERC20 = Contracts.getFromNodeModules(`openzeppelin-eth`, `ERC20`)

require(`chai`).should()

contract(`XyGovernance`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy for the EVM Package`, async () => {
    const proxy = await project.createProxy(Governance)
    const result = await proxy.methods.numResolutions(`1`).call()
    result.should.eq(`0`)
  })
})
