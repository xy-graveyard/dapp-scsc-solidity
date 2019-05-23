import {time} from 'openzeppelin-test-helpers'
import {BigNumber} from 'ethers/utils'

const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Bond = artifacts.require(`XyBond.sol`)
const StakingConsensus = artifacts.require(`XyStakingConsensus.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const BlockProducer = artifacts.require(`XyBlockProducer.sol`)
const {testParams} = require(`./utils.test`)

require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

const erc20TotalSupply = 1000000
const governablePeriod = 200
const bondPeriod = 60 * 60 * 24 * 3 // 3 day bond

const encodeApproveAndCall = (to, expiration) =>
  web3.utils.toHex(`${web3.eth.abi.encodeParameters([`address`, `uint`], [to, expiration])}`)

contract(
  `XyBond`,
  ([governor, erc20Owner, consensusOwner, govOwner, user1, stakee1, stakee2, user2]) => {
    let erc20, bonder, consensus, expirationDate, governableStub
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20Owner
      })
    })

    beforeEach(async () => {
      const whatTime = await time.latest()
      expirationDate = whatTime.toNumber() + bondPeriod
      bonder = await Bond.new({from: governor})

      consensus = await StakingConsensus.new({from: consensusOwner})
      governableStub = await Governance.new({
        from: govOwner
      })
      const bpStub = await BlockProducer.new({
        from: govOwner
      })
      await governableStub.initialize(erc20.address, govOwner, testParams(), {from: govOwner})
      await governableStub.ownerSet(`XyBondContract`, bonder.address, {from: govOwner})
      await consensus.initialize(erc20.address, bpStub.address, governableStub.address, {
        from: consensusOwner
      })
      await bonder.initialize(erc20.address, consensus.address, governablePeriod)
    })

    describe(`Depositing`, () => {
      it(`should allow deposit`, async () => {
        const amount = 100

        await erc20.approve(bonder.address, amount, {from: erc20Owner}).should.be.fulfilled
        await bonder.createBond(amount, expirationDate, {from: erc20Owner}).should.be.fulfilled

        const bondId = await bonder.bonds(0)
        const bond = await bonder.bond(bondId)
        const balance = await erc20.balanceOf(bonder.address)
        balance.toNumber().should.be.equal(amount)
        bond.value.toNumber().should.be.equal(amount)
        bond.expirationSec.toNumber().should.be.equal(expirationDate)
        bond.owner.should.be.equal(erc20Owner)
      })
      it(`should allow deposit via approveAndCall`, async () => {
        const amount = 100

        const solidityEncoded = encodeApproveAndCall(erc20Owner, expirationDate)

        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, {from: erc20Owner})
          .should.be.fulfilled

        const bondId = await bonder.bonds(0)
        const bond = await bonder.bond(bondId)
        const balance = await erc20.balanceOf(bonder.address)
        balance.toNumber().should.be.equal(amount)
        bond.value.toNumber().should.be.equal(amount)
        bond.expirationSec.toNumber().should.be.equal(expirationDate)
        bond.owner.should.be.equal(erc20Owner)
      })
      it(`should allow bonding via approveAndCall for third party`, async () => {
        const amount = 100

        const solidityEncoded = encodeApproveAndCall(user2, expirationDate)

        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, {from: erc20Owner})
          .should.be.fulfilled

        const bondId = await bonder.bonds(0)
        const bond = await bonder.bond(bondId)
        const balance = await erc20.balanceOf(bonder.address)
        balance.toNumber().should.be.equal(amount)
        bond.value.toNumber().should.be.equal(amount)
        bond.expirationSec.toNumber().should.be.equal(expirationDate)
        bond.owner.should.be.equal(user2)
      })
    })
    describe(`Withdrawing`, () => {
      const amount = 100
      let bondId

      beforeEach(async () => {
        const whatTime = await time.latest()
        expirationDate = whatTime.toNumber() + bondPeriod
        await erc20.transfer(user1, amount, {from: erc20Owner})
        const bal1 = await erc20.balanceOf(user1)
        const solidityEncoded = encodeApproveAndCall(user1, expirationDate)
        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, {from: user1}).should.be
          .fulfilled
        bondId = await bonder.bonds(0)
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(bal1.toNumber() - amount)
      })

      it(`should allow governor withdraw`, async () => {
        await bonder.withdrawTo(bondId, user1, {from: governor}).should.be.fulfilled
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(amount)
        const contractBalance = await erc20.balanceOf(bonder.address)
        contractBalance.toNumber().should.be.equal(0)
      })
      it(`should not allow anyone to withdraw `, async () => {
        await bonder.withdrawTo(bondId, user1, {from: erc20Owner}).should.not.be.fulfilled
      })

      it(`should not allow governor to withdraw after governable period`, async () => {
        const bond = await bonder.bond(bondId)
        await time.increaseTo(governablePeriod + bond.creationSec.toNumber() + 1) // move to after reveal period
        await bonder.withdrawTo(bondId, user1, {from: governor}).should.not.be.fulfilled
      })

      it(`should not allow user to withdraw until after expiry`, async () => {
        const bal1 = await erc20.balanceOf(user1)

        await bonder.withdrawTo(bondId, user1, {from: user1}).should.not.be.fulfilled
        await time.increaseTo(expirationDate + 1)
        await bonder.withdrawTo(bondId, user1, {from: erc20Owner}).should.not.be.fulfilled
        await bonder.withdrawTo(bondId, user1, {from: user1}).should.be.fulfilled
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(bal1.toNumber() + amount)
      })
    })

    describe(`staking nodes`, () => {
      const amount = 100
      let bondId

      beforeEach(async () => {
        const whatTime = await time.latest()
        const solidityEncoded = encodeApproveAndCall(user1, expirationDate)
        await erc20.transfer(user1, amount, {from: erc20Owner})
        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, {from: user1}).should.be
          .fulfilled
        bondId = await bonder.bonds(0)
      })

      it(`should allow staking stakees`, async () => {
        await bonder.stake(bondId, user1, [stakee1], [amount], {from: user1}).should.be.fulfilled
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        const stake = await consensus.stakeData(stakingId)
        stake.amount.toNumber().should.be.equal(amount)
        const bondId1 = await consensus.bondedStake(stakingId)
        bondId1.should.be.equal(bondId)
      })
      it(`should allow staking stakees by governor`, async () => {
        await bonder.stake(bondId, user1, [stakee1], [amount], {from: governor}).should.be.fulfilled
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        const stake = await consensus.stakeData(stakingId)
        stake.amount.toNumber().should.be.equal(amount)
        stake.staker.should.be.equal(user1)
        const bondId1 = await consensus.bondedStake(stakingId)
        bondId1.should.be.equal(bondId)
      })
      it(`should not allow staking stakees by a non owner or governor of stake`, async () => {
        await bonder.stake(bondId, user1, [stakee1], [amount], {from: user2}).should.not.be
          .fulfilled
        await consensus.stakerToStakingIds(user1, 0).should.not.be.fulfilled
      })
      it(`should not allow staking stakees over bond balance`, async () => {
        await bonder.stake(bondId, user1, [stakee1], [amount * 4], {from: user2}).should.not.be
          .fulfilled
        await consensus.stakerToStakingIds(user1, 0).should.not.be.fulfilled
      })
      it(`should allow staking multiple`, async () => {
        await bonder.stake(bondId, user1, [stakee1, user2].sort(), [amount - 10, 10], {from: user1})
          .should.be.fulfilled
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        const stake = await consensus.stakeData(stakingId)
        stake.amount.toNumber().should.be.equal(amount - 10)
        stake.staker.should.be.equal(user1)
      })
      it(`should allow sending eth and staking multiple`, async () => {
        const ethAmount = 333
        const before = await web3.eth.getBalance(user1)

        await bonder.sendEthAndStake(bondId, user1, [stakee1, user2].sort(), [amount - 10, 10], {
          from: governor,
          value: ethAmount
        }).should.be.fulfilled
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        const stake = await consensus.stakeData(stakingId)
        stake.amount.toNumber().should.be.equal(amount - 10)
        stake.staker.should.be.equal(user1)
        const after = await web3.eth.getBalance(user1)
        ethAmount.should.be.equal(new BigNumber(after).sub(new BigNumber(before)).toNumber())
      })
    })
    describe(`unstaking nodes`, () => {
      const amount = 100
      let bondId

      beforeEach(async () => {
        const whatTime = await time.latest()
        expirationDate = whatTime.toNumber() + bondPeriod
        const solidityEncoded = encodeApproveAndCall(user1, expirationDate)
        await erc20.transfer(user1, amount, {from: erc20Owner})
        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, {from: user1}).should.be
          .fulfilled
        bondId = await bonder.bonds(0)
        await bonder.stake(bondId, user1, [stakee1], [amount / 4], {from: user1}).should.be
          .fulfilled
      })

      it(`should allow unstaking stakees`, async () => {
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        await bonder.unstake(bondId, stakingId, {from: user1}).should.be.fulfilled
        await consensus.stakerToStakingIds(user1, 0).should.not.be.fulfilled
      })

      it(`should allow govenor to unstake stakees`, async () => {
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        await bonder.unstake(bondId, stakingId, {from: governor}).should.be.fulfilled
        await consensus.stakerToStakingIds(user1, 0).should.not.be.fulfilled
      })

      it(`should not allow multiple unstakes`, async () => {
        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        await bonder.unstake(bondId, stakingId, {from: user1}).should.be.fulfilled
        await bonder.unstake(bondId, stakingId, {from: user1}).should.not.be.fulfilled
      })
      it(`should allow multiple unstakes from a bond with multiple stakes`, async () => {
        await bonder.stake(bondId, user1, [stakee2], [amount / 5], {from: user1}).should.be
          .fulfilled

        const stakingId = await consensus.stakerToStakingIds(user1, 0)
        const stakingId2 = await consensus.stakerToStakingIds(user1, 1)
        const bondStakeId = await consensus.bondStakes(bondId, 0)
        const bondStakeId2 = await consensus.bondStakes(bondId, 1)
        const bondStakeIndex = await consensus.bondStakeIndex(bondStakeId)
        const bondStakeIndex2 = await consensus.bondStakeIndex(bondStakeId2)
        const numStakes = await consensus.numBondStakes(bondId)
        stakingId.should.be.equal(bondStakeId)
        stakingId2.should.be.equal(bondStakeId2)
        bondStakeIndex.toNumber().should.be.equal(0)
        bondStakeIndex2.toNumber().should.be.equal(1)
        numStakes.toNumber().should.be.equal(2)
        const stakeData = await consensus.stakeData(stakingId)

        await bonder.unstake(bondId, stakingId2, {from: user1}).should.be.fulfilled
        const numStakes2 = await consensus.numBondStakes(bondId)

        const stakingId3 = await consensus.stakerToStakingIds(user1, 0)
        const bondStakeId3 = await consensus.bondStakes(bondId, 0)
        const bondStakeIndex3 = await consensus.bondStakeIndex(bondStakeId3)
        stakingId3.should.be.equal(bondStakeId3)
        bondStakeIndex3.toNumber().should.be.equal(0)
        numStakes2.toNumber().should.be.equal(1)
        const stakeData2 = await consensus.stakeData(stakingId3)

        await bonder.unstake(bondId, stakingId, {from: user1}).should.be.fulfilled
      })
    })
  }
)
