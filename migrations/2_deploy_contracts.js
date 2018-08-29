const StandardToken = artifacts.require('StandardToken.sol')
const XyoStaked = artifacts.require('XyoStaked.sol')

module.exports = function _(deployer, network, [owner1]) {
    return deployer.deploy(StandardToken, { from: owner1 }).then((token) => {
      deployer.deploy(XyoStaked, token, 10000, { from: owner1 })
    })
}
