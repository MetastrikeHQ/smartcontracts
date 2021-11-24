require("@nomiclabs/hardhat-waffle");
require('dotenv').config()


const mnemonic = process.env.MNEMONIC

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",

	networks: {
		localhost: {
			url: "http://127.0.0.1:8545"
		},
		testnet: {
			url: "https://data-seed-prebsc-1-s3.binance.org:8545/",
			chainId: 97,
			gasPrice: 'auto',
			accounts: {mnemonic: mnemonic}
		},
		mumbai: {
			url: "https://matic-mumbai.chainstacklabs.com/",
			chainId: 80001,
			gasPrice: 'auto',
			accounts: {mnemonic: mnemonic}
		},
		hardhat: {
			gas: 9000000,
			blockGasLimit: 0x1fffffffffffff,
			allowUnlimitedContractSize: true
		},
	},
	solidity: {
		compilers: [
			{
				version: "0.4.18",
			},
			{
				version: "0.5.0",
			},
			{
				version: "0.5.16",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			},
			{
				version: "0.6.6",
				settings: {},
			},
			{
				version: "0.8.4",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
				},
			}
		],
	},
};
