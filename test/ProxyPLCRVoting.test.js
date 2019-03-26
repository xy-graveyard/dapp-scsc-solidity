const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const PLCRVoting = Contracts.getFromLocal(`PLCRVoting`)
const ERC20 = Contracts.getFromNodeModules(`openzeppelin-eth`, `ERC20`)
const erc20TotalSupply = 1000000

require(`chai`).should()

contract(`PLCRVoting`, () => {
  let project
  beforeEach(async () => {
    project = await TestHelper()
  })

  it(`should create a proxy for the EVM package for PLCR Voting`, async () => {
    const proxy = await project.createProxy(PLCRVoting)
  })
})
