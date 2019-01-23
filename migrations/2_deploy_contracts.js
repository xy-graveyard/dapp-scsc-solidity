const plcr = artifacts.require(`PLCRVoting.sol`)
const attrStore = artifacts.require(`AttributeStore.sol`)
const dll = artifacts.require(`DLL.sol`)
const safeERC20 = artifacts.require(`SafeERC20.sol`)
const staking = artifacts.require(`XyStakingToken.sol`)
const stakableToken = artifacts.require(`XyStakableMock.sol`)
const parameterizer = artifacts.require(`XyGovernance.sol`)
const erc20 = artifacts.require(`XyERC20Token.sol`)

module.exports = async function (deployer, network, [owner1]) {
  await deployer.deploy(attrStore)
  // await deployer.deploy(safeERC20)
  await deployer.deploy(dll)
  await deployer.link(attrStore, plcr)
  await deployer.link(dll, plcr)
  // await deployer.link(safeERC20, erc20)
  console.log(`Done linking`)
  // await deployer.deploy(plcr)
  // await deployer.deploy(erc20, 1000000, `fake`, `fa`)
  // await deployer.deploy(
  //   staking,
  //   erc20.address,
  //   stakableToken.address,
  //   parameterizer.address
  // )
}
