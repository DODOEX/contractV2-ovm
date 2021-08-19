const { deploySwitch } = require('../truffle-config.ovm.js')
var OpTest = artifacts.require("OpTest");
var OpTest2 = artifacts.require("OpTest2");
var proxyFactory = artifacts.require("ProxyFactory");

module.exports = function (deployer) {
  if (deploySwitch.TEST) {
    // deployer.deploy(OpTest, { gasPrice: 15000000 });
    // deployer.deploy(OpTest2, { gasPrice: 15000000 });
    deployer.deploy(proxyFactory, { gasPrice: 15000000});
  }
};
