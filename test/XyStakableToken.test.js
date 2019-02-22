const abi = require(`ethereumjs-abi`)

const Stakeable = artifacts.require(`XyStakableToken.sol`)

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `XyStakableToken`,
  ([contractOwner, deviceOwner, deviceOwner2, ownee, nongovenor]) => {
    let stakableToken

    const genArgs = async (newOwnee, from) => [newOwnee, { from }]
    beforeEach(async () => {
      stakableToken = await Stakeable.new({ from: contractOwner })
    })
    describe(`Minting`, async () => {
      it(`should allow minting by owner`, async () => {
        const args = await genArgs(ownee, ownee)
        await stakableToken.mint(...args).should.be.fulfilled
      })

      it(`should allow minting by governor`, async () => {
        const args = await genArgs(ownee, contractOwner)
        await stakableToken.mint(...args).should.be.fulfilled
      })

      it(`should fail to mint account by non governor`, async () => {
        const args = await genArgs(ownee, nongovenor)
        await stakableToken.mint(...args).should.not.be.fulfilled
      })

      it(`should fail to mint the same ownee device twice`, async () => {
        // equivalent of encode packed:
        const args = await genArgs(ownee, ownee)
        await stakableToken.mint(...args).should.be.fulfilled

        await stakableToken.mint(...args).should.not.be.fulfilled
      })
    })
  }
)
