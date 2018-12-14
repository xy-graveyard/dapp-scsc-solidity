const StandardToken = artifacts.require(`StandardToken.sol`)
const StakedConsensus = artifacts.require(`XyStakedConsensus.sol`)

module.exports = function (deployer, network, [owner1]) {
  return deployer.deploy(StandardToken, `100000000000000000000000000`, { from: owner1 })
    .then(() => deployer.deploy(StakedConsensus, StandardToken.address, 1000, ``, { from: owner1 }))
}
