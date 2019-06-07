import {BigNumber} from 'bignumber.js'
import {expectEvent} from 'openzeppelin-test-helpers'

const abi = require(`ethereumjs-abi`)
const PayOnDelivery = artifacts.require(`XyPayOnDeliveryMock.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const BlockProducer = artifacts.require(`XyBlockProducerMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const erc20TotalSupply = 1000000
const {advanceBlock, testParams} = require(`./utils.test`)

require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()

contract(
  `XyStakingConsensus`,
  ([
    consensusOwner,
    erc20owner,
    stakableContractOwner,
    stakableTokenOwner,
    governanceOwner,
    d1,
    d2,
    d3,
    d4,
    payOnDeliveryOwner
  ]) => {
    let erc20
    let consensus
    let stakableToken
    let governance
    let plcr
    const diviners = [consensusOwner, d1, d2, d4]
    const numDiviners = diviners.length
    const numRequests = 1
    let payOnD
    const xyoPayment = 200
    const xyoBounty = 0
    const ethOnDelivery = 1000
    const miningEth = 100

    const synchronizePromises = async (promises, results = [], index = 0) => {
      if (promises.length === 0) return []

      const next = await promises[index]
      results.push(next)

      if (index === promises.length - 1) {
        return results
      }
      return synchronizePromises(promises, results, index + 1)
    }

    const randomBoolResponses = (responses = []) => {
      const byteResponses = new Uint8Array(numRequests)
      for (let i = 0; i < numRequests; i++) {
        const random = Math.random() >= 0.5
        byteResponses[i] = random
      }
      appendResponse(responses, `bytes`, byteResponses)

      return responses
    }
    const randUintResponse = () => {
      const uintResp = []
      for (let j = 0; j < numRequests; j++) {
        const random = Math.random() * 100000000000000
        uintResp[j] = random
      }
      return uintResp
    }

    const requestPayOnDeliveries = async (starting = 0) => {
      const requests = [...Array(numRequests).keys()].map(r => `0x${r + 1 + starting}`)
      await erc20.approve(payOnD.address, numRequests * xyoPayment, {
        from: erc20owner
      })
      const promises = requests.map(
        async q =>
          payOnD.requestPayOnDelivery(q, xyoBounty, xyoPayment, ethOnDelivery, d3, {
            value: ethOnDelivery + miningEth,
            from: erc20owner
          }).should.be.fulfilled
      )
      await synchronizePromises(promises)
      return requests
    }

    const submitUintRequest = async () => {
      const requests = [...Array(numRequests).keys()].map(r => `0x${r + 1}`)
      await erc20.approve(payOnD.address, numRequests * xyoPayment, {
        from: erc20owner
      })
      const promises = requests.map(
        async q =>
          payOnD.submitUintRequest(q, xyoBounty, xyoPayment, ethOnDelivery, d3, {
            value: ethOnDelivery + miningEth,
            from: erc20owner
          }).should.be.fulfilled
      )
      await synchronizePromises(promises)
      return requests
    }

    const compareDiviners = (a, b) => a > b
    const SubmitArgsEnum = {
      PREVIOUS: 0,
      STAKING: 1,
      REQUESTS: 2,
      DATAHASH: 3,
      RESPONSES: 4,
      SIGNERS: 5,
      R: 6,
      S: 7,
      V: 8,
      SIGHASH: 9
    }
    const createArgs = async (requests, packedResponses, returnHash) => {
      const previous = await consensus.getLatestBlock()
      const blockHeight = 100
      const responseDataHash = abi.soliditySHA3([`bytes32`], [previous]) // a bogus hash
      const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
      const promises = sorted.map(async adr =>
        encodeAndSign(adr, previous, blockHeight, requests, responseDataHash, packedResponses)
      )
      const sigArr = await synchronizePromises(promises)
      const r = []
      const s = []
      const v = []
      let packedMsg
      let hash
      sigArr.forEach(sig => {
        r.push(sig[0])
        s.push(sig[1])
        v.push(sig[2])
        packedMsg = sig[3]
        hash = sig[4]
      })
      const args = [
        previous,
        blockHeight,
        requests,
        responseDataHash,
        packedResponses,
        sorted,
        r,
        s,
        v
      ]
      if (returnHash) {
        args.push(hash)
      }
      return args
    }
    const generateArgs = async (returnHash = false) => {
      const requests = await requestPayOnDeliveries()
      const responses = randomBoolResponses()
      const packedResponses = packResponse(responses)
      return createArgs(requests, packedResponses, returnHash)
    }

    const addWithdrawRequest = async (from, requests) => {
      const withdrawReq = await consensus.withdrawRewardsRequest.call(0, {
        from
      })
      await consensus.withdrawRewardsRequest(0, {from})
      requests.push(withdrawReq)
    }

    const withdrawSubmitBlockArgs = async (responseAmt, withdrawRequester) => {
      const requests = await requestPayOnDeliveries()
      await addWithdrawRequest(withdrawRequester, requests)
      const responses = randomBoolResponses()
      appendResponse(responses, `uint`, responseAmt)
      const packedResponses = packResponse(responses)
      return createArgs(requests, packedResponses, false)
    }
    const appendResponse = (responses, type, val) => {
      responses.push({type, value: val})
    }

    const packResponse = responses => {
      const responseTypes = responses.map(r => r.type)
      const responseValues = responses.map(r => r.value)
      // console.log(`TYPES AND VALUES`, responseTypes, responseValues)

      const packedBytes = abi.solidityPack([...responseTypes], [...responseValues])

      // console.log(`Packed`, packedBytes)
      return packedBytes
    }
    const encodeAndSign = async (
      signer,
      previous,
      blockHeight,
      requests,
      responseDataHash,
      packedResponses
    ) => {
      const bytes32Arr = requests.map(() => `bytes32`)

      const hash = `0x${abi
        .soliditySHA3(
          [`bytes32`, `uint`, ...bytes32Arr, `bytes32`, `bytes`],
          [previous, blockHeight, ...requests, responseDataHash, packedResponses]
        )
        .toString(`hex`)}`

      const packedBytes = `0x${abi
        .solidityPack(
          [`bytes32`, `uint`, ...bytes32Arr, `bytes32`, `bytes`],
          [previous, blockHeight, ...requests, responseDataHash, packedResponses]
        )
        .toString(`hex`)}`

      // console.log(`HASH`, hash, previous, requests)
      // console.log(`ENCODED BYTES`, packedBytes)
      // console.log(`JUST RESPONSES`, justResponses, responses.toString())

      const signedMessage = await web3.eth.sign(hash, signer)

      const sig = signedMessage.slice(2)
      const r = `0x${sig.slice(0, 64)}`
      const s = `0x${sig.slice(64, 128)}`
      const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27

      return [r, s, v, packedBytes, hash]
    }
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      plcr = await PLCR.new({
        from: governanceOwner
      })
      await plcr.initialize(erc20.address)
      stakableToken = await BlockProducer.new(diviners, {
        from: stakableContractOwner
      })
      await advanceBlock()
    })
    beforeEach(async () => {
      governance = await Governance.new({
        from: governanceOwner
      })
      await governance.initialize(erc20.address, plcr.address, testParams(), {
        from: governanceOwner
      })
      consensus = await StakingConsensus.new(diviners, {
        from: consensusOwner
      })
      await consensus.initialize(erc20.address, stakableToken.address, governance.address)

      await governance.initializeGovernor(consensus.address)
      payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
        from: payOnDeliveryOwner
      })
      await advanceBlock()
    })
    describe(`Approve and call`, async () => {
      it(`should allow approve and requesting`, async () => {
        const bounty = 10
        await erc20.transfer(d1, 500, {from: erc20owner})

        const originalBalance = await erc20.balanceOf(d1)

        const data = `${web3.eth.abi.encodeParameters(
          [`bytes32`, `uint`, `address`, `uint8`],
          [`0x1`, bounty, d1, 4]
        )}`
        const encodedMethod = `${web3.eth.abi.encodeParameters(
          [`uint`, `bytes`],
          [
            2, // submitRequest
            data
          ]
        )}`
        const solidityEncoded = web3.utils.toHex(encodedMethod)

        await erc20.approveAndCall(consensus.address, bounty, solidityEncoded, {from: d1}).should.be
          .fulfilled
        const newBalance = await erc20.balanceOf(d1)
        newBalance.toNumber().should.be.equal(originalBalance.toNumber() - bounty)
      })
      it(`should allow approve and staking`, async () => {
        const stake = 10
        const spender = d1
        const stakee = d2
        const staker = d3
        await erc20.transfer(spender, 500, {from: erc20owner})
        const originalBalance = await erc20.balanceOf(spender)
        const data = `${web3.eth.abi.encodeParameters([`address`, `address`], [staker, stakee])}`
        const encodedMethod = `${web3.eth.abi.encodeParameters(
          [`uint`, `bytes`],
          [
            1, // stake
            data
          ]
        )}`
        const solidityEncoded = web3.utils.toHex(encodedMethod)

        const tx = await erc20.approveAndCall(consensus.address, stake, solidityEncoded, {
          from: spender
        }).should.be.fulfilled
        const newBalance = await erc20.balanceOf(spender)
        newBalance.toNumber().should.be.equal(originalBalance.toNumber() - stake)
      })
      it(`should allow approve and staking multiple`, async () => {
        const stake = 100 // divisible by 3 stakees
        const spender = d1
        const stakees = [d2, d4, spender].sort()
        console.log('Stakees', stakees)
        const stakers = [d3, d3, d3]
        const amounts = [33, 33, 34]
        await erc20.transfer(spender, 500, {from: erc20owner})
        const originalBalance = await erc20.balanceOf(spender)
        const data = `${web3.eth.abi.encodeParameters(
          [`address[]`, `address[]`, `uint[]`],
          [stakers, stakees, amounts]
        )}`
        const encodedMethod = `${web3.eth.abi.encodeParameters(
          [`uint`, `bytes`],
          [
            3, // stake multiple
            data
          ]
        )}`
        const solidityEncoded = web3.utils.toHex(encodedMethod)

        const tx = await erc20.approveAndCall(consensus.address, stake, solidityEncoded, {
          from: spender
        }).should.be.fulfilled
        const newBalance = await erc20.balanceOf(spender)
        newBalance.toNumber().should.be.equal(originalBalance.toNumber() - stake)
      })
    })
    describe(`Submit Request`, () => {
      it(`Should allow creating requests with many request types`, async () => {
        await consensus.submitRequest(`0x1`, 0, d1, 1).should.be.fulfilled
        await consensus.submitRequest(`0x2`, 0, d1, 2).should.be.fulfilled
        await consensus.submitRequest(`0x3`, 0, d1, 3).should.be.fulfilled
        await consensus.submitRequest(`0x4`, 0, d1, 4).should.be.fulfilled
        await consensus.submitRequest(`0x5`, 0, d1, 0).should.be.fulfilled
      })
      it(`Should not allow duplicate requests`, async () => {
        await consensus.submitRequest(`0x1`, 0, d1, 1).should.be.fulfilled
        await consensus.submitRequest(`0x1`, 0, d1, 2).should.not.be.fulfilled
      })
      it(`Should not allow requests under minimum bounty if in place`, async () => {
        const min = 100
        await governance.ownerSet(`xyXYORequestBountyMin`, min, {
          from: governanceOwner
        })
        await governance.ownerSet(`xyWeiMiningMin`, min, {
          from: governanceOwner
        })
        await erc20.transfer(d1, 500, {from: erc20owner})
        await erc20.approve(consensus.address, 500, {from: d1})
        await consensus.submitRequest(`0x1`, 0, d1, 1, {from: d1}).should.not.be.fulfilled
        await consensus.submitRequest(`0x1`, 0, d1, 1, {from: d1, value: min}).should.not.be
          .fulfilled
        await consensus.submitRequest(`0x1`, min, d1, 1, {
          from: d1,
          value: 99
        }).should.not.be.fulfilled
        await consensus.submitRequest(`0x1`, min, d1, 1, {
          from: d1,
          value: min
        }).should.be.fulfilled

        const contractBalance = await erc20.balanceOf(consensus.address)
        contractBalance.toNumber().should.be.equal(min)
      })
    })
    describe(`Submitting blocks`, () => {
      it(`should allow creating a block by consensus of at least 4 diviners`, async () => {
        const args = await generateArgs()
        const tx = await consensus.submitBlock(...args)
        expectEvent.inLogs(tx.logs, `BlockCreated`)
      })

      it(`should return correct previous block`, async () => {
        const args = await generateArgs()
        const lastBlock = await consensus.submitBlock.call(...args).should.be.fulfilled
        await consensus.submitBlock(...args).should.be.fulfilled
        lastBlock.toString().should.not.be.equal(`0`)
        const newLast = await consensus.getLatestBlock.call()
        newLast.toString().should.be.equal(lastBlock.toString())
      })

      it(`should fail if passes responses doesnt match signed data`, async () => {
        const submitParams = await generateArgs()
        const randomIndex = Math.floor(Math.random() * (submitParams[3].length - 1))
        submitParams[3][randomIndex] = !submitParams[3][randomIndex]
        // console.log(`Responses After`, responses)
        await consensus.submitBlock(...submitParams).should.not.be.fulfilled
      })

      it(`should not allow submitting response for an answer twice`, async () => {
        const requests = await requestPayOnDeliveries()
        const responses = randomBoolResponses()
        const packedResponses = packResponse(responses)
        const args = await createArgs(requests, packedResponses, false)

        const lastBlock = await consensus.submitBlock.call(...args).should.be.fulfilled
        await consensus.submitBlock(...args).should.be.fulfilled
        lastBlock.toString().should.not.be.equal(`0`)
        const newLast = await consensus.getLatestBlock.call()
        newLast.toString().should.be.equal(lastBlock.toString())

        await requestPayOnDeliveries(100) // hack to add value to contract so revert is right reason

        const args2 = await createArgs(requests, packedResponses, false)
        await consensus.submitBlock(...args2).should.not.be.fulfilled
        const latest2 = await consensus.getLatestBlock.call()
        newLast.toString().should.be.equal(latest2.toString())
      })

      describe(`handleResponses`, async () => {
        it(`should return correct reward`, async () => {
          const requests = await requestPayOnDeliveries()
          const responses = packResponse(randomBoolResponses())
          const reward = await consensus.mock_handleResponses.call(requests, responses, {})
          reward.toNumber().should.be.equal(miningEth * numRequests)
        })

        it(`should call callback contract and receive a IntersectResponse event`, async () => {
          const requests = await requestPayOnDeliveries()
          const responses = packResponse(randomBoolResponses())
          const {tx} = await consensus.mock_handleResponses(requests, responses)

          expectEvent.inTransaction(tx, PayOnDelivery, `IntersectResponse`)
        })

        it(`requests callbacks should have correct answers, and should show as answered`, async () => {
          const requests = await requestPayOnDeliveries()
          const responses = packResponse(randomBoolResponses())

          await consensus.mock_handleResponses(requests, responses)
          const cbResponses = await synchronizePromises(requests.map(r => payOnD.didIntersect(r)))
          // console.log(`CB RESPONSES`, cbResponses)
          cbResponses.forEach((a, i) => {
            a.should.be.equal(!!responses[i])
          })
          const indexPromises = requests.map(async q => payOnD.requestIndex(q))
          const indexes = await synchronizePromises(indexPromises)
          const newPromises = indexes.map(async i => payOnD.requests(i))
          const doneRequests = await synchronizePromises(newPromises)

          // console.log(`RESPONSES`, doneRequests)
          doneRequests.map(r => r.responseAt.toNumber().should.be.gt(0))
        })

        it(`works for uint responses for future interfaces`, async () => {
          const requests = await submitUintRequest()
          const responses = randUintResponse()
          const bytesArr = responses.map(() => `uint`)

          const packedBytes = `0x${abi.solidityPack([...bytesArr], [...responses]).toString(`hex`)}`
          // console.log(packedBytes)
          await consensus.mock_handleResponses(requests, packedBytes).should.be.fulfilled
        })
      })
    })
    describe(`checkSigsAndStakes`, () => {
      it(`should succeed if signers signed a message hash`, async () => {
        const subParams = await generateArgs(true)

        // console.log(`Args`, subParams)
        await consensus.mock_checkSigsAndStakes(
          subParams[SubmitArgsEnum.SIGHASH],
          subParams[SubmitArgsEnum.SIGNERS],
          subParams[SubmitArgsEnum.R],
          subParams[SubmitArgsEnum.S],
          subParams[SubmitArgsEnum.V]
        ).should.be.fulfilled
      })

      it(`should fail if signers not passed in order`, async () => {
        const subParams = await generateArgs(true)
        const unsorted = diviners
          .map(d => d.toLowerCase())
          .sort(compareDiviners)
          .reverse()
        await consensus.mock_checkSigsAndStakes(
          subParams[SubmitArgsEnum.SIGHASH],
          unsorted,
          subParams[SubmitArgsEnum.R],
          subParams[SubmitArgsEnum.S],
          subParams[SubmitArgsEnum.V]
        ).should.not.be.fulfilled
      })

      it(`should fail if quorum not met`, async () => {
        await governance.ownerSet(`xyStakeSuccessPct`, 66, {
          from: governanceOwner
        })
        await advanceBlock()

        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const sortedQuorum = sorted.slice(0, Math.floor(numDiviners - numDiviners * 0.5))
        const subParams = await generateArgs(true)
        await consensus.mock_checkSigsAndStakes(
          subParams[SubmitArgsEnum.SIGHASH],
          sortedQuorum,
          subParams[SubmitArgsEnum.R],
          subParams[SubmitArgsEnum.S],
          subParams[SubmitArgsEnum.V]
        ).should.not.be.fulfilled
      })
    })

    describe(`withdraw request`, () => {
      const stakeAmt = 10000000
      beforeEach(async () => {
        await consensus.fake_updateCacheOnStake(stakeAmt, d1, {from: d1})
        await consensus.fake_updateCacheOnActivate(stakeAmt, d1, {from: d1})
        await erc20.transfer(consensus.address, stakeAmt, {
          from: erc20owner
        })
        await advanceBlock()
      })

      it(`should be able to withdraw rewards`, async () => {
        const balanceBefore = await erc20.balanceOf(d1)
        const args = await withdrawSubmitBlockArgs(stakeAmt, d1)
        await consensus.submitBlock(...args).should.be.fulfilled
        const newBalance = await erc20.balanceOf(d1)
        stakeAmt.should.be.equal(newBalance - balanceBefore)
      })
      it(`should not be able to withdraw over staking`, async () => {
        const args = await withdrawSubmitBlockArgs(stakeAmt + 100, d1)
        await consensus.submitBlock(...args).should.not.be.fulfilled
      })
    })
    describe(`blockForRequest and supportingDataForRequest`, () => {
      beforeEach(async () => {
        const args = await generateArgs()
        await consensus.submitBlock(...args)
      })
      it(`should be able to grab block for request that exists`, async () => {
        const blockForRequest = await consensus.blockForRequest(`0x1`)
        blockForRequest.creator.should.be.equal(consensusOwner)
      })
      it(`should not be able to grab block for request that exists`, async () => {
        const blockForRequest = await consensus.blockForRequest(`0x1adfdf`)
        blockForRequest.creator.should.be.equal(web3.utils.padLeft(`0x0`, 40))
        const blockData = await consensus.supportingDataForRequest(`0x1adfdf`)
        blockData.should.be.equal(web3.utils.padLeft(`0x0`, 64))
      })
      it(`should be able to grab block data for request that exists`, async () => {
        const blockData = await consensus.supportingDataForRequest(`0x1`)
        blockData.should.be.equal(
          `0x290decd9548b62a8d60345a988386fc84ba6bc95484008f6362f93160ef3e563`
        )
      })
    })
  }
)
