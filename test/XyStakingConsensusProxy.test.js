const { TestHelper } = require(`zos`)
const { Contracts, ZWeb3 } = require(`zos-lib`)

ZWeb3.initialize(web3.currentProvider)

const stakingConsensus = Contracts.getFromLocal(`XyStakingConsensus`)
const ERC20 = Contracts.getFromNodeModules(`openzeppelin-eth`, `ERC20`)

require(`chai`).should()

contract(`XyStakingConsensus`, () => {
  beforeEach(async () => {
    this.project = await TestHelper()
  })

  it(`should create a proxy`, async () => {
    const proxy = await this.project.createProxy(stakingConsensus, {
      initMethod: `initialize`,
      initArgs: [
        `0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1`,
        `0x9561c133dd8580860b6b7e504bc5aa500f0f06a7`,
        `0x9561c133dd8580860b6b7e504bc5aa500f0f06a7`
      ]
    })
    const result = await proxy.methods.getLatestBlock().call()
    result.should.eq(`38`)
  })

  it(`should create a proxy for the EVM package`, async () => {
    const proxy = await this.project.createProxy(ERC20, { contractName: `XyStakingConsensus`, packageName: `openzeppelin-eth` })
    const result = await proxy.methods.getLatestBlock().call()
    result.should.eq(`38`)
  })
})
