import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)

const PayOnDelivery = artifacts.require(`XyPayOnDeliveryMock.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const erc20TotalSupply = 1000000

require(`chai`)
  .use(require(`chai-as-promised`))
  .use(require(`chai-bignumber`)(BigNumber))
  .should()
const fs = require(`fs`)
const config = JSON.parse(fs.readFileSync(`./config/testParams.json`))
const params = config.paramDefaults
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
contract(
  `XyStakingConsensus`,
  ([
    consensusOwner,
    erc20owner,
    stakableContractOwner,
    stakableTokenOwner,
    parameterizerOwner,
    d1,
    d2,
    d3,
    d4,
    payOnDeliveryOwner
  ]) => {
    let erc20
    let consensus
    let stakableToken
    let parameterizer
    let plcr
    const diviners = [
      d1,
      d2,
      d3,
      d4,
      stakableContractOwner,
      stakableTokenOwner,
      parameterizerOwner,
      payOnDeliveryOwner
    ]
    const numDiviners = diviners.length
    const numRequests = 2
    let payOnD
    const xyoPayment = 200
    const xyoBounty = 0
    const ethOnDelivery = 1000
    const miningEth = 100

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

    const requestPayOnDeliveries = async () => {
      const requests = [...Array(numRequests).keys()].map(r => r + 1)
      await erc20.approve(payOnD.address, numRequests * xyoPayment, {
        from: erc20owner
      })
      const promises = requests.map(
        async q => payOnD.requestPayOnDelivery(
          q,
          xyoPayment,
          xyoBounty,
          ethOnDelivery,
          d3,
          {
            value: ethOnDelivery + miningEth,
            from: erc20owner
          }
        ).should.be.fulfilled
      )
      await synchronizePromises(promises)
      return requests
    }

    const submitUintRequest = async () => {
      const requests = [...Array(numRequests).keys()].map(r => r + 1)
      await erc20.approve(payOnD.address, numRequests * xyoPayment, {
        from: erc20owner
      })
      const promises = requests.map(
        async q => payOnD.submitUintRequest(
          q,
          xyoPayment,
          xyoBounty,
          ethOnDelivery,
          d3,
          {
            value: ethOnDelivery + miningEth,
            from: erc20owner
          }
        ).should.be.fulfilled
      )
      await synchronizePromises(promises)
      return requests
    }

    const compareDiviners = (a, b) => a > b

    const createArgs = async (requests, packedResponses, returnHash) => {
      const previous = await consensus.getLatestBlock()
      const responseDataHash = abi.soliditySHA3([`bytes32`], [previous]) // a bogus hash
      const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
      const promises = sorted.map(async adr => encodeAndSign(
        adr,
        previous,
        requests,
        responseDataHash,
        packedResponses
      ))
      const sigArr = await synchronizePromises(promises)
      const r = []
      const s = []
      const v = []
      let packedMsg
      let hash
      sigArr.forEach((sig) => {
        r.push(sig[0])
        s.push(sig[1])
        v.push(sig[2])
        packedMsg = sig[3]
        hash = sig[4]
      })
      const args = [
        d1,
        previous,
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
      await consensus.withdrawRewardsRequest(0, { from })
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
      responses.push({ type, value: val })
    }

    const packResponse = (responses) => {
      const responseTypes = responses.map(r => r.type)
      const responseValues = responses.map(r => r.value)
      // console.log(`TYPES AND VALUES`, responseTypes, responseValues)

      const packedBytes = abi.solidityPack(
        [...responseTypes],
        [...responseValues]
      )

      // console.log(`Packed`, packedBytes)
      return packedBytes
    }
    const encodeAndSign = async (
      signer,
      previous,
      requests,
      responseDataHash,
      packedResponses
    ) => {
      const uintArr = requests.map(() => `uint`)

      const hash = `0x${abi
        .soliditySHA3(
          [`uint`, ...uintArr, `bytes32`, `bytes`],
          [previous, ...requests, responseDataHash, packedResponses]
        )
        .toString(`hex`)}`

      const packedBytes = `0x${abi
        .solidityPack(
          [`uint`, ...uintArr, `bytes32`, `bytes`],
          [previous, ...requests, responseDataHash, packedResponses]
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
        from: parameterizerOwner
      })
      await plcr.initialize(erc20.address)
      stakableToken = await Stakeable.new(consensusOwner, diviners, {
        from: stakableContractOwner
      })
      beforeEach(async () => {
        parameterizer = await Governance.new({
          from: parameterizerOwner
        })
        consensus = await StakingConsensus.new(
          diviners,
          erc20.address,
          stakableToken.address,
          parameterizer.address,
          {
            from: consensusOwner
          }
        )
        await parameterizer.initialize(
          consensus.address,
          erc20.address,
          plcr.address,
          parameters,
          { from: parameterizerOwner }
        )
        payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
          from: payOnDeliveryOwner
        })
      })
      await advanceBlock()
    })

    describe(`Submit Request`, () => {
      it(`Should only allow creating withdraw, uint, and bool request types`, async () => {
        await consensus.submitRequest(1, 0, d1, 1).should.be.fulfilled
        await consensus.submitRequest(2, 0, d1, 2).should.be.fulfilled
        await consensus.submitRequest(3, 0, d1, 3).should.be.fulfilled
        await consensus.submitRequest(4, 0, d1, 4).should.not.be.fulfilled
        await consensus.submitRequest(5, 0, d1, 0).should.not.be.fulfilled
      })
      it(`Should not allow duplicate requests`, async () => {
        await consensus.submitRequest(1, 0, d1, 1).should.be.fulfilled
        await consensus.submitRequest(1, 0, d1, 2).should.not.be.fulfilled
      })
      it(`Should not allow requests under minimum bounty if in place`, async () => {
        const min = 100
        await parameterizer.ownerSet(`xyXYORequestBountyMin`, min, {
          from: parameterizerOwner
        })
        await parameterizer.ownerSet(`xyWeiMiningMin`, min, {
          from: parameterizerOwner
        })
        await erc20.transfer(d1, 500, { from: erc20owner })
        await erc20.approve(consensus.address, 500, { from: d1 })
        await consensus.submitRequest(1, 0, d1, 1, { from: d1 }).should.not.be
          .fulfilled
        await consensus.submitRequest(1, 0, d1, 1, { from: d1, value: min })
          .should.not.be.fulfilled
        await consensus.submitRequest(1, min, d1, 1, { from: d1, value: 99 })
          .should.not.be.fulfilled
        await consensus.submitRequest(1, min, d1, 1, { from: d1, value: min })
          .should.be.fulfilled

        const contractBalance = await erc20.balanceOf(consensus.address)
        contractBalance.toNumber().should.be.equal(min)
      })
    })
    describe(`Submitting blocks`, () => {
      it(`should allow creating a block by consensus of at least 4 diviners`, async () => {
        const tx = await consensus.submitBlock(...(await generateArgs())).should
          .be.fulfilled
        expectEvent.inLogs(tx.logs, `BlockCreated`)
      })

      it(`should return correct previous block`, async () => {
        const args = await generateArgs()
        const lastBlock = await consensus.submitBlock.call(...args).should.be
          .fulfilled
        await consensus.submitBlock(...args).should.be.fulfilled
        lastBlock.toString().should.not.be.equal(`0`)
        const newLast = await consensus.getLatestBlock.call()
        newLast.toString().should.be.equal(lastBlock.toString())
      })

      it(`should fail if passes responses doesnt match signed data`, async () => {
        const submitParams = await generateArgs()
        const randomIndex = Math.floor(
          Math.random() * (submitParams[2].length - 1)
        )
        submitParams[2][randomIndex] = !submitParams[2][randomIndex]
        // console.log(`Responses After`, responses)
        await consensus.submitBlock(...submitParams).should.not.be.fulfilled
      })

      describe(`handleResponses`, async () => {
        it(`should return correct reward`, async () => {
          const requests = await requestPayOnDeliveries(1)
          const responses = packResponse(randomBoolResponses())
          const reward = await consensus.mock_handleResponses.call(
            requests,
            responses,
            {}
          )
          reward.toNumber().should.be.equal(miningEth * numRequests)
        })

        it(`should call callback contract and receive a IntersectResponse event`, async () => {
          const requests = await requestPayOnDeliveries(1)
          const responses = packResponse(randomBoolResponses())
          const { tx } = await consensus.mock_handleResponses(
            requests,
            responses
          )

          expectEvent.inTransaction(tx, PayOnDelivery, `IntersectResponse`)
        })

        it(`requests callbacks should have correct answers, and should show as answered`, async () => {
          const requests = await requestPayOnDeliveries()
          const responses = packResponse(randomBoolResponses())

          await consensus.mock_handleResponses(requests, responses)
          const cbResponses = await synchronizePromises(
            requests.map(r => payOnD.didIntersect(r))
          )
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

          const packedBytes = `0x${abi
            .solidityPack([...bytesArr], [...responses])
            .toString(`hex`)}`
          // console.log(packedBytes)
          await consensus.mock_handleResponses(requests, packedBytes).should.be
            .fulfilled
        })
      })
    })
    describe(`checkSigsAndStakes`, () => {
      it(`should succeed if signers signed a message hash`, async () => {
        const subParams = await generateArgs(true)

        // console.log(`Args`, subParams)
        await consensus.mock_checkSigsAndStakes(
          subParams[9],
          subParams[5],
          subParams[6],
          subParams[7],
          subParams[8]
        ).should.be.fulfilled
      })

      it(`should fail if signers not passed in order`, async () => {
        const subParams = await generateArgs(true)
        await consensus.mock_checkSigsAndStakes(
          subParams[9],
          diviners,
          subParams[6],
          subParams[7],
          subParams[8]
        ).should.not.be.fulfilled
      })

      it(`should fail if quorum not met`, async () => {
        await parameterizer.ownerSet(`xyStakeQuorumPct`, 66, {
          from: parameterizerOwner
        })
        await advanceBlock()

        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const sortedQuorum = sorted.slice(
          0,
          Math.floor(numDiviners - numDiviners * 0.5)
        )
        const subParams = await generateArgs(true)
        await consensus.mock_checkSigsAndStakes(
          subParams[9],
          sortedQuorum,
          subParams[6],
          subParams[7],
          subParams[8]
        ).should.not.be.fulfilled
      })
    })

    describe(`withdraw request`, () => {
      const stakeAmt = 10000000
      beforeEach(async () => {
        await consensus.fake_updateCacheOnStake(stakeAmt, d1, { from: d1 })
        await consensus.fake_updateCacheOnActivate(stakeAmt, d1, { from: d1 })
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
  }
)
