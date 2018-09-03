const XyoStaked = artifacts.require(`XyoStaked.sol`)
const StandardToken = artifacts.require(`StandardToken.sol`)

module.exports = function _ (deployer, network, [owner1]) {
  const token = deployer.deploy(StandardToken, `10000000000000000000000000`, { from: owner1 })
  return deployer.deploy(XyoStaked, token, 30, { from: owner1 })
}
