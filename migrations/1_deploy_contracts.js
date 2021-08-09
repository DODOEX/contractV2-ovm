
var SimpleStorage = artifacts.require("SimpleStorage");
var OpTest = artifacts.require("OpTest");

module.exports = function(deployer) {
  // deployer.deploy(SimpleStorage, { gasPrice: 15000000 });
  deployer.deploy(OpTest, { gasPrice: 15000000 });
};
