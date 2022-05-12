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

  let MtsTokenContract;
  let MetaStrikeNFTContract;
  let MetastrikeBoxContract;
  let metaBox;
  let mtsNft;
  let deployer;
  let user1;
  let user2;
  let user3;
  let addrs;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {

    // Get the ContractFactory and Signers here.
    //MetaStrike Token
    MtsTokenContract = await ethers.getContractFactory("MetaStrike");
    [deployer, user1, user2, user3, user4, user5, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    mtsToken = await MtsTokenContract.deploy();

    zeroAdd = '0x0000000000000000000000000000000000000000'

    MetaStrikeNFTContract = await hre.ethers.getContractFactory('MetaStrikeCore')
    mtsNft = await MetaStrikeNFTContract.deploy(zeroAdd, zeroAdd)

    MetastrikeBoxContract = await hre.ethers.getContractFactory('MetaStrikeBox')
    metaBox = await MetastrikeBoxContract.deploy(mtsNft.address, 123)

    console.log(deployer.address)

    const mintRole = await mtsNft.MINTER_ROLE()
    await mtsNft.grantRole(mintRole, metaBox.address);

  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    // it("Deployment with dependencies!", async function () {
    //   console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    // });

    it("Safe Mint Gun", async function () {
        await mtsNft.safeMint(deployer.address, 1, 1, 3, 4, 4, 5, 6, 30);
        await mtsNft.safeMint(deployer.address, 2, 1, 5, 8, 6, 1, 3, 762);
        await mtsNft.safeMint(deployer.address, 6, 1, 5, 1, 3, 9, 3, 556);
        expect(await mtsNft.balanceOf(deployer.address)).to.be.equal(3);
    });

    it("List ownership by address", async function () {
      await mtsNft.safeMint(deployer.address, 1, 1, 3, 4, 4, 5, 6, 30);
      await mtsNft.safeMint(deployer.address, 2, 1, 5, 8, 6, 1, 3, 762);
      await mtsNft.safeMint(deployer.address, 6, 1, 5, 1, 3, 9, 3, 556);
        console.log(await mtsNft.ownedBy(deployer.address));
        const ownership1 = await mtsNft.ownedBy(deployer.address)
        const owning = await mtsNft.balanceOf(deployer.address)
        for (let i = 0; i < owning; i ++ ){
            console.log(ownership1[i].toString());
        }
    });

    it("Setup Box and Test Open", async function () {
      console.log('Before setup');
        await metaBox.setupBox(0, [30, 40, 1, 10, 10, 10, 1, 3, [1,2], [500, 500]]);
        console.log('After setup');
        await metaBox.mint(user1.address, 0, 10, "0x");
        for (let i = 0; i < 10; i ++) {
            await metaBox.connect(user1).openBox(0);
        }
        console.log(await mtsNft.ownedBy(user1.address));
        const ownership1 = await mtsNft.ownedBy(user1.address)
        const owning = await mtsNft.balanceOf(user1.address)
        for (let i = 0; i < owning; i ++ ){
            console.log(ownership1[i].toString());
        }
    });
  });
});