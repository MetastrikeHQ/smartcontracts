const hre = require('hardhat')

async function main () {

	const addressesMainnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3'
    }

	const addressesTestnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3'
	}

	const accounts = await hre.ethers.getSigners()
    const deployer = accounts[0];
    const user = accounts[1];
    console.log('Deployer address', deployer.address)
	const options = {
		gasLimit: 4000000
	}


	const MTSTokenContract = await hre.ethers.getContractFactory('MetaStrike')
	const mtsToken = await MTSTokenContract.deploy()
	await mtsToken.deployed()

	console.log('Metastrike ERC20 address: ', mtsToken.address)

    await mtsToken.mint(user.address, "10000000000000000000000");

    const MetaStrikeNFTContract = await hre.ethers.getContractFactory('MetaStrikeNFT')
    const mtsNft = await MetaStrikeNFTContract.deploy()
    await mtsNft.deployed()
	console.log('Metastrike ERC721 address: ', mtsNft.address)

    await mtsNft.safeMint(deployer.address, 1, 1, 30, options);
    await mtsNft.safeMint(deployer.address, 2, 1, 762, options);
    await mtsNft.safeMint(deployer.address, 6, 1, 556, options);

    const MetaMarketplaceContract = await hre.ethers.getContractFactory('MetaMarketplace')
    const metaMarket = await MetaMarketplaceContract.deploy(deployer.address, mtsToken.address, 100);
    await metaMarket.deployed()
	console.log('Meta Market address: ', metaMarket.address)

    await mtsNft.setApprovalForAll(metaMarket.address);
    console.log('Done Approve');

    
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error)
		process.exit(1)
	})