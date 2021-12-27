const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const hre = require('hardhat')

describe("Meta Locked Staking contract", function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let MtsTokenContract;
  let MttTokenContract;
  let MetaLockedStakingContract;

  let mtsToken;
  let mttToken;
  let metaStaking;

  let owner;
  let user1;
  let user2;
  let user3;
  let addrs;

  let nowInSec;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {

    // Get the ContractFactory and Signers here.
    MetaLockedStakingContract = await ethers.getContractFactory("MetaLockedStaking");
    //MetaStrike Token
    MtsTokenContract = await ethers.getContractFactory("MetaStrike");
    //MetaStrikeMTT
    MttTokenContract = await ethers.getContractFactory("MetaStrikeMTT");
    [owner, user1, user2, user3, user4, user5, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    mtsToken = await MtsTokenContract.deploy();
    mttToken = await MttTokenContract.deploy();
    // constructor(
    //     IERC20Ext _stakedToken,
    //     IERC20Ext _rewardToken,
    //     uint256 _rewardPerBlock,
    //     uint256 _startBlock,
    //     uint256 _bonusEndBlock,
    //     uint256 _lockDate,
    //     uint256 _withdrawFeePermile
    //     ) 

    nowInSec = Math.round(new Date().getTime() / 1000);
    metaStaking = await MetaLockedStakingContract.deploy(mtsToken.address, mttToken.address, 10, 0 , 0, nowInSec + 3000, 100);
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    it("Deposit and withdraw before lockDate will be fined!", async function () {
        await mtsToken.mint(user1.address, "100000");
        await mtsToken.mint(user2.address, "100000");
        await mttToken.mint(owner.address, "100000000000");
        await mttToken.transfer(metaStaking.address, "100000");
        
        await mtsToken.connect(user1).approve(metaStaking.address, "110000000000000000000");
        await mtsToken.connect(user2).approve(metaStaking.address, "110000000000000000000");
        await metaStaking.connect(user1).deposit("10000");
        await mttToken.mint(owner.address, "1");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(10);
        await metaStaking.connect(user2).deposit("10000");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(20);
        await mttToken.mint(owner.address, "1");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(25);
        expect(await metaStaking.pendingReward(user2.address)).to.be.equal(5);
        await metaStaking.connect(user1).withdraw("10000");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(0);
        expect(await mtsToken.balanceOf(user1.address)).to.be.equal(99000);

        // await network.provider.send("evm_increaseTime", [400])
        // await network.provider.send("evm_mine")

        // await network.provider.send("evm_increaseTime", [2000])
        // await network.provider.send("evm_mine")
    });


    it("Withdraw after lockDate will be ok!", async function () {
        await mtsToken.mint(user1.address, "100000");
        await mtsToken.mint(user2.address, "100000");
        await mttToken.mint(owner.address, "100000000000");
        await mttToken.transfer(metaStaking.address, "100000");
        
        await mtsToken.connect(user1).approve(metaStaking.address, "110000000000000000000");
        await mtsToken.connect(user2).approve(metaStaking.address, "110000000000000000000");
        await metaStaking.connect(user1).deposit("10000");
        await mttToken.mint(owner.address, "1");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(10);
        await metaStaking.connect(user2).deposit("10000");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(20);
        await mttToken.mint(owner.address, "1");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(25);
        expect(await metaStaking.pendingReward(user2.address)).to.be.equal(5);
        await expect(metaStaking.connect(user1).claimReward()).to.be.reverted;
        await network.provider.send("evm_increaseTime", [4000])
        await network.provider.send("evm_mine")
        await metaStaking.stopReward();
        // await metaStaking.connect(user1).withdraw("10000");
        // expect(await mtsToken.balanceOf(user1.address)).to.be.equal(100000);
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(40);
        await metaStaking.connect(user1).claimReward()
        expect(await mttToken.balanceOf(user1.address)).to.be.equal(40);
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(0);
        await mttToken.mint(owner.address, "1");
        await mttToken.mint(owner.address, "1");
        await mttToken.mint(owner.address, "1");
        expect(await metaStaking.pendingReward(user1.address)).to.be.equal(0);

        // await network.provider.send("evm_increaseTime", [2000])
        // await network.provider.send("evm_mine")
    });
  });
});