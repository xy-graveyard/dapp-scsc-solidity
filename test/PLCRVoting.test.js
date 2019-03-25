import { BigNumber } from "bignumber.js"

const PLCR = artifacts.require(`PLCRVoting.sol`)

const ERC20 = artifacts.require(`XyERC20Token.sol`)

const erc20TotalSupply = 10000000

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
    let pollId
    let voteQuorum
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      plcr = await PLCR.new({
        from: plcrOwner
      })

      plcr.initialize(erc20.address)
      const plcrPoll = await plcr.startPoll(3, 60, 60)
      pollId = plcrPoll.logs[0].args.pollID
      voteQuorum = plcrPoll.logs[0].args.voteQuorum
    })

    describe(`Function: requestVotingRights`, (accounts) => {
      it(`should not allow a NOOP request Voting Rights`, async () => {
        await plcr.requestVotingRights().should.not.be.fulfilled
      })
      it(`should tell me if a poll exists`, async () => {
        await plcr.pollExists(pollId).should.be.fulfilled
      })
      it(`should request voting rights`, async () => {
        await plcr.requestVotingRights(150000).should.be.fulfilled
      })
      it(`should not withdraw voting rights if no tokens in request for voting rights`, async () => {
        await plcr.requestVotingRights().should.not.be.fulfilled
      })
      it(`should withdraw voting rights`, async () => {
        await plcr.withdrawVotingRights(150000).should.be.fulfilled
      })
      it(`should rescue tokens with a poll id`, async () => {
        await plcr.rescueTokens(pollId).should.be.fulfilled
      })
      it(`should not rescue tokens without a poll id`, async () => {
        await plcr.rescueTokens().should.not.be.fulfilled
      })
      it(`should not rescue tokens in multiple polls wihout poll ids`, async () => {
        await plcr.rescueTokensInMultiplePolls().should.not.be.fulfilled
      })
      it(`should get number of passing tokens`, async () => {
        await plcr.getNumPassingTokens(plcrOwner, pollId).should.be.fulfilled
      })
      it(`should generate an identifier for both plcr user and poll`, async () => {
        await plcr.attrUUID(plcrOwner, pollId).should.be.fulfilled
      })
    })
  }
)
