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

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await mtsToken.balanceOf(owner.address);
      expect(await mtsToken.totalSupply()).to.equal(ownerBalance);
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
      await mtsToken.approve(uniRouter.address, tokenAmountToAddLP);
      await uniRouter.addLiquidityETH(mtsToken.address, tokenAmountToAddLP, 0, 0, owner.address, 2629735000, { value:  bnbAmountToAddLP});
      let tokenAmountToBuy = tokenAmountToAddLP.div(BigNumber.from(50)) //(2%)
      //before setup then can not buy.
      await expect(uniRouter.swapETHForExactTokens(tokenAmountToBuy, [wETH.address, mtsToken.address], owner.address, 2629735000)).to.be.reverted;
      let pairAddress = await uniFactory.getPair(wETH.address, mtsToken.address);
      expect(await mtsToken.setupListing(pairAddress, ethers.utils.parseEther('2000'), 1637160360))
      let bigAmount = ethers.utils.parseEther('2001')
      let goodAmount = ethers.utils.parseEther('2000')
      await uniRouter.swapETHForExactTokens(goodAmount, [wETH.address, mtsToken.address], owner.address, 2629735000, { value:  ethers.utils.parseEther('2')})
      await uniRouter.swapETHForExactTokens(bigAmount, [wETH.address, mtsToken.address], owner.address, 2629735000, { value:  ethers.utils.parseEther('2')})
    });
  });
});