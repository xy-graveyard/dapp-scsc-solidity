const abi = require(`ethereumjs-abi`)

const Stakeable = artifacts.require(`XyStakableToken.sol`)

const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `XyStakableToken`,
  ([contractOwner, deviceOwner, deviceOwner2, ownee, ownee2]) => {
    let stakableToken
    beforeEach(async () => {
      stakableToken = await Stakeable.new({ from: contractOwner })
    })
    describe(`Minting`, async () => {
      it(`should allow minting using signed message`, async () => {
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        const signedMessage = await web3.eth.sign(hash, ownee)

        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner
        }).should.be.fulfilled
      })

      it(`should allow minting using signature in R, S, V`, async () => {
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        // const hash = abi.simpleEncode(ownee, deviceOwner)
        // const hash = web3.utils.sha3(ownee, deviceOwner)
        const signedMessage = await web3.eth.sign(hash, ownee)

        const sig = signedMessage.slice(2)
        const r = `0x${sig.slice(0, 64)}`
        const s = `0x${sig.slice(64, 128)}`
        const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27
        await stakableToken.mint(ownee, r, s, v, {
          from: deviceOwner
        }).should.be.fulfilled
      })

      it(`should fail to mint the same ownee device twice`, async () => {
        // equivalent of encode packed:
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        const signedMessage = await web3.eth.sign(hash, ownee)

        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner
        }).should.be.fulfilled

        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner
        }).should.not.be.fulfilled
      })
      it(`should fail to mint by a device owner who was not in the signed message`, async () => {
        // equivalent of encode packed:
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        const signedMessage = await web3.eth.sign(hash, ownee)

        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner2
        }).should.not.be.fulfilled
        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner
        }).should.be.fulfilled
      })
      it(`should fail to mint if ownee passed does not match the ownee in signed message`, async () => {
        // equivalent of encode packed:
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        const signedMessage = await web3.eth.sign(hash, ownee2)

        await stakableToken.mintWithMessage(ownee2, signedMessage, {
          from: deviceOwner
        }).should.not.be.fulfilled
        await stakableToken.mintWithMessage(ownee, signedMessage, {
          from: deviceOwner
        }).should.not.be.fulfilled
      })

      const repeatArray = (num, obj) => Array(num).fill(obj)

      it(`should allow testing many addresses`, async () => {
        const hash = `0x${abi
          .soliditySHA3([`address`, `address`], [ownee, deviceOwner])
          .toString(`hex`)}`

        const signedMessage = await web3.eth.sign(hash, ownee)

        const sig = signedMessage.slice(2)
        const r = `0x${sig.slice(0, 64)}`
        const s = `0x${sig.slice(64, 128)}`
        const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27
        const nTimes = 180
        const result = await stakableToken.testMany(
          hash,
          repeatArray(nTimes, ownee),
          repeatArray(nTimes, r),
          repeatArray(nTimes, s),
          repeatArray(nTimes, v),
          {
            from: deviceOwner,
            gas: 6721975
            // gasPrice: 0
          }
        )
      })
    })
  }
)
