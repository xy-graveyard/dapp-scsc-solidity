import BigNumber from "bignumber.js"

const abi = require(`ethereumjs-abi`)
const { toChecksumAddress } = require(`ethereumjs-util`)

const StakingConsensus = artifacts.require(`XyConsensusMock.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableAddressMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)
const stripHexPrefix = require(`strip-hex-prefix`)

const erc20TotalSupply = 1000000
const should = require(`chai`)
  .use(require(`chai-as-promised`))
  .should()

contract(
  `XyStakableToken`,
  ([
    consensusOwner,
    erc20owner,
    stakableContractOwner,
    stakableTokenOwner,
    parameterizerOwner,
    d1,
    d2,
    d3,
    d4
  ]) => {
    let erc20
    let consensus
    let stakableToken
    let parameterizer
    let plcr
    const diviners = [d1, d2, d3, d4]
    const numDiviners = diviners.length
    const numQuestions = 5

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
      await advanceBlock()
    })

    const createRandomAnswers = () => {
      const byteAnswers = new Uint8Array(numQuestions)
      for (let i = 0; i < numQuestions; i++) {
        const random = Math.random() >= 0.5
        byteAnswers[i] = random
      }
      return byteAnswers
    }

    const createQuestions = async (answerType) => {
      const questions = [...Array(numQuestions).keys()]
      const getQuestions = async () => {
        const promises = questions.map(async q => consensus.submitQuestion(q, erc20owner, answerType))
        return Promise.all(promises)
      }
      await getQuestions()
      return questions
    }

    const compareDiviners = (a, b) => a > b

    const encodeAndSign = async (signer, previous, questions, answers) => {
      const uintArr = questions.map(() => `uint`)

      const hash = `0x${abi
        .soliditySHA3(
          [`uint`, ...uintArr, `bytes`],
          [previous, ...questions, answers]
        )
        .toString(`hex`)}`

      const packedBytes = `0x${abi
        .solidityPack(
          [`uint`, ...uintArr, `bytes`],
          [previous, ...questions, answers]
        )
        .toString(`hex`)}`
      // console.log(`HASH`, hash)
      // console.log(`ENCODED BYTES`, packedBytes)

      const signedMessage = await web3.eth.sign(hash, signer)

      const sig = signedMessage.slice(2)
      const r = `0x${sig.slice(0, 64)}`
      const s = `0x${sig.slice(64, 128)}`
      const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27

      return [r, s, v, packedBytes]
    }

    describe(`Submitting blocks`, () => {
      it(`should be able to handle four diviners submitting blocks`, async () => {
        const sorted = diviners.sort(compareDiviners)

        console.log(`Diviners sorted`, sorted)
        let previousD = 0
        for (let i = 0; i < numDiviners; i++) {
          if (sorted[i] < previousD) {
            console.log(`NOT SORTED`, previousD, sorted[i])
          }
          previousD = sorted[i]
        }
        const previous = await consensus.getLatestBlock()
        console.log(`Previous block `, previous)

        const questions = await createQuestions(0)
        const answers = createRandomAnswers()

        const getSigs = async () => {
          const promises = sorted.map(async adr => encodeAndSign(adr, previous, questions, answers))
          return Promise.all(promises)
        }
        const sigArr = await getSigs()
        const r = []
        const s = []
        const v = []
        let hash
        sigArr.forEach((sig) => {
          r.push(sig[0])
          s.push(sig[1])
          v.push(sig[2])
          hash = sig[3]
        })
        const result = await consensus.submitBlock.call(
          previous,
          questions,
          answers,
          sorted,
          r,
          s,
          v,
          hash
        )
        const tx = await consensus.submitBlock(
          previous,
          questions,
          answers,
          sorted,
          r,
          s,
          v,
          hash
        ).should.be.fulfilled

        console.log(`TX RESULT`, result, tx)
      })
    })
  }
)
