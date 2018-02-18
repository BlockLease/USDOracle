'use strict';

const USDOracle = artifacts.require('USDOracle.sol');

module.exports = async function(deployer) {
  await deployer.deploy(USDOracle);
};
