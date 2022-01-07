const hre = require('hardhat')

const getAllRows = async (fileName) => {
	return new Promise((resolve, reject) => {
		const csv = require('csv-parser')
		const fs = require('fs')
		let results = []

		fs.createReadStream(fileName)
			.pipe(csv())
			.on('data', (data) => results.push(data))
			.on('end', () => {
				resolve(results)
			})
	})
}

async function main () {

	const addressesMainnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
        vestingApp: '0xB72C07429714ffe8762d4e223D5E8DB9940d7daC'
    }

	const addressesTestnet = {
		pancakeswap_router: '0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3',
        vestingApp : '0xB72C07429714ffe8762d4e223D5E8DB9940d7daC'
	}


	const accounts = await hre.ethers.getSigners()
	const MetaStrikeTokenContract = await hre.ethers.getContractFactory('MetaStrike')
	// const MetaStakingContract = await hre.ethers.getContractFactory('MetaStaking')

	const options = {
		gasLimit: 4000000
	}

	// const mtsToken = await MetaStrikeTokenContract.deploy()

    const MetaVestingContract = await ethers.getContractFactory("MetaVesting");
    const now = Math.round(new Date().getTime() / 1000);
    const metaVesting = await MetaVestingContract.attach(addressesTestnet.vestingApp)
    
    let addressesFile = './scripts/address_list.csv'
	let resAllRows = await getAllRows(addressesFile)
	let tx, res
	let totalRow = 0
	let eachTx = 400
    console.log('Before Loop')
	for (let i = 0; i < resAllRows.length; i += eachTx) {
		let addresses = []
		let amounts = []
		for (let j = 0; j < eachTx; j++) {
			try {
				const row = resAllRows[i + j]
				for (const key of Object.keys(row)) {
					row[key.trim()] = row[key]
				}
				addresses.push(row.address)
			} catch {
				break
			}
		}
		console.log(addresses)
        tx = await metaVesting.setupVestingUser(0, 100000, addresses);
		res = await tx.wait()
		console.log('Batch ', i / eachTx, res.status, 'with ', res.transactionHash)
    }

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error)
		process.exit(1)
	})