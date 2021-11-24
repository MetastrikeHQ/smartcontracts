const hre = require('hardhat')

async function main () {

	const addressesMainnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3'
    }

	const addressesTestnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3'
	}


	const accounts = await hre.ethers.getSigners()
	const MetaStrikeTokenContract = await hre.ethers.getContractFactory('MetaStrike')
	// const MetaStakingContract = await hre.ethers.getContractFactory('MetaStaking')

	const options = {
		gasLimit: 4000000
	}

	const mtsToken = await MetaStrikeTokenContract.deploy()
	await mtsToken.deployed()

	console.log('Metastrike token address: ', mtsToken.address)
    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error)
		process.exit(1)
	})