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
  let FactoryContract;
  let RouterContract;
  let MetaStrikeNFTContract;
  let uniFactory;
  let uniRouter;
  let mtsToken;
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
    //UniswapV2Factory
    FactoryContract = await ethers.getContractFactory("UniswapV2Factory");
    //WETH9
    WETHContract = await ethers.getContractFactory("WETH9");
    //UniswapV2Router01
    RouterContract = await ethers.getContractFactory("UniswapV2Router02")
    //MetaStrike Token
    MtsTokenContract = await ethers.getContractFactory("MetaStrike");
    [deployer, user1, user2, user3, user4, user5, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    wETH = await WETHContract.deploy();
    uniFactory = await FactoryContract.deploy(deployer.address);
    // console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    uniRouter = await RouterContract.deploy(uniFactory.address, wETH.address);
    mtsToken = await MtsTokenContract.deploy();


    MetaStrikeNFTContract = await hre.ethers.getContractFactory('MetaStrikeNFT')
    mtsNft = await MetaStrikeNFTContract.deploy()
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    // it("Deployment with dependencies!", async function () {
    //   console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    // });

    it("Safe Mint Gun", async function () {
        await mtsNft.safeMint(deployer.address, 1, 1, 30);
        await mtsNft.safeMint(deployer.address, 2, 1, 762);
        await mtsNft.safeMint(deployer.address, 6, 1, 556);
        expect(await mtsNft.balanceOf(deployer.address)).to.be.equal(3);
    });

    it("List ownership by address", async function () {
        await mtsNft.safeMint(deployer.address, 1, 1, 30);
        await mtsNft.safeMint(deployer.address, 2, 1, 762);
        await mtsNft.safeMint(deployer.address, 6, 1, 556);
        console.log(await mtsNft.ownedBy(deployer.address));
        const ownership1 = await mtsNft.ownedBy(deployer.address)
        const owning = await mtsNft.balanceOf(deployer.address)
        for (let i = 0; i < owning; i ++ ){
            console.log(ownership1[i].toString());
        }
    });
  });
});