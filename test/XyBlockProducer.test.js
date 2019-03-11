const Stakeable = artifacts.require(`XyBlockProducer.sol`)

require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `XyBlockProducer`,
  ([contractOwner, deviceOwner, deviceOwner2, ownee, nongovenor]) => {
    let stakableToken

    const genArgs = async (newOwnee, from) => [newOwnee, { from }]
    beforeEach(async () => {
      stakableToken = await Stakeable.new({ from: contractOwner })
    })
    describe(`Minting`, async () => {
      it(`should not allow minting by random owner`, async () => {
        const args = await genArgs(ownee, ownee)
        await stakableToken.create(...args).should.not.be.fulfilled
      })

      it(`should allow minting by governor`, async () => {
        const args = await genArgs(ownee, contractOwner)
        await stakableToken.create(...args).should.be.fulfilled
      })

      it(`should fail to create account by non governor`, async () => {
        const args = await genArgs(ownee, nongovenor)
        await stakableToken.create(...args).should.not.be.fulfilled
      })

      it(`should fail to create the same ownee device twice`, async () => {
        // equivalent of encode packed:
        const args = await genArgs(ownee, contractOwner)
        await stakableToken.create(...args).should.be.fulfilled

        await stakableToken.create(...args).should.not.be.fulfilled
      })
    })
  }
)
