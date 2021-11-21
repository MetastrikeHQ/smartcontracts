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
  let uniFactory;
  let uniRouter;
  let mtsToken;
  let owner;
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
    [owner, user1, user2, user3, user4, user5, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    wETH = await WETHContract.deploy();
    uniFactory = await FactoryContract.deploy(owner.address);
    // console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    uniRouter = await RouterContract.deploy(uniFactory.address, wETH.address);
    mtsToken = await MtsTokenContract.deploy();
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    it("Deployment with dependencies!", async function () {
      console.log(await uniFactory.INIT_CODE_PAIR_HASH())
    });

    it("Deployment Token & Create A Pair in Pancake", async function () {
        await uniFactory.createPair(wETH.address, mtsToken.address)
        let pairAddress = await uniFactory.getPair(wETH.address, mtsToken.address);
        console.log(pairAddress);
    });

    it("Test 2 Phase Ownership", async function () {
      expect(await mtsToken.owner()).to.be.equal(owner.address);
      await mtsToken.transferOwnership(user1.address);
      expect(await mtsToken.owner()).to.be.equal(owner.address);
      await expect(mtsToken.connect(user1).pause()).to.be.reverted;
      await mtsToken.connect(user1).acceptOwnership();
      await mtsToken.connect(user1).pause();
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await mtsToken.balanceOf(owner.address);
      expect(await mtsToken.totalSupply()).to.equal(ownerBalance);
    });

    it("Test blacklist", async function () {
      await mtsToken.blackList(user1.address, true);
      await expect(mtsToken.transfer(user1.address, "10000")).to.be.revertedWith("MTS: This recipient was blacklisted!");

      await mtsToken.transfer(user2.address, "100000000");
      await mtsToken.connect(user2).transfer(owner.address, "10000");
      await mtsToken.blackList(user2.address, true);
      await expect(mtsToken.connect(user2).transfer(owner.address, "10000")).to.be.revertedWith("MTS: This sender was blacklisted!");
    });

    it("Tried add LP", async function () {
      let tokenAmountToAddLP = BigNumber.from(4500000).mul(BigNumber.from(10).pow(18))
      let bnbAmountToAddLP = BigNumber.from(223).mul(BigNumber.from(10).pow(17))
      await mtsToken.approve(uniRouter.address, tokenAmountToAddLP);
      await uniRouter.addLiquidityETH(mtsToken.address, tokenAmountToAddLP, 0, 0, owner.address, 2629735000, { value:  bnbAmountToAddLP});
    });

    it("Add Liquidity and setup tried to buy from bigger than allownced", async function () {
      let tokenAmountToAddLP = BigNumber.from(4500000).mul(BigNumber.from(10).pow(18))
      let bnbAmountToAddLP = BigNumber.from(223).mul(BigNumber.from(10).pow(17))
      await uniFactory.createPair(wETH.address, mtsToken.address)
      let pairAddress = await uniFactory.getPair(wETH.address, mtsToken.address);
      await mtsToken.approve(uniRouter.address, tokenAmountToAddLP);
      let currentlyTime = Math.floor(Date.now() / 1000)

      await mtsToken.setupListing(pairAddress, ethers.utils.parseEther('2000'), 0, currentlyTime  + 36000);

      await uniRouter.addLiquidityETH(mtsToken.address, tokenAmountToAddLP, 0, 0, owner.address, 2629735000, { value:  bnbAmountToAddLP});
      let tokenAmountToBuy = tokenAmountToAddLP.div(BigNumber.from(50)) //(2%)
      //before setup then can not buy.
      let bigAmount = ethers.utils.parseEther('2001')
      let goodAmount = ethers.utils.parseEther('2000')
      await expect(uniRouter.swapETHForExactTokens(bigAmount, [wETH.address, mtsToken.address], owner.address, 2629735000,  { value:  ethers.utils.parseEther('2')})).to.be.reverted;
      await mtsToken.setupListing(pairAddress, ethers.utils.parseEther('2000'), currentlyTime, currentlyTime  + 3600);
      await network.provider.send("evm_increaseTime", [20])
      await network.provider.send("evm_mine")
      await uniRouter.swapETHForExactTokens(goodAmount, [wETH.address, mtsToken.address], owner.address, 2629735000, { value:  ethers.utils.parseEther('2')})
      await expect(uniRouter.swapETHForExactTokens(bigAmount, [wETH.address, mtsToken.address], owner.address, 2629735000,  { value:  ethers.utils.parseEther('2')})).to.be.reverted;
    });
  });
});