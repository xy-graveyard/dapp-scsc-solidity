const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Bond = artifacts.require(`XyBond.sol`)
import { time } from 'openzeppelin-test-helpers'

require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

const erc20TotalSupply = 1000000
const governablePeriod = 200
const bondPeriod = 100

contract(
  `XyBond`,
  ([
    governor,
    erc20Owner,
    consensusStub,
    user1
  ]) => {
    let erc20,
      bonder, expirationDate

    before(async () => {

      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20Owner
      })
    })

    beforeEach(async () => {
      const whatTime = await time.latest()
      expirationDate = whatTime.toNumber() + bondPeriod;
      bonder = await Bond.new({ from: governor })
      await bonder.initialize(erc20.address, consensusStub, governablePeriod)
    })

    describe(`Depositing`, () => {
      it(`should allow deposit`, async () => {
        const amount = 100

        await erc20.approve(bonder.address, amount, { from: erc20Owner }).should.be.fulfilled
        await bonder.deposit(amount, expirationDate, { from: erc20Owner }).should.be.fulfilled
        
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

        const data = `${web3.eth.abi.encodeParameters(
            ['uint'],
            [ expirationDate ]
          )}`
        const solidityEncoded = web3.utils.toHex(data)

        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, { from: erc20Owner }).should.be.fulfilled

        const bondId = await bonder.bonds(0)
        const bond = await bonder.bond(bondId)
        const balance = await erc20.balanceOf(bonder.address)
        balance.toNumber().should.be.equal(amount)
        bond.value.toNumber().should.be.equal(amount)
        bond.expirationSec.toNumber().should.be.equal(expirationDate)
        bond.owner.should.be.equal(erc20Owner)
      })

    })
    describe(`Withdrawing`, () => {
      const amount = 100
      let bondId
      
      beforeEach(async () => {
        const whatTime = await time.latest()
        expirationDate = whatTime.toNumber() + bondPeriod;
        // console.log("CurTime, Expiration Date", timeSeconds(), expirationDate)

        const data = `${web3.eth.abi.encodeParameters(
            ['uint'],
            [ expirationDate ]
        )}`
        const solidityEncoded = web3.utils.toHex(data)
        
        await erc20.transfer(user1, amount, {from: erc20Owner})
        const bal1 = await erc20.balanceOf(user1)

        await erc20.approveAndCall(bonder.address, amount, solidityEncoded, { from: user1 }).should.be.fulfilled
        bondId = await bonder.bonds(0)
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(bal1.toNumber() - amount)
      })

      it(`should allow governor withdraw`, async () => {
        await bonder.withdrawTo(bondId, user1, { from: governor }).should.be.fulfilled
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(amount)
        const contractBalance = await erc20.balanceOf(bonder.address)
        contractBalance.toNumber().should.be.equal(0)
      })
      it(`should not allow anyone to withdraw `, async () => {
        await bonder.withdrawTo(bondId, user1, { from: erc20Owner}).should.not.be.fulfilled
      })

      it(`should not allow governor to withdraw after governable period`, async () => {
        const bond = await bonder.bond(bondId)
        await time.increaseTo(bondPeriod + bond.creationSec.toNumber()) // move to after reveal period
        await bonder.withdrawTo(bondId, user1, { from: governor}).should.be.fulfilled
      })

      it(`should not allow user to withdraw until after expiry`, async () => {
        const bal1 = await erc20.balanceOf(user1)

        await bonder.withdrawTo(bondId, user1, { from: user1}).should.not.be.fulfilled
        await time.increaseTo(expirationDate+1) // move to after reveal period
        await bonder.withdrawTo(bondId, user1, { from: erc20Owner}).should.not.be.fulfilled
        await bonder.withdrawTo(bondId, user1, { from: user1}).should.be.fulfilled
        const userBalance = await erc20.balanceOf(user1)
        userBalance.toNumber().should.be.equal(bal1.toNumber() + amount)
      })
    })
  }
)
