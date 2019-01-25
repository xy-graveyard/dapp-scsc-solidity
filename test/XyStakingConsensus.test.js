import BigNumber from "bignumber.js"

const abi = require(`ethereumjs-abi`)

const StakingConsensus = artifacts.require(`XyStakingConsensus.sol`)
const ERC20 = artifacts.require(`XyERC20Token.sol`)
const Stakeable = artifacts.require(`XyStakableMock.sol`)
const Governance = artifacts.require(`XyGovernance.sol`)
const PLCR = artifacts.require(`PLCRVoting.sol`)

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
    parameterizerOwner
  ]) => {
    let erc20
    let consensus
    let stakableToken
    let stakeeList
    let parameterizer
    let plcr

    const numDiviners = 4
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

      stakableToken = await Stakeable.new(numDiviners, stakableTokenOwner, {
        from: stakableContractOwner
      })

      console.log(`STAKEE LIST`, stakeeList)
    })
    beforeEach(async () => {
      consensus = await StakingConsensus.new(
        erc20.address,
        stakableToken.address,
        parameterizer.address,
        {
          from: consensusOwner
        }
      )
      await advanceBlock()
    })

    const fetchDiviners = async () => {
      const promises = []
      let ds = []
      for (let i = 0; i < numDiviners; i++) {
        promises.push(stakableToken.stakeeMocks(i))
      }
      await Promise.all(promises).then((values) => {
        ds = values
      })

      return ds
    }

    const createRandomAnswers = async () => {
      const byteAnswers = Uint8Array(numQuestions)

      for (let i = 0; i < numDiviners; i++) {
        const random = Math.random() >= 0.5
        byteAnswers.push(random)
      }
      return byteAnswers
    }

    const compareDiviners = (a, b) => new BigNumber(a).comparedTo(new BigNumber(b))

    const encodeAndSign = async (signer, previous, questions, answers) => {
      const qs = questions.map(q => ({ t: `uint`, v: q }))
      const hash = `0x${abi
        .soliditySHA3({ t: `uint`, v: previous }, ...qs, { t: `bytes`, v: answers })
        .toString(`hex`)}`

      // const hash = abi.simpleEncode(ownee, deviceOwner)
      // const hash = web3.utils.sha3(ownee, deviceOwner)
      const signedMessage = await web3.eth.sign(hash, signer)

      const sig = signedMessage.slice(2)
      const r = `0x${sig.slice(0, 64)}`
      const s = `0x${sig.slice(64, 128)}`
      const v = web3.utils.toDecimal(sig.slice(128, 130)) + 27
      return r, s, v
    }
    describe(`Submitting blocks`, () => {
      it(`should be able to handle four diviners submitting blocks`, async () => {
        const diviners = await fetchDiviners()
        console.log(`Diviners`, diviners)
        const sorted = diviners.sort(compareDiviners)
        console.log(`Diviners sorted`, sorted)
        const previous = await consensus.getLatestBlock()
        console.log(`Previous block `, previous)

        const questions = [...Array(numQuestions).keys()]

        const answers = createRandomAnswers()
        const r = []
        const s = []
        const v = []
        diviners.forEach((adr) => {
          const sig = encodeAndSign(adr, previous, questions, answers)
          r.push(sig.r)
          s.push(sig.s)
          v.push(sig.v)
        })
        await consensus.submitBlock(
          previous,
          questions,
          answers,
          diviners,
          r,
          s,
          v
        ).should.be.fulfilled
      })
    })
  }
)
