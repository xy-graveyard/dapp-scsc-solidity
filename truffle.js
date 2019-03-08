require(`babel-register`)({
  ignore: /node_modules\/(?!openzeppelin-solidity)/
})
require(`babel-polyfill`)
const HDWalletProvider = require(`truffle-hdwallet-provider`)
require(`dotenv`).config() // Store environment-specific variable from '.env' to process.env
const NonceTrackerSubprovider = require(`web3-provider-engine/subproviders/nonce-tracker`)

// NOTE: If retreiving mnemonic from Metamask - use 1st wallet in profile list.

const wallet = process.env.WALLET
const mnemonic = process.env.MNENOMIC
const infuraKey = process.env.INFURA_API_KEY

module.exports = {
  migrations_directory: `./migrations`,
  networks: {
    development: {
      network_id: `*`, // Match any network id
      host: `localhost`,
      gas: 6721975,
      port: 8545
    },
    kovan: {
      network_id: 42,
      from: wallet,
      provider: () => new HDWalletProvider(
        mnemonic,
        `https://kovan.infura.io/v3/${infuraKey}`
      ),
      gas: 6986331,
      gasPrice: 5500000000
    },
    ropsten: {
      network_id: 3,
      provider: () => new HDWalletProvider(
        mnemonic,
        `https://ropsten.infura.io/${infuraKey}`
      ),
      gas: 6986331,
      gasPrice: 3500000000
    },
    mainnet: {
      network_id: `1`,
      provider: () => {
        const wallet = new HDWalletProvider(
          mnemonic,
          `https://mainnet.infura.io/${infuraKey}`
        )
        const nonceTracker = new NonceTrackerSubprovider()
        wallet.engine._providers.unshift(nonceTracker)
        nonceTracker.setEngine(wallet.engine)
        return wallet
      },
      gas: 6986331,
      gasPrice: 25000000000
    }
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  },
  compilers: {
    solc: {
      version: `0.5.4`
    }
  }
}
