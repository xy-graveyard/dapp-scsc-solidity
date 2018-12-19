const Staking = artifacts.require(`XyStakableToken.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableMock.sol`)
const StakingMock = artifacts.require(`XyStakingMock.sol`)
const BN = web3.utils.BN
const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()
const {
  advanceBlock
} = require(`openzeppelin-solidity/test/helpers/advanceToBlock`)
const {
  inTransaction
} = require(`openzeppelin-solidity/test/helpers/expectEvent`)

const cooldownStake = 10
const cooldownUnstake = 20
const erc20TotalSupply = 1000000

contract(
  `XyStakableToken`,
  ([
    stakingTokenOwner,
    erc20owner,
    stakableContractOwner,
    stakableTokenOwner,
    staker1,
    staker2,
    stakee1,
    stakee2
  ]) => {
    let erc20,
      staking,
      stakableToken

    before(async () => {
      stakableToken = await Stakeable.new(10, stakableTokenOwner, {
        from: stakableContractOwner
      })
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
    })

    beforeEach(async () => {
      staking = await StakingMock.new(
        erc20.address,
        stakableToken.address,
        cooldownStake,
        cooldownUnstake,
        {
          from: stakingTokenOwner
        }
      )
      await advanceBlock()
    })

    const stakeFromInput = async (meth, param) => {
      const {
        totalStake,
        activeStake,
        totalUnstake,
        activeUnstake
      } = await meth(param)
      return [
        totalStake.toNumber(),
        activeStake.toNumber(),
        totalUnstake.toNumber(),
        activeUnstake.toNumber()
      ]
    }

    const stakeeStake = async stakee => stakeFromInput(staking.stakeeStake, stakee)

    const stakerStake = async staker => stakeFromInput(staking.stakerStake, staker)

    const stakeCompare = async (
      method,
      [totalStake, activeStake, totalUnstake, activeUnstake]
    ) => {
      const [ts, as, tus, taus] = await method
      ts.should.be.equal(totalStake)
      as.should.be.equal(activeStake)
      tus.should.be.equal(totalUnstake)
      taus.should.be.equal(activeUnstake)
    }

    describe(`Cache Updates`, async () => {
      const amt1 = 100
      const amt2 = 200
      const amt3 = 300
      const amt4 = 400

      const updateCacheMethod = async (method, [a1, a2, a3, a4]) => {
        await method(a1, stakee1, {
          from: staker1
        })
        await method(a2, stakee2, {
          from: staker1
        })
        await method(a3, stakee1, {
          from: staker2
        })
        await method(a4, stakee2, {
          from: staker2
        })
      }

      const updateManyCacheMethod = async methods => Promise.all(
        methods.map(async method => updateCacheMethod(method, [amt1, amt2, amt3, amt4]))
      )

      it(`should update cache on stake`, async () => {
        await updateManyCacheMethod([staking.mock_updateCacheOnStake])

        await stakeCompare(stakeeStake(stakee1), [amt1 + amt3, 0, 0, 0])
        await stakeCompare(stakeeStake(stakee2), [amt2 + amt4, 0, 0, 0])
        await stakeCompare(stakerStake(staker1), [amt1 + amt2, 0, 0, 0])
        await stakeCompare(stakerStake(staker2), [amt3 + amt4, 0, 0, 0])
      })

      it(`should update cache on activate`, async () => {
        await updateManyCacheMethod([
          staking.mock_updateCacheOnStake,
          staking.mock_updateCacheOnActivate
        ])

        await stakeCompare(stakeeStake(stakee1), [
          amt1 + amt3,
          amt1 + amt3,
          0,
          0
        ])
        await stakeCompare(stakeeStake(stakee2), [
          amt2 + amt4,
          amt2 + amt4,
          0,
          0
        ])
        await stakeCompare(stakerStake(staker1), [
          amt1 + amt2,
          amt1 + amt2,
          0,
          0
        ])
        await stakeCompare(stakerStake(staker2), [
          amt3 + amt4,
          amt3 + amt4,
          0,
          0
        ])
      })

      it(`should update cache on unstake`, async () => {
        await updateManyCacheMethod([
          staking.mock_updateCacheOnStake,
          staking.mock_updateCacheOnActivate
        ])
        await advanceBlock()
        await updateManyCacheMethod([staking.mock_updateCacheOnUnstake])
        await stakeCompare(stakeeStake(stakee1), [0, 0, amt1 + amt3, 0])
        await stakeCompare(stakeeStake(stakee2), [0, 0, amt2 + amt4, 0])
        await stakeCompare(stakerStake(staker1), [0, 0, amt1 + amt2, 0])
        await stakeCompare(stakerStake(staker2), [0, 0, amt3 + amt4, 0])
      })
      it(`should update cache on activate unstake`, async () => {
        await updateManyCacheMethod([
          staking.mock_updateCacheOnStake,
          staking.mock_updateCacheOnActivate
        ])
        await advanceBlock()
        await updateManyCacheMethod([
          staking.mock_updateCacheOnUnstake,
          staking.mock_updateCacheOnActivateUnstake
        ])
        await stakeCompare(stakeeStake(stakee1), [
          0,
          0,
          amt1 + amt3,
          amt1 + amt3
        ])
        await stakeCompare(stakeeStake(stakee2), [
          0,
          0,
          amt2 + amt4,
          amt2 + amt4
        ])
        await stakeCompare(stakerStake(staker1), [
          0,
          0,
          amt1 + amt2,
          amt1 + amt2
        ])
        await stakeCompare(stakerStake(staker2), [
          0,
          0,
          amt3 + amt4,
          amt3 + amt4
        ])
      })
      it(`should update cache on withdraw`, async () => {
        await updateManyCacheMethod([
          staking.mock_updateCacheOnStake,
          staking.mock_updateCacheOnActivate
        ])
        await advanceBlock()
        await updateManyCacheMethod([
          staking.mock_updateCacheOnUnstake,
          staking.mock_updateCacheOnActivateUnstake
        ])
        await advanceBlock()
        await updateManyCacheMethod([staking.mock_updateCacheOnWithdraw])
        await stakeCompare(stakeeStake(stakee1), [0, 0, 0, 0])
        await stakeCompare(stakeeStake(stakee2), [0, 0, 0, 0])
        await stakeCompare(stakerStake(staker1), [0, 0, 0, 0])
        await stakeCompare(stakerStake(staker2), [0, 0, 0, 0])
      })
    })
    describe(`Public Functions`, async () => {
      const stakingQty = 1000
      const stakeAmt = 100
      const advanceToBlock = async (number) => {
        let blockNumber = await web3.eth.getBlockNumber()
        if (blockNumber > number) {
          throw Error(
            `block number ${number} is in the past (current is ${blockNumber})`
          )
        }

        while (blockNumber < number) {
          await advanceBlock()
          blockNumber = await web3.eth.getBlockNumber()
        }
      }
      beforeEach(async () => {
        await erc20.transfer(staker1, stakingQty, {
          from: erc20owner
        })
        await erc20.transfer(staker2, stakingQty, {
          from: erc20owner
        })
        await erc20.approve(staking.address, stakingQty, { from: staker1 })
        await erc20.approve(staking.address, stakingQty, { from: staker2 })
      })

      describe(`Staking`, async () => {
        it(`should allow staking on a stakable token and transfer token to contract`, async () => {
          const balanceBefore = await erc20.balanceOf(staker1)
          await staking.stake(1, stakeAmt, {
            from: staker1
          }).should.be.fulfilled
          const newBalance = await erc20.balanceOf(staker1)
          const contractBalance = await erc20.balanceOf(staking.address)
          stakeAmt.should.be.equal(balanceBefore - newBalance)
          stakeAmt.should.be.equal(contractBalance)
        })
        it(`should not allow staking on a non-existent coin`, async () => {
          await staking.stake(20, stakeAmt, {
            from: staker1
          }).should.not.be.fulfilled
        })
        it(`should update cache on stake`, async () => {
          await staking.stake(2, stakeAmt, {
            from: staker1
          }).should.be.fulfilled
          await stakeCompare(stakeeStake(2), [stakeAmt, 0, 0, 0])
          await stakeCompare(stakerStake(staker1), [stakeAmt, 0, 0, 0])
        })
        it(`should save stakee data on stake`, async () => {
          const stakeeToken = 2
          const newToken = await staking.stake.call(stakeeToken, stakeAmt, {
            from: staker1
          })
          const tx = await staking.stake(stakeeToken, stakeAmt, {
            from: staker1
          }).should.be.fulfilled
          await inTransaction(tx, `Staked`)
          console.log(`What is the new token`, newToken)
          const curBlock = await web3.eth.getBlockNumber()
          const stakeData = await staking.stakeData(newToken)
          const {
            amount,
            stakeBlock,
            unstakeBlock,
            stakee,
            activatedStake,
            activatedUnstake
          } = stakeData

          amount.toNumber().should.be.equal(stakeAmt)
          stakeBlock.toNumber().should.be.equal(curBlock)
          stakee.toNumber().should.be.equal(stakeeToken)
          unstakeBlock.toNumber().should.be.equal(0)
          activatedStake.toNumber().should.be.equal(0)
          activatedUnstake.toNumber().should.be.equal(0)
        })
      })
      describe(`Activating Stake`, async () => {
        const stakeAmt2 = 1000
        const stakeeTokenId = 4
        const stakeeTokenId2 = 5
        let stakeeToken
        let stakeeToken2
        beforeEach(async () => {
          stakeeToken = await staking.stake.call(stakeeTokenId, stakeAmt, {
            from: staker1
          })
          await staking.stake(stakeeTokenId, stakeAmt, {
            from: staker1
          })
          stakeeToken2 = await staking.stake.call(stakeeTokenId2, stakeAmt2, {
            from: staker2
          })
          await staking.stake(stakeeTokenId2, stakeAmt2, {
            from: staker2
          })
        })
        it(`should not allow activating a stake in a cooldown`, async () => {
          await staking.activateStake(stakeeToken, { from: staker1 }).should.not
            .be.fulfilled
        })
        it(`should only allow stake owner to activate stake, and disallow reactivating stake`, async () => {
          const blockNumber = await web3.eth.getBlockNumber()
          await advanceToBlock(blockNumber + cooldownStake)
          await staking.activateStake(stakeeToken, { from: staker1 }).should.be
            .fulfilled
          await advanceBlock()
          await staking.activateStake(stakeeToken, { from: staker1 }).should.not
            .be.fulfilled
          await staking.activateStake(stakeeToken2, { from: staker1 }).should
            .not.be.fulfilled
          await staking.activateStake(stakeeToken2, { from: staker2 }).should.be
            .fulfilled
        })
        it(`should emit event Activated Stake`, async () => {
          const blockNumber = await web3.eth.getBlockNumber()
          await advanceToBlock(blockNumber + cooldownStake)
          const tx = await staking.activateStake(stakeeToken, { from: staker1 })
            .should.be.fulfilled
          await stakeCompare(stakeeStake(stakeeTokenId), [
            stakeAmt,
            stakeAmt,
            0,
            0
          ])
          await stakeCompare(stakerStake(staker1), [stakeAmt, stakeAmt, 0, 0])
          await inTransaction(tx, `ActivatedStake`)
        })
      })
      describe.only(`Unstaking`, async () => {
        const stakeAmt2 = 1000
        const stakeeTokenId = 4
        const stakeeTokenId2 = 5
        let stakeeToken
        let stakeeToken2
        beforeEach(async () => {
          stakeeToken = await staking.stake.call(stakeeTokenId, stakeAmt, {
            from: staker1
          })
          await staking.stake(stakeeTokenId, stakeAmt, {
            from: staker1
          })
          stakeeToken2 = await staking.stake.call(stakeeTokenId2, stakeAmt2, {
            from: staker2
          })
          await staking.stake(stakeeTokenId2, stakeAmt2, {
            from: staker2
          })
        })
      })
    })
  }
)
