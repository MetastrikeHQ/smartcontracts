const {expect} = require('chai')

describe('MetaMarketplace contract', function () {
	// Mocha has four functions that let you hook into the the test runner's
	// lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

	// They're very useful to setup the environment for tests, and to clean it
	// up after they run.

	// A common pattern is to declare some variables, and assign them in the
	// `before` and `beforeEach` callbacks.

    let owner, user1, user2, user3
    let MtsContract, mtsToken
    let MetaNFTContract, metaNFT
    let MetaMarketContract, metaMarket


	// `beforeEach` will run before each test, re-deploying the contract every
	// time. It receives a callback, which can be async.
	beforeEach(async function () {
		[owner, user1, user2, user3, ...addrs] = await ethers.getSigners()

        MetaNFTContract = await ethers.getContractFactory("MetaStrikeCore");
        // metaNFT = await MetaNFTContract.deploy();
        metaNFT = await upgrades.deployProxy(MetaNFTContract);

        MtsContract = await ethers.getContractFactory("MetaStrike");
        mtsToken = await MtsContract.deploy();

        MetaMarketContract = await ethers.getContractFactory("MetaMarketplace");
        metaMarket = await MetaMarketContract.deploy(mtsToken.address, "3000"); // allow MTS for trading on MetaMarketplace and marketFee is 3%

	})

	// You can nest describe calls to create subsections.
	describe('Deployment', function () {

		it('Test Deployment', async function () {
            const marketDefaultFee = await metaMarket.marketFee()
            expect(marketDefaultFee).to.be.equal("3000");
            expect(await metaMarket.isPaymentAccepted(mtsToken.address)).to.be.equal(true);
		})

		it('Test Setup', async function () {
            await metaMarket.configNftType(metaNFT.address, true, false);
            let nftInfo = await metaMarket.nfts(metaNFT.address);
            expect(nftInfo[0]).to.be.equal(true);
            expect(nftInfo[1]).to.be.equal(false);
		})

		it('Test List&Buy Item 721', async function () {
            // function safeMint(address to, uint256 _weapon, uint256 _skin, uint8 _tier,  uint8 _slot, uint256 _timeLock) public onlyRole(MINTER_ROLE) {
            await metaNFT.safeMint(user1.address, 1, 2, 3, 4, 0);
			expect(await metaNFT.balanceOf(user1.address)).to.be.equal(1);
            await metaMarket.configNftType(metaNFT.address, true, false);

			await metaNFT.connect(user1).setApprovalForAll(metaMarket.address, true);
			await metaMarket.connect(user1).createListing(metaNFT.address, 0, 1, mtsToken.address, "1000000000", 0, 0);
			await mtsToken.mint(user2.address, "2000000000000000");
			await mtsToken.connect(user2).approve(metaMarket.address, "10000000000000000000");
			await metaMarket.connect(user2).buyAsset(0, 1);
			expect (await metaNFT.ownerOf(0)).to.be.equal(user2.address);
			expect (await metaNFT.balanceOf(user1.address)).to.be.equal(0);
            expect (await mtsToken.balanceOf(user1.address)).to.be.equal(970000000);
            expect (await mtsToken.balanceOf(metaMarket.address)).to.be.equal(30000000);
		})

		it('Test Cancel', async function () {
            await metaNFT.safeMint(user1.address, 1, 2, 3, 4, 0);
			expect(await metaNFT.balanceOf(user1.address)).to.be.equal(1);
            await metaMarket.configNftType(metaNFT.address, true, false);

			await metaNFT.connect(user1).setApprovalForAll(metaMarket.address, true);
			await metaMarket.connect(user1).createListing(metaNFT.address, 0, 1, mtsToken.address, "1000000000", 0, 0);
            expect(await metaNFT.balanceOf(user1.address)).to.be.equal(0);
            await metaMarket.connect(user1).cancelListing(0);
            expect (await metaNFT.ownerOf(0)).to.be.equal(user1.address);
			await mtsToken.mint(user2.address, "2000000000000000");
			await mtsToken.connect(user2).approve(metaMarket.address, "10000000000000000000");
			await expect(metaMarket.connect(user2).buyAsset(0, 1)).to.be.revertedWith("MM: Listing was canceled!");
		})
	})
})