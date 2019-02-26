const PLCR = artifacts.require(`PLCRVoting.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)

const erc20TotalSupply = 1000000

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `PLCRVoting`,
  ([
    erc20owner,
    pollId,
    pollIds,
    prevPollId,
    numTokens,
    secretHash,
    secretHashes,
    numsTokens,
    prevPollIds
  ]) => {
    let erc20
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
    })
    beforeEach(async () => {
      await PLCR.initialize(erc20.address)
    })
    describe(`PLCRVoting process`, () => {
      it(`should load ERC20 tokens into the voting contract`, async () => {
        await PLCR.requestVotingRights(10000)
          .should.be.fulfilled
      })
      it(`should withdraw ERC20 tokens from the voting contract`, async () => {
        await PLCR.withdrawVotingRights(10000)
          .should.be.fulfilled
      })
      it(`should unlock tokens locked in unrevealed vote`, async () => {
        await PLCR.withdrawVotingRights(pollId)
          .should.be.fulfilled
      })
      it(`should unlock tokens locked in unrevealed votes`, async () => {
        await PLCR.rescueTokensInMultiplePolls(pollIds)
          .should.be.fulfilled
      })
      it(`should commit vote using choice hash and secret salt to conceal vote`, async () => {
        await PLCR.commitVote(pollId, secretHash, numTokens, prevPollId)
          .should.be.fulfilled
      })
      it(`should commit votes using choice hashes and secret salts to conceal votes`, async () => {
        await PLCR.commitVotes(pollIds, secretHashes, numsTokens, prevPollIds)
          .should.be.fulfilled
      })
    })
  }
)
