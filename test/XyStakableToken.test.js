const abi = require(`ethereumjs-abi`)

const Stakeable = artifacts.require(`XyStakableToken.sol`)

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `XyStakableToken`,
  ([contractOwner, deviceOwner, deviceOwner2, ownee, ownee2, govenor]) => {
    let stakableToken

    const genArgs = async (newOwnee) => {
      const hash = `0x${abi
        .soliditySHA3([`address`, `address`], [newOwnee, deviceOwner])
        .toString(`hex`)}`

      const signedMessage = await web3.eth.sign(hash, newOwnee)
      const sig = signedMessage.slice(2)
      const r = `0x${sig.slice(0, 64)}`
      const s = `0x${sig.slice(64, 128)}`
      const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27
      return [newOwnee, r, s, v, true]
    }
    beforeEach(async () => {
      stakableToken = await Stakeable.new(govenor, { from: contractOwner })
    })
    describe(`Minting`, async () => {
      it(`should allow minting using signature in R, S, V`, async () => {
        const args = await genArgs(ownee)
        await stakableToken.mint(...args, {
          from: deviceOwner
        }).should.be.fulfilled
      })

      it(`should fail to mint the same ownee device twice`, async () => {
        // equivalent of encode packed:
        const args = await genArgs(ownee)
        await stakableToken.mint(...args, {
          from: deviceOwner
        }).should.be.fulfilled

        await stakableToken.mint(...args, {
          from: deviceOwner
        }).should.not.be.fulfilled
      })
      it(`should fail to mint by a device owner who was not in the signed message`, async () => {
        // equivalent of encode packed:
        const args = await genArgs(ownee)
        await stakableToken.mint(...args, {
          from: deviceOwner2
        }).should.not.be.fulfilled

        await stakableToken.mint(...args, {
          from: deviceOwner
        }).should.be.fulfilled
      })

      it(`should fail to mint if ownee passed does not match the ownee in signed message`, async () => {
        // equivalent of encode packed:
        const args = await genArgs(ownee)

        await stakableToken.mint(...args, {
          from: deviceOwner
        }).should.be.fulfilled

        const args2 = await genArgs(ownee2)
        await stakableToken.mint(ownee, args2.slice(1, args2.length - 1), {
          from: deviceOwner
        }).should.not.be.fulfilled
      })
    })
  }
)
