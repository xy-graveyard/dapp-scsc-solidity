const Staking = artifacts.require(`XyStakableToken.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableMock.sol`)
const StakingMock = artifacts.require(`XyStakingMock.sol`)
const BN = web3.utils.BN
const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

const {
  inTransaction
} = require(`openzeppelin-solidity/test/helpers/expectEvent`)

const cooldownStake = 10
const cooldownUnstake = 20
const erc20TotalSupply = 1000000

function advanceBlock () {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: `2.0`,
      method: `evm_mine`,
      id: Date.now()
    }, (err, res) => (err ? reject(err) : resolve(res)))
  })
}

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
    stakee2,
    withdrawStaker
  ]) => {
    let erc20,
      staking,
      stakableToken

    before(async () => {
      stakableToken = await Stakeable.new(15, stakableTokenOwner, {
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
  }
)
