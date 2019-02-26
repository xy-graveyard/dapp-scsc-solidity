const PLCR = artifacts.require(`PLCRVoting.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)

const erc20TotalSupply = 1000000
const { encodeCall } = require(`zos-lib`)

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `PLCRVoting`,
  ([
    erc20owner
  ]) => {
    let erc20
    let data
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      data = encodeCall(
        `initialize`,
        [`address`],
        [erc20.address]
      )
      const newPLCR = await PLCR.new()
      await newPLCR.sendTransaction()
    })
    beforeEach(async () => {
      await PLCR.initialize(erc20.address)
    })
  }
)
