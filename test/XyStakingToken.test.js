const Staking = artifacts.require(`XyBlockProducer.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyBlockProducerMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const StakingMock = artifacts.require(`XyStakingMock.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`./config/params.json`))
const params = config.paramDefaults
const BN = web3.utils.BN

const parameters = [
  params.pMinDeposit,
  params.pApplyStageLen,
  params.pCommitStageLen,
  params.pRevealStageLen,
  params.pDispensationPct,
  params.pVoteQuorum,
  params.xyStakeQuorumPct,
  params.xyWeiMiningMin,
  params.xyXYORequestBountyMin,
  params.xyStakeCooldown,
  params.xyUnstakeCooldown,
  params.xyProposalsEnabled
]

require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

const { expectEvent } = require(`openzeppelin-test-helpers`)

const cooldownStake = params.xyStakeCooldown
const cooldownUnstake = params.xyUnstakeCooldown
const erc20TotalSupply = 1000000

function advanceBlock () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: `2.0`,
        method: `evm_mine`,
        id: Date.now()
      },
      (err, res) => (err ? reject(err) : resolve(res))
    )
  })
}

contract(
  `XyStakingModel`,
  ([
    stakingTokenOwner,
    erc20owner,
    stakableContractOwner,
    parameterizerOwner,
    stakableTokenOwner,
    staker1,
    staker2,
    withdrawStaker
  ]) => {
    let erc20,
      staking,
      stakableToken,
      parameterizer,
      plcr,
      stakee1,
      stakee2,
      stakee3,
      stakee4

    before(async () => {
      stakableToken = await Stakeable.new([15], {
        from: stakableContractOwner
      })
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
    })

    beforeEach(async () => {
      parameterizer = await Governance.new({
        from: parameterizerOwner
      })
      plcr = await PLCR.new({
        from: parameterizerOwner
      })
      await plcr.initialize(erc20.address)
      staking = await StakingMock.new(
        erc20.address,
        stakableToken.address,
        parameterizer.address,
        {
          from: stakingTokenOwner
        }
      )
      stakee1 = await stakableToken.stakeeMocks(0)
      stakee2 = await stakableToken.stakeeMocks(1)
      stakee3 = await stakableToken.stakeeMocks(2)
      stakee4 = await stakableToken.stakeeMocks(3)

      await parameterizer.initialize(
        staking.address,
        erc20.address,
        plcr.address,
        parameters
      )
      await advanceBlock()
    })

    const stakeFromInput = async (meth, param) => {
      const { totalStake, activeStake, totalUnstake } = await meth(param)
      return [
        totalStake.toNumber(),
        activeStake.toNumber(),
        totalUnstake.toNumber()
      ]
    }

    const stakeeStake = async stakee => stakeFromInput(staking.stakeeStake, stakee)

    const stakerStake = async staker => stakeFromInput(staking.stakerStake, staker)

    const stakeCompare = async (
      method,
      [totalStake, activeStake, totalUnstake]
    ) => {
      const [ts, as, tus] = await method
      ts.should.be.equal(totalStake)
      as.should.be.equal(activeStake)
      tus.should.be.equal(totalUnstake)
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
        await updateManyCacheMethod([staking.fake_updateCacheOnStake])

        await stakeCompare(stakeeStake(stakee1), [amt1 + amt3, 0, 0])
        await stakeCompare(stakeeStake(stakee2), [amt2 + amt4, 0, 0])
        await stakeCompare(stakerStake(staker1), [amt1 + amt2, 0, 0])
        await stakeCompare(stakerStake(staker2), [amt3 + amt4, 0, 0])
      })

      it(`should update cache on activate`, async () => {
        await updateManyCacheMethod([
          staking.fake_updateCacheOnStake,
          staking.fake_updateCacheOnActivate
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
          staking.fake_updateCacheOnStake,
          staking.fake_updateCacheOnActivate
        ])
        await advanceBlock()
        await updateManyCacheMethod([staking.stub_updateCacheOnUnstake])
        await stakeCompare(stakeeStake(stakee1), [0, 0, amt1 + amt3])
        await stakeCompare(stakeeStake(stakee2), [0, 0, amt2 + amt4])
        await stakeCompare(stakerStake(staker1), [0, 0, amt1 + amt2])
        await stakeCompare(stakerStake(staker2), [0, 0, amt3 + amt4])
      })
      it(`should update cache on withdraw`, async () => {
        await updateManyCacheMethod([
          staking.fake_updateCacheOnStake,
          staking.fake_updateCacheOnActivate
        ])
        await advanceBlock()
        await updateManyCacheMethod([staking.stub_updateCacheOnUnstake])
        await advanceBlock()
        await updateManyCacheMethod([staking.fake_updateCacheOnWithdraw])
        await stakeCompare(stakeeStake(stakee1), [0, 0, 0])
        await stakeCompare(stakeeStake(stakee2), [0, 0, 0])
        await stakeCompare(stakerStake(staker1), [0, 0, 0])
        await stakeCompare(stakerStake(staker2), [0, 0, 0])
      })
    })
    describe(`Public Functions`, async () => {
      const stakingQty = 10000
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

      const createStake = async (staker, stakee, amount) => staking.stake(stakee, amount, {
        from: staker
      })
      const createUnstake = async (staker, stakingToken) => staking.unstake(stakingToken, {
        from: staker
      })

      describe(`Staking`, async () => {
        it(`should allow staking on a stakable token and transfer token to contract`, async () => {
          const balanceBefore = await erc20.balanceOf(staker1)
          await createStake(staker1, stakee1, stakeAmt)
          const newBalance = await erc20.balanceOf(staker1)
          const contractBalance = await erc20.balanceOf(staking.address)
          stakeAmt.should.be.equal(balanceBefore - newBalance)
          stakeAmt.should.be.equal(contractBalance.toNumber())
        })
        it(`should not allow staking on a non-existent coin`, async () => {
          await staking.stake(20, stakeAmt, {
            from: staker1
          }).should.not.be.fulfilled
        })
        it(`should update cache on stake`, async () => {
          await createStake(staker1, stakee2, stakeAmt).should.be.fulfilled
          await stakeCompare(stakeeStake(stakee2), [stakeAmt, 0, 0])
          await stakeCompare(stakerStake(staker1), [stakeAmt, 0, 0])
        })
        it(`should save stakee data on stake`, async () => {
          const newToken = await staking.stake.call(stakee2, stakeAmt, {
            from: staker1
          })
          const tx = await createStake(staker1, stakee2, stakeAmt).should.be
            .fulfilled
          await expectEvent.inLogs(tx.logs, `Staked`)
          const curBlock = await web3.eth.getBlockNumber()
          const stakeData = await staking.stakeData(newToken)
          const {
            amount,
            stakeBlock,
            unstakeBlock,
            stakee,
            isActivated
          } = stakeData

          amount.toNumber().should.be.equal(stakeAmt)
          stakeBlock.toNumber().should.be.equal(curBlock)
          stakee.toString().should.be.equal(stakee2.toString())
          unstakeBlock.toNumber().should.be.equal(0)
          isActivated.should.be.equal(false)
        })
      })
      describe(`Activating Stake`, async () => {
        const stakeAmt2 = 1000
        let stakeeToken
        let stakeeToken2
        beforeEach(async () => {
          stakeeToken = await staking.stake.call(stakee3, stakeAmt, {
            from: staker1
          })
          await staking.stake(stakee3, stakeAmt, {
            from: staker1
          })
          stakeeToken2 = await staking.stake.call(stakee4, stakeAmt2, {
            from: staker2
          })
          await staking.stake(stakee4, stakeAmt2, {
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
          await stakeCompare(stakeeStake(stakee3), [
            stakeAmt,
            stakeAmt,
            0,
            0
          ])
          await stakeCompare(stakerStake(staker1), [stakeAmt, stakeAmt, 0])
          await expectEvent.inLogs(tx.logs, `ActivatedStake`)
        })
      })
      describe(`Unstaking and withdrawing`, async () => {
        const stakeAmt2 = 500
        let stakingToken
        let stakingToken2
        beforeEach(async () => {
          stakingToken = await staking.stake.call(stakee3, stakeAmt, {
            from: staker1
          })
          await staking.stake(stakee3, stakeAmt, {
            from: staker1
          })
          stakingToken2 = await staking.stake.call(stakee4, stakeAmt2, {
            from: staker1
          })
          await staking.stake(stakee4, stakeAmt2, {
            from: staker1
          })
        })
        describe(`Unstaking`, async () => {
          it(`should allow unstaking after cooldown`, async () => {
            await staking.unstake(stakingToken, { from: staker1 }).should.not.be
              .fulfilled
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await staking.unstake(stakingToken, { from: staker1 }).should.be
              .fulfilled
          })
          it(`should only allow staker to unstake`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await staking.unstake(stakingToken, { from: staker2 }).should.not.be
              .fulfilled
            await staking.unstake(stakingToken, { from: staker1 }).should.be
              .fulfilled
          })
          it(`Cannot re-unstake`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await staking.unstake(stakingToken, { from: staker1 }).should.be
              .fulfilled
            await staking.unstake(stakingToken, { from: staker1 }).should.not.be
              .fulfilled
          })
          it(`should issue unstaking event`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            const tx = await staking.unstake(stakingToken, { from: staker1 })
              .should.be.fulfilled
            await expectEvent.inLogs(tx.logs, `Unstaked`)
          })
          it(`should update stake datas`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await staking.unstake(stakingToken, { from: staker1 }).should.be
              .fulfilled
            await stakeCompare(stakeeStake(stakee3), [0, 0, stakeAmt])
            await stakeCompare(stakerStake(staker1), [stakeAmt2, 0, stakeAmt])
          })
          it(`should reflect proper available staker and stakee unstake before and after cooldown`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await staking.unstake(stakingToken, { from: staker1 }).should.be
              .fulfilled

            await staking.unstake(stakingToken2, { from: staker1 }).should.be
              .fulfilled
            const avUnStakee = await staking.getAvailableStakeeUnstake.call(
              stakingToken
            )
            const avUnStakee2 = await staking.getAvailableStakeeUnstake.call(
              stakingToken2
            )
            const avUnStaker = await staking.getAvailableStakerUnstake.call(
              staker1
            )
            avUnStakee.toNumber().should.be.equal(0)
            avUnStakee2.toNumber().should.be.equal(0)
            avUnStaker.toNumber().should.be.equal(0)
            const b2 = await web3.eth.getBlockNumber()
            await advanceToBlock(b2 + cooldownUnstake)
            const avUnStakeeAfter = await staking.getAvailableStakeeUnstake.call(
              stakee3
            )
            const avUnStakeeAfter2 = await staking.getAvailableStakeeUnstake.call(
              stakee4
            )
            const avUnStakerAfter = await staking.getAvailableStakerUnstake.call(
              staker1
            )

            avUnStakerAfter.toNumber().should.be.equal(stakeAmt + stakeAmt2)
            avUnStakeeAfter.toNumber().should.be.equal(stakeAmt)
            avUnStakeeAfter2.toNumber().should.be.equal(stakeAmt2)
          })
        })

        describe(`Withdrawing`, async () => {
          beforeEach(async () => {
            await erc20.transfer(withdrawStaker, stakingQty * 30, {
              from: erc20owner
            })
            await erc20.approve(staking.address, stakingQty * 30, {
              from: withdrawStaker
            })
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)

            await staking.unstake(stakingToken, { from: staker1 })
            await staking.unstake(stakingToken2, { from: staker1 })
          })

          it(`should allow withdrawing after unstake cooldown`, async () => {
            await staking.withdrawStake(stakingToken, { from: staker1 }).should.not
              .be.fulfilled
            const balance = await erc20.balanceOf(staking.address)
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownUnstake)
            await staking.withdrawStake(stakingToken, { from: staker1 }).should.be
              .fulfilled
          })

          it(`should transfer stake on withdraw from contract to staker`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownUnstake)
            const balanceBefore = await staking.numStakerStakes(staker1)
            const balanceBefore20 = await erc20.balanceOf(staker1)
            await staking.withdrawStake(stakingToken, { from: staker1 }).should.be
              .fulfilled
            const balanceAfter = await staking.numStakerStakes(staker1)
            const balanceAfter20 = await erc20.balanceOf(staker1)
            balanceBefore
              .toNumber()
              .should.be.equal(balanceAfter.toNumber() + 1)
            balanceBefore20
              .toNumber()
              .should.be.equal(balanceAfter20.toNumber() - stakeAmt)
          })

          it(`should update the stake cache after withdraw`, async () => {
            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownUnstake)
            await staking.withdrawStake(stakingToken, { from: staker1 }).should.be
              .fulfilled
            await stakeCompare(stakeeStake(stakee3), [0, 0, 0])
            await stakeCompare(stakerStake(staker1), [0, 0, stakeAmt2])
          })
          const stakeMany = async (staker, amounts, numToStake) => {
            const tokens = []
            for (let i = 0; i < numToStake; i++) {
              const stakee = await stakableToken.stakeeMocks(i)
              const response = await staking.stake.call(stakee, amounts, {
                from: staker
              })
              tokens.push(response)
              await createStake(staker, stakee, amounts)
            }
            return tokens
          }
          const unstakeMany = async (staker, tokens) => {
            for (let i = 0; i < tokens.length; i++) {
              await createUnstake(staker, tokens[i])
            }
          }
          it(`should allow withdrawing up to a batch count`, async () => {
            const stakingTokens = 15

            const tokens = await stakeMany(withdrawStaker, 100, stakingTokens)
            await stakeCompare(stakerStake(withdrawStaker), [
              stakingTokens * 100,
              0,
              0
            ])

            const blockNumber = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber + cooldownStake)
            await unstakeMany(withdrawStaker, tokens)
            await advanceBlock()
            await stakeCompare(stakerStake(withdrawStaker), [
              0,
              0,
              stakingTokens * 100
            ])
            await staking.withdrawManyStake(2, { from: withdrawStaker }).should.be
              .fulfilled
            await stakeCompare(stakerStake(withdrawStaker), [
              0,
              0,
              (stakingTokens - 2) * 100
            ])
            const blockNumber2 = await web3.eth.getBlockNumber()
            await advanceToBlock(blockNumber2 + cooldownUnstake)

            await staking.withdrawManyStake(5, { from: withdrawStaker }).should.be
              .fulfilled
            await stakeCompare(stakerStake(withdrawStaker), [
              0,
              0,
              (stakingTokens - 7) * 100
            ])
            await staking.withdrawManyStake(15, { from: withdrawStaker }).should.be
              .fulfilled
            await stakeCompare(stakerStake(withdrawStaker), [0, 0, 0])
          })
        })
      })
    })
  }
)
