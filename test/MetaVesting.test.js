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
  let MetaVestingContract;

  let mtsToken;
  let metaVesting;

  let owner;
  let user1;
  let user2;
  let user3;
  let addrs;

  let now;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {

    // Get the ContractFactory and Signers here.
    //MetaVestingContract
    MetaVestingContract = await ethers.getContractFactory("MetaVesting");
    //MetaStrike Token
    MtsTokenContract = await ethers.getContractFactory("MetaStrike");
    [owner, user1, user2, user3, user4, user5, ...addrs] = await ethers.getSigners();

    // To deploy our contract, we just have to call Token.deploy() and await
    // for it to be deployed(), which happens onces its transaction has been
    // mined.
    mtsToken = await MtsTokenContract.deploy();
    now = Math.round(new Date().getTime() / 1000);

    metaVesting = await MetaVestingContract.deploy(mtsToken.address, now);
  });

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {

    it("tge 15%, cliff 200s, linear 2000 sec", async function () {
        // function setupVestingStrategy(uint256 _id, uint256 _tgePercent, uint256 _cliffSecs, uint256 _linearSecs)
        await metaVesting.setupVestingStrategy(0, 150, 200, 2000);
        await metaVesting.setupVestingUser(0, 100000, [user1.address]);
        await mtsToken.transfer(metaVesting.address, 1000000);
        let user1Info = await metaVesting.userToVesting(user1.address, 0);
        console.log(user1Info.amount.toString(), user1Info.claimed.toString(), user1Info.lastClaim.toString());
        let user1Claimable = await metaVesting.claimable(user1.address, 0);
        console.log('User 1 Claimable: ', user1Claimable.toString());
        expect(user1Claimable).to.be.equal(15000);
        await network.provider.send("evm_increaseTime", [400])
        await network.provider.send("evm_mine")
        user1Claimable = await metaVesting.claimable(user1.address, 0);
        console.log('User 1 Claimable: ', user1Claimable.toString());
        expect(user1Claimable).to.be.gt(30000);
        await metaVesting.connect(user1).claim(0);
        await network.provider.send("evm_increaseTime", [2000])
        await network.provider.send("evm_mine")
        await metaVesting.connect(user1).claim(0);
        let user1Bl = await mtsToken.balanceOf(user1.address);
        console.log("User 1 Balance: ", user1Bl.toString());
        expect(user1Bl).to.be.equal(100000);
        user1Claimable = await metaVesting.claimable(user1.address, 0);
        console.log('User 1 Claimable: ', user1Claimable.toString());
        expect(user1Claimable).to.be.equal(0);
        await expect(metaVesting.connect(user1).claim(0)).to.be.reverted;
    });
  });
});