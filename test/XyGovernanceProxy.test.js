const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const Governance = Contracts.getFromLocal(`XyGovernance`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)

require(`chai`).should()

contract(`XyGovernanceProxy`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy`, async () => {
    const proxy = await project.createProxy(Governance)
    const result = await proxy.methods.proposeNewAction(1, 50, 0).call()
    result.should.eq(true)
  })

  it(`should create a proxy for the EVM package`, async () => {
    const proxy = await project.createProxy(ERC20, { contractName: `XyGovernance`, packageName: `openzeppelin-eth` })
    const result = await proxy.methods.proposeNewAction(1, 50, 0).call()
    result.should.eq(true)
  })
})
