import { BigNumber } from 'bignumber.js'
import { time } from 'openzeppelin-test-helpers'
import { random } from 'node-forge'

const BN = web3.utils.BN
const PLCR = artifacts.require(`PLCRVoting.sol`)
const abi = require(`ethereumjs-abi`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const erc20TotalSupply = 10000000

require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

const generateSecret = (choice, salt) => `0x${abi.soliditySHA3([`uint`, `uint`], [choice, salt]).toString(`hex`)}`

contract(`PLCRVoting`, ([erc20owner, plcrOwner, voter1]) => {
  let erc20
  let plcr
  let pollId

  before(async () => {
    erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
      from: erc20owner
    })
    await erc20.transfer(voter1, 3000000, { from: erc20owner })
    plcr = await PLCR.new({
      from: plcrOwner
    })
    await erc20.approve(plcr.address, 3000000, { from: erc20owner })
    await erc20.approve(plcr.address, 3000000, { from: voter1 })

    plcr.initialize(erc20.address)
  })

  beforeEach(async () => {
    const plcrPoll = await plcr.startPoll(50, 60, 60)
    pollId = plcrPoll.logs[0].args.pollID
    // const voteQuorum = plcrPoll.logs[0].args.voteQuorum
    await plcr.requestVotingRights(150000, { from: erc20owner }).should.be
      .fulfilled
    await plcr.requestVotingRights(150000, { from: voter1 }).should.be.fulfilled
  })

  describe(`Function: requestVotingRights`, async () => {
    it(`should not allow a NOOP request Voting Rights`, async () => {
      await plcr.requestVotingRights().should.not.be.fulfilled
    })
    it(`should tell me if a poll exists`, async () => {
      await plcr.pollExists(pollId).should.be.fulfilled
    })
    it(`should request voting rights`, async () => {
      await plcr.requestVotingRights(150000, { from: erc20owner }).should.be
        .fulfilled
    })
  })
  describe(`Function: withdraw`, async () => {
    it(`should not withdraw voting rights if no tokens in request for voting rights`, async () => {
      await plcr.requestVotingRights({ from: erc20owner }).should.not.be
        .fulfilled
    })
    it(`should withdraw voting rights`, async () => {
      await plcr.requestVotingRights(5000, { from: erc20owner }).should.be
        .fulfilled
      await plcr.withdrawVotingRights(5000, { from: erc20owner }).should.be
        .fulfilled
    })
  })
  describe(`rescue tokens`, async () => {
    it(`should rescue tokens with a poll id`, async () => {
      const timestamp = await time.latest()
      const choice = 1
      const salt = Math.ceil(Math.random() * 10000)
      const secret = generateSecret(choice, salt)
      await plcr.commitVote(pollId, secret, 5000, 0, {
        from: voter1
      }).should.be.fulfilled
      await time.increaseTo(timestamp.add(new BN(130))) // move to after reveal period
      await plcr.rescueTokens(pollId, { from: voter1 }).should.be.fulfilled
    })
    it(`should not rescue tokens without a poll id`, async () => {
      await plcr.rescueTokens().should.not.be.fulfilled
    })
    it(`should not rescue tokens in multiple polls wihout poll ids`, async () => {
      await plcr.rescueTokensInMultiplePolls().should.not.be.fulfilled
    })
  })
  describe(`get number of tokens`, async () => {
    it(`should get number of passing tokens`, async () => {
      const timestamp = await time.latest()
      // console.log(`Latest time`, timestamp.toNumber())
      // const voteBalance = await plcr.voteTokenBalance(voter1)
      // console.log(`VOTER BALANCE`, new BN(voteBalance).toNumber())
      await time.increaseTo(timestamp.add(new BN(40))) // move to commit period

      const duringCommit = await time.latest()
      // console.log(`During commit`, duringCommit.toNumber())
      const choice = 1
      const salt = Math.ceil(Math.random() * 10000)
      const secret = generateSecret(choice, salt)
      await time.advanceBlock()

      await plcr.commitVote(pollId, secret, 5000, 0, {
        from: voter1
      }).should.be.fulfilled
      await time.increaseTo(duringCommit.add(new BN(60))) // move to reveal period

      const duringReveal = await time.latest()
      // console.log(`During reveal`, duringReveal.toNumber())

      await plcr.revealVote(pollId, choice, salt, { from: voter1 }).should.be
        .fulfilled
      await time.increaseTo(duringReveal.add(new web3.utils.BN(60))) // move to after reveal period
      await plcr.getNumPassingTokens(voter1, pollId, { from: voter1 }).should.be
        .fulfilled
    })
    it(`should generate an identifier for both plcr user and poll`, async () => {
      await plcr.attrUUID(plcrOwner, pollId).should.be.fulfilled
    })
  })
})
