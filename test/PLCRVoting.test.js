const PLCR = artifacts.require(`PLCRVoting.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)

const fs = require(`fs`)

const erc20TotalSupply = 1000000

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `PLCRVoting`,
  ([
    erc20owner
  ]) => {
    let erc20
    before(async () => {})
    beforeEach(async () => {})
    describe(`PLCRVoting process`, () => {})
  }
)
