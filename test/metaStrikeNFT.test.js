const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const hre = require('hardhat')

describe("Token contract", function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let MetaStrikeNFTContract;
  let MetaMetalContract;
  let metaMetal;
  let mtsNft;
  let deployer;
  let user1;
  let user2;
  let user3;
  let addrs;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [deployer, user1, user2, user3, ...addrs] = await ethers.getSigners()

    MetaStrikeNFTContract = await hre.ethers.getContractFactory('MetaStrikeCore')
    mtsNft = await MetaStrikeNFTContract.deploy()

    MetaMetalContract = await ethers.getContractFactory("MetaMetal");
    metaMetal = await MetaMetalContract.deploy()
    await mtsNft.setupTierPoint([100,210,360,440], 4);
    await mtsNft.setupMetalAddress(metaMetal.address);

    await metaMetal.setupMetal(0, 1, 1, 10, 8000);
    await metaMetal.setupMetal(1, 1, 2, 15, 7500);
    await metaMetal.setupMetal(2, 1, 3, 20, 7000);
    await metaMetal.setupMetal(3, 1, 4, 25, 6500);
    await metaMetal.setupMetal(4, 1, 5, 30, 6000);

    await metaMetal.setupMetal(5, 1, 5, 60, 2000); //test silvin lv5
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    // it("Deployment with dependencies!", async function () {
    //   console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    // });

    it("Safe Mint Gun", async function () {
        // mint nft id 0 = GL32 Uncom	0,45	7	32	15	26	29	6
        // weaponCat = 0 (gun), weaponType = 1, skin = 1, color = 1, tier = 0 (unCommon), slot = 6, point = 100 (10.0), release at timestamp 30
        await mtsNft.safeMint(deployer.address, 0, 1, 1, 1, 0, 6, 100, 30);
        // await mtsNft.safeMint(deployer.address, 2, 1, 762);
        // await mtsNft.safeMint(deployer.address, 6, 1, 556);
        expect(await mtsNft.balanceOf(deployer.address)).to.be.equal(1);
    });

    it("Attach Metal", async function () {
        // mint nft id 0 = GL32 Uncom	0,45	7	32	15	26	29	6
        // weaponCat = 0 (gun), weaponType = 1, skin = 1, color = 1, tier = 0 (unCommon), slot = 6, point = 100 (10.0), release at timestamp 30
        await mtsNft.safeMint(deployer.address, 0, 1, 1, 1, 0, 6, 100, 30);
        //mint 5 kinds of metal with quantity
        await metaMetal.mintBatch(deployer.address, [0, 1, 2, 3, 4], [10, 10, 10, 10, 10], "0x00");
        // attach 4 metal with id 0, 2, 4, 3 into gun 0
        // console.log(await mtsNft.weapons(0));
        weapon0Info = await mtsNft.weapons(0)
        console.log('point: ', weapon0Info.point.toString());
        console.log('slot: ', weapon0Info.slot.toString());
        console.log('tier: ', weapon0Info.tier.toString());
        await metaMetal.setApprovalForAll(mtsNft.address, true);
        await mtsNft.attachMetal([0, 2, 4, 3], 0);

        weapon0Info = await mtsNft.weapons(0)
        console.log('point: ', weapon0Info.point.toString());
        console.log('slot: ', weapon0Info.slot.toString());
        console.log('tier: ', weapon0Info.tier.toString());

        expect(await metaMetal.balanceOf(deployer.address, 0)).to.be.equal(9);
        expect(await metaMetal.balanceOf(deployer.address, 2)).to.be.equal(9);
        expect(await metaMetal.balanceOf(deployer.address, 4)).to.be.equal(9);
        expect(await metaMetal.balanceOf(deployer.address, 3)).to.be.equal(9);
    });

    it("Attach Metal with upgrade tier", async function () {
        // mint nft id 0 = GL32 Uncom	0,45	7	32	15	26	29	6
        // weaponCat = 0 (gun), weaponType = 1, skin = 1, color = 1, tier = 0 (unCommon), slot = 6, point = 100 (10.0), release at timestamp 30
        await mtsNft.safeMint(deployer.address, 0, 1, 1, 1, 0, 6, 100, 30);
        //mint 5 kinds of metal with quantity
        await metaMetal.mintBatch(deployer.address, [5], [10], "0x00");
        // attach 4 metal with id 0, 2, 4, 3 into gun 0
        // console.log(await mtsNft.weapons(0));
        weapon0Info = await mtsNft.weapons(0)
        console.log('point: ', weapon0Info.point.toString());
        console.log('slot: ', weapon0Info.slot.toString());
        console.log('tier: ', weapon0Info.tier.toString());
        await metaMetal.setApprovalForAll(mtsNft.address, true);
        await mtsNft.attachMetal([5, 5, 5, 5, 5, 5], 0);

        weapon0Info = await mtsNft.weapons(0)
        console.log('point: ', weapon0Info.point.toString());
        console.log('slot: ', weapon0Info.slot.toString());
        console.log('tier: ', weapon0Info.tier.toString());
        expect(await metaMetal.balanceOf(deployer.address, 5)).to.be.equal(4);
    });
  });
});