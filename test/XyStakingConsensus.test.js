import { BigNumber } from "bignumber.js"

import { expectEvent } from "openzeppelin-test-helpers"
import { request } from "http"

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)

const PayOnDelivery = artifacts.require(`XyPayOnDeliveryMock.sol`)
const StakingConsensus = artifacts.require(`XyConsensusMock.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const erc20TotalSupply = 1000000

const should = require(`chai`)
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
  params.xyEthMiningCost,
  params.xyXYOMiningCost,
  params.xyStakeCooldown,
  params.xyUnstakeCooldown
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
    before(async () => {
      erc20 = await ERC20.new(erc20TotalSupply, `XYO Token`, `XYO`, {
        from: erc20owner
      })
      parameterizer = await Governance.new({
        from: parameterizerOwner
      })
      plcr = await PLCR.new({
        from: parameterizerOwner
      })
      await plcr.init(erc20.address)

      stakableToken = await Stakeable.new(stakableTokenOwner, diviners, {
        from: stakableContractOwner
      })
    })
    beforeEach(async () => {
      consensus = await StakingConsensus.new(
        diviners,
        erc20.address,
        stakableToken.address,
        parameterizer.address,
        {
          from: consensusOwner
        }
      )
      payOnD = await PayOnDelivery.new(consensus.address, erc20.address, {
        from: payOnDeliveryOwner
      })
      await parameterizer.init(
        consensus.address,
        erc20.address,
        plcr.address,
        parameters,
        { from: parameterizerOwner }
      )
      await advanceBlock()
    })

    const synchronizePromises = async (promises, results = [], index = 0) => {
      if (promises.length === 0) return []

      const next = await promises[index]
      results.push(next)

      if (index === promises.length - 1) {
        return results
      }
      return synchronizePromises(promises, results, index + 1)
    }

    const randomBoolResponses = () => {
      const byteResponses = new Uint8Array(numRequests)
      for (let i = 0; i < numRequests; i++) {
        const random = Math.random() >= 0.5
        byteResponses[i] = random
      }
      return byteResponses
    }
    const randUintResponse = () => {
      const uintResp = []
      for (let j = 0; j < numRequests; j++) {
        const random = Math.random() * 100000000000000
        uintResp[j] = random
      }
      return uintResp
    }

    const submitPayOnDeliverys = async () => {
      const requests = [...Array(numRequests).keys()].map(r => r + 1)
      await erc20.approve(payOnD.address, numRequests * xyoPayment, {
        from: erc20owner
      })
      const promises = requests.map(
        async q => payOnD.submitPayOnDelivery(q, xyoPayment, ethOnDelivery, d3, {
          value: ethOnDelivery + miningEth,
          from: erc20owner
        }).should.be.fulfilled
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
        async q => payOnD.submitUintRequest(q, xyoPayment, ethOnDelivery, d3, {
          value: ethOnDelivery + miningEth,
          from: erc20owner
        }).should.be.fulfilled
      )
      await synchronizePromises(promises)
      return requests
    }

    const compareDiviners = (a, b) => a > b

    const encodeAndSign = async (signer, previous, requests, responses) => {
      const uintArr = requests.map(() => `uint`)
      // console.log(`encodeAndSign`, signer, previous, requests, responses)

      const hash = `0x${abi
        .soliditySHA3(
          [`uint`, ...uintArr, `bytes`],
          [previous, ...requests, responses]
        )
        .toString(`hex`)}`

      const packedBytes = `0x${abi
        .solidityPack(
          [`uint`, ...uintArr, `bytes`],
          [previous, ...requests, responses]
        )
        .toString(`hex`)}`
      // console.log(`HASH`, hash, previous, requests, responses)
      // console.log(`ENCODED BYTES`, packedBytes)

      const signedMessage = await web3.eth.sign(hash, signer)

      const sig = signedMessage.slice(2)
      const r = `0x${sig.slice(0, 64)}`
      const s = `0x${sig.slice(64, 128)}`
      const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27

      return [r, s, v, packedBytes, hash]
    }

    describe(`Submitting blocks`, () => {
      it(`should allow creating a block by consensus of at least 4 diviners`, async () => {
        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const previous = await consensus.getLatestBlock()
        const requests = await submitPayOnDeliverys()
        const responses = randomBoolResponses()
        const promises = sorted.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)
        const r = []
        const s = []
        const v = []
        let testMessage
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          testMessage = sig[3]
        })

        const tx = await consensus.submitBlock(
          previous,
          requests,
          responses,
          sorted,
          r,
          s,
          v,
          testMessage
        ).should.be.fulfilled
        expectEvent.inLogs(tx.logs, `BlockCreated`)
      })

      it(`should return correct previous block`, async () => {
        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const previous = await consensus.getLatestBlock()
        const requests = await submitPayOnDeliverys()
        const responses = randomBoolResponses()
        const promises = sorted.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)
        const r = []
        const s = []
        const v = []
        let testMessage
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          testMessage = sig[3]
        })

        const lastBlock = await consensus.submitBlock.call(
          previous,
          requests,
          responses,
          sorted,
          r,
          s,
          v,
          testMessage
        ).should.be.fulfilled
        await consensus.submitBlock(
          previous,
          requests,
          responses,
          sorted,
          r,
          s,
          v,
          testMessage
        ).should.be.fulfilled
        lastBlock.toString().should.not.be.equal(`0`)
        const newLast = await consensus.getLatestBlock.call()
        newLast.toString().should.be.equal(lastBlock.toString())
      })

      it(`should fail if passes responses doesnt match signed data`, async () => {
        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const previous = await consensus.getLatestBlock()
        const requests = await submitPayOnDeliverys()
        const responses = randomBoolResponses()
        const promises = sorted.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)

        const r = []
        const s = []
        const v = []
        let testMessage
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          testMessage = sig[3]
        })
        // console.log(`Responses Before`, responses)
        const randomIndex = Math.floor(Math.random() * (responses.length - 1))
        responses[randomIndex] = !responses[randomIndex]
        // console.log(`Responses After`, responses)
        await consensus.submitBlock(
          previous,
          requests,
          responses,
          sorted,
          r,
          s,
          v,
          testMessage
        ).should.not.be.fulfilled
      })

      describe(`respondAndCalcReward`, async () => {
        it(`should return correct reward`, async () => {
          const requests = await submitPayOnDeliverys(1)
          const responses = randomBoolResponses()
          const reward = await consensus.mock_respondAndCalcReward.call(
            requests,
            responses,
            {}
          )
          reward.toNumber().should.be.equal(miningEth * numRequests)
        })

        it(`should call callback contract and receive a IntersectResponse event`, async () => {
          const requests = await submitPayOnDeliverys(1)
          const responses = randomBoolResponses()
          const { tx } = await consensus.mock_respondAndCalcReward(
            requests,
            responses
          )

          expectEvent.inTransaction(tx, PayOnDelivery, `IntersectResponse`)
        })

        it(`requests callbacks should have correct answers, and should show as answered`, async () => {
          const requests = await submitPayOnDeliverys()
          const responses = randomBoolResponses()

          await consensus.mock_respondAndCalcReward(requests, responses)
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

        it.only(`works for uint responses for future interfaces`, async () => {
          const requests = await submitUintRequest()
          const responses = randUintResponse()
          const bytesArr = responses.map(() => `uint`)

          const packedBytes = `0x${abi
            .solidityPack([...bytesArr], [...responses])
            .toString(`hex`)}`
          console.log(packedBytes)
          await consensus.mock_respondAndCalcReward(requests, packedBytes)
            .should.be.fulfilled
        })
      })
    })
    describe(`checkSigsAndStake`, () => {
      it(`should succeed if signers signed a message hash`, async () => {
        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const previous = await consensus.getLatestBlock()
        const requests = await submitPayOnDeliverys()
        const responses = randomBoolResponses()
        const promises = sorted.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)
        const r = []
        const s = []
        const v = []
        let hash
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          hash = sig[4]
        })
        await consensus.mock_checkSigsAndStake(hash, sorted, r, s, v).should.be
          .fulfilled
      })

      it(`should fail if signers not passed in order`, async () => {
        const previous = await consensus.getLatestBlock()
        const requests = await submitPayOnDeliverys()
        const responses = randomBoolResponses()
        const promises = diviners.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)
        const r = []
        const s = []
        const v = []
        let hash
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          hash = sig[4]
        })
        await consensus.mock_checkSigsAndStake(hash, diviners, r, s, v).should
          .not.be.fulfilled
      })

      it(`should fail if quorum not met`, async () => {
        const previous = await consensus.getLatestBlock()

        await parameterizer.ownerSet(`xyStakeQuorumPct`, 66, {
          from: parameterizerOwner
        })
        await advanceBlock()

        const sorted = diviners.map(d => d.toLowerCase()).sort(compareDiviners)
        const sortedQuorum = sorted.slice(
          0,
          Math.floor(numDiviners - numDiviners * 0.5)
        )
        const requests = await submitPayOnDeliverys()

        const responses = randomBoolResponses()
        const promises = sortedQuorum.map(async adr => encodeAndSign(adr, previous, requests, responses))
        const sigArr = await synchronizePromises(promises)
        const r = []
        const s = []
        const v = []
        let hash
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          hash = sig[4]
        })
        await consensus.mock_checkSigsAndStake(hash, sortedQuorum, r, s, v)
          .should.not.be.fulfilled
      })
    })
  }
)
