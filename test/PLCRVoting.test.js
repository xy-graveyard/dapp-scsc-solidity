import { BigNumber } from "bignumber.js"

const PLCR = artifacts.require(`PLCRVoting.sol`)

const ERC20 = artifacts.require(`XyERC20Token.sol`)

const erc20TotalSupply = 1000000

require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

contract(
  `PLCRVoting`,
  ([
    erc20owner,
    plcrOwner
  ]) => {
    let erc20
    let plcr
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      plcr = await PLCR.new({
        from: plcrOwner
      })
      await erc20.transfer(plcrOwner, 100)
      await erc20.approve(plcr.address, 100, { from: plcrOwner })
    })
    beforeEach(async () => {
      plcr = await PLCR.new({
        erc20
      })
    })
    describe(`Function: requestVotingRights`, (accounts) => {
      it(`should not allow a NOOP request Voting Rights`, async () => {
        await plcr.requestVotingRights().should.not.be.fulfilled
      })
      it(`should request voting rights`, async () => {
        await plcr.requestVotingRights(50).should.be.fulfilled
      })
      it(`should not withdraw voting rights if no tokens in request for voting rights`, async () => {
        await plcr.requestVotingRights().should.not.be.fulfilled
      })
      it(`should rescue tokens with a poll id`, async () => {
        await plcr.rescueTokens(1).should.be.fulfilled
      })
      it(`should not rescue tokens wihout a poll id`, async () => {
        await plcr.rescueTokens().should.not.be.fulfilled
      })
      it(`should not rescue tokens in multiple polls wihout poll ids`, async () => {
        await plcr.rescueTokensInMultiplePolls().should.not.be.fulfilled
      })
    })
  }
)
