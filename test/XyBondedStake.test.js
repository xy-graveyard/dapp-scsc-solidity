const ERC20 = artifacts.require(`XyERC20Token.sol`)
const BondedStake = artifacts.require(`XyBondedStake.sol`)

require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

const erc20TotalSupply = 1000000

contract(
  `XyBondedStake`,
  ([
    escrowOwner,
    erc20Owner,
    consensusStub,
    user1
  ]) => {
    let erc20,
      managedEscrow

    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20Owner
      })
    })

    beforeEach(async () => {
      managedEscrow = await BondedStake.new({ from: escrowOwner })
      await managedEscrow.initialize(erc20.address, consensusStub)
    })

    // describe(`Depositing`, () => {
    //   it(`should allow deposit via approveAndCall`, async () => {
    //     const amount = 100
    //     await erc20.approveAndCall(managedEscrow.address, amount, `0x0`, { from: erc20Owner }).should.be.fulfilled
    //     const balance = await managedEscrow.escrowBalanceXYO(erc20Owner)
    //     balance.toNumber().should.be.equal(amount)
    //   })
    //   it(`should allow deposit`, async () => {
    //     const amount = 100
    //     await erc20.approve(managedEscrow.address, amount, { from: erc20Owner }).should.be.fulfilled
    //     await managedEscrow.deposit(amount, { from: erc20Owner })
    //     const balance = await managedEscrow.escrowBalanceXYO(erc20Owner)
    //     balance.toNumber().should.be.equal(amount)
    //   })
    // })
    // describe(`Withdrawing`, () => {
    //   const amount = 100

    //   beforeEach(async () => {
    //     await erc20.approveAndCall(managedEscrow.address, amount, `0x0`, { from: erc20Owner }).should.be.fulfilled
    //   })
    //   it(`should allow withdraw`, async () => {
    //     await managedEscrow.withdrawBondedStake(amount, { from: erc20Owner }).should.be.fulfilled
    //     const balance = await managedEscrow.escrowBalanceXYO(erc20Owner)
    //     balance.toNumber().should.be.equal(0)
    //   })
    //   it(`should not allow anyone to withdraw `, async () => {
    //     await managedEscrow.withdrawBondedStake(amount).should.not.be.fulfilled
    //   })
    // })
  }
)
