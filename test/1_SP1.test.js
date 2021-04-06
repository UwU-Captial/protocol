const { artifacts, contract, assert } = require("hardhat");
const { pack, keccak256 } = require("@ethersproject/solidity");
const { getCreate2Address } = require("@ethersproject/address");

const { BN, time } = require("@openzeppelin/test-helpers");
const expectEvent = require("@openzeppelin/test-helpers/src/expectEvent");

const UwU = artifacts.require("UwU");
const UwUPolicy = artifacts.require("UwUPolicy");
const Orchestrator = artifacts.require("Orchestrator");
const MiningPool = artifacts.require("MiningPool");
const BridgePool = artifacts.require("BridgePool");
const Seed = artifacts.require("Seed");
const Oracle = artifacts.require("Oracle");
const Token = artifacts.require("Token");
const SP1 = artifacts.require("SP1");
const IPancakeRouter = artifacts.require("IPancakeRouter02");

contract("SP1", (accounts) => {
  let owner = accounts[0];
  let router;
  let orchestrator;
  let busd;
  let uwuPolicy;
  let debaseBridgePool;
  let debaseEthBridgePool;
  let uwuMiningPool;
  let seed;
  let sp1;
  let stakeToken;
  let multiSigRewardAddress = accounts[1];
  let treasury = accounts[2];
  let fee = 30;
  let uwuLiquidity = "100000000000000000000";
  let busdLiquidity = "10000000000000000000000";
  let uwuBusdLp;
  let oracle;

  before("Test", async () => {
    router = await IPancakeRouter.at(
      "0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F"
    );
    orchestrator = await Orchestrator.new({ from: owner });
    uwuPolicy = await UwUPolicy.new({ from: owner });
    busd = await Token.new("BUSD", "BUSD", { from: owner });
    uwu = await UwU.new({ from: owner });

    debaseBridgePool = await BridgePool.new({ from: owner });
    debaseEthBridgePool = await BridgePool.new({ from: owner });
    uwuMiningPool = await MiningPool.new({ from: owner });
    seed = await Seed.new({ from: owner });
    await orchestrator.initialize(
      uwu.address,
      uwuPolicy.address,
      debaseBridgePool.address,
      debaseEthBridgePool.address,
      uwuMiningPool.address,
      seed.address,
      "900000000000000000000000",
      0
    );

    await uwu.initialize(
      debaseBridgePool.address,
      0,
      debaseEthBridgePool.address,
      0,
      uwuMiningPool.address,
      0,
      owner,
      5000,
      uwuPolicy.address,
      5000
    );

    await busd.approve(router.address, busdLiquidity, { from: owner });
    await uwu.approve(router.address, uwuLiquidity, { from: owner });
    await router.addLiquidity(
      busd.address,
      uwu.address,
      busdLiquidity,
      uwuLiquidity,
      0,
      0,
      owner,
      2000000000
    );

    let token0 =
      busd.address.toLowerCase() > uwu.address.toLowerCase()
        ? uwu.address
        : busd.address;
    const uwuBusdLpAddress = getCreate2Address(
      "0xBCfCcbde45cE874adCB698cC183deBcF17952812",
      keccak256(
        ["bytes"],
        [
          pack(
            ["address", "address"],
            [token0, token0 === busd.address ? uwu.address : busd.address]
          ),
        ]
      ),
      "0xd0d4c4cd0848c93cb4fd1f498d7013ee6bfb25783ea21593d5834f5d250ece66"
    );

    uwuBusdLp = await Token.at(uwuBusdLpAddress);

    oracle = await Oracle.new(
      uwu.address,
      uwuBusdLp.address,
      uwuPolicy.address
    );
    await uwuPolicy.initialize(uwu.address, orchestrator.address);
    await uwuPolicy.setOracle(oracle.address, {
      from: owner,
    });
    stakeToken = await Token.new("TestStake", "TST", { from: owner });
    sp1 = await SP1.new(
      uwu.address,
      stakeToken.address,
      uwuPolicy.address,
      "100000000000000000", // 10%
      194800,
      0,
      0,
      multiSigRewardAddress,
      false,
      0,
      false,
      0,
      treasury,
      fee,
      {
        from: owner,
      }
    );
    await uwuPolicy.addNewStabilizerPool(sp1.address, {
      from: owner,
    });
    await uwuPolicy.setStabilizerPoolEnabled(0, true, {
      from: owner,
    });
  });

  describe("Buy BUSD in every reward distribution", () => {
    it("setFee", async () => {
      const newFee = "40";
      const res = await sp1.setFee(newFee);
      expectEvent(res, "LogSetFeePercentage", {
        fee_: newFee,
      });
      assert.equal((await sp1.fee()).toString(), newFee);
      await sp1.setFee(fee);
    });

    it("setTreasury", async () => {
      const newTreasury = accounts[3];
      const res = await sp1.setTreasury(newTreasury);
      expectEvent(res, "LogSetTreasuryAddress", {
        treasury_: newTreasury,
      });
      assert.equal((await sp1.treasury()).toString(), newTreasury);
      await sp1.setTreasury(treasury);
    });

    it("setUwUBusdPath", async () => {
      await sp1.setUwUBusdPath([uwu.address, busd.address]);
      assert.equal(await sp1.uwuBusdPath(0), uwu.address);
      assert.equal(await sp1.uwuBusdPath(1), busd.address);
    });

    it("Automatically buy BUSD and send to treasury", async () => {
      const currentTime = Number((await time.latest()).toString());
      if (currentTime % (24 * 3600) < 72000) {
        await time.increase(72100 - (currentTime % (24 * 3600)));
      }
      await orchestrator.rebase();
      assert.equal(await busd.balanceOf(treasury), "9676793794440853264382");
    });
  });
});
