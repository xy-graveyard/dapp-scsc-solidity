const XyERC20 = artifacts.require(`XyERC20Token.sol`)
const StakedConsensus = artifacts.require(`XyStakedConsensus.sol`)

module.exports = function (deployer, network, [owner1]) {
  return deployer.deploy(XyERC20, `100000000000000000000000000`, `XYO Network`, `XYO`, { from: owner1 })
    .then(() => deployer.deploy(StakedConsensus, XyERC20.address, 1000, ``, { from: owner1 }))
}
