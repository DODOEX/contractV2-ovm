// create a file at the root of your project and name it .env -- there you can set process variables
// like the mnemomic below. Note: .env is ignored by git in this project to keep your private information safe
require("ts-node/register"); 
require('dotenv').config();
const privKey = process.env.privKey;
const infuraId = process.env.infuraId;

const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {

  /**
  * contracts_build_directory tells Truffle where to store compiled contracts
  */
  contracts_build_directory: './build/optimism-contracts',

  /**
  *  contracts_directory tells Truffle where to find your contracts
  */
  contracts_directory: './contracts/optimism',

  deploySwitch: {
    TEST:      false,
    DEPLOY_V2: false,
  },

  networks: {
    development: {
      url: "http://127.0.0.1:8545",
      network_id: "*",
    },
    optimistic_kovan: {
      networkCheckTimeout: 100000,
      network_id: 69,
      chain_id: 69,
      gasPrice: 15000000,
      gas: 218590000,
      provider: function() {
        return new HDWalletProvider(privKey, "https://kovan.optimism.io");
      }
    },
    optimistic_mainnet: {
      network_id: 10,
      chain_id: 10,
      provider: function() {
        return new HDWalletProvider(privKey, "https://optimism-mainnet.infura.io/v3/" + infuraId);
      }
    },
    omgx_rinkeby: {
      networkCheckTimeout: 100000,
      network_id: 28,
      chain_id: 28,
      gasPrice: 15000000,
      gas: 218590000,
      provider: function () {
        return new HDWalletProvider(privKey, "https://rinkeby.omgx.network");
      }
    }
  },

  mocha: {
    timeout: 100000
  },
  compilers: {
    solc: {
      version: "node_modules/@eth-optimism/solc", //0.7.6
      settings:  {
        optimizer: {
          enabled: true,
          runs: 800
        }
      }
    },
  },
  db: {
    enabled: false
  }
}
