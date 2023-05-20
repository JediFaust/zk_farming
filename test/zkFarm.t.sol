// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/zkFarm.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract ZKFarmTestCore is Test {
    ZKFarming public farming;
    uint224 public constant MILLION = 1_000_000 * 10 ** 18;
    uint224 public constant HUNDRED_K = 100_000 * 10 ** 18;
    uint224 public constant TEN_K = 10_000 * 10 ** 18;

    Token public tokenA = new Token("RewardToken", "RWT");
    Token public tokenB = new Token("DepositToken", "DPT");

    address immutable public admin = address(this);
    address immutable public depositer = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    function setUp() public {
        farming = new ZKFarming(address(tokenA), address(tokenB), 10, 1 days);

        // Transfer 100k B tokens to the depositer
        tokenB.transfer(depositer, HUNDRED_K);
    }

    event Deposited(address indexed user, uint256 amount, uint256 indexed time);
    event Claimed(address indexed user, uint256 reward, uint256 indexed time);
    event RewardPercentChanged(uint256 oldPercent, uint256 newPercent, uint256 indexed time);
    event RewardRateChanged(uint256 oldRate, uint256 newRate, uint256 indexed time);
    event RewardFilled(uint256 amount, uint256 indexed time);
}

contract Initial is ZKFarmTestCore {
    function testInitial() external {
        assertEq(farming.admin(), admin);
        assertEq(farming.rewardPercent(), 10);
        assertEq(farming.rewardRate(), 1 days);
        assertEq(farming.MAXIMUM_REWARD_PERCENT(), 1000);

        assertEq(address(farming.rewardToken()), address(tokenA));
        assertEq(address(farming.depositToken()), address(tokenB));
    }

    function testInitialBalances() external {
        assertEq(tokenA.balanceOf(admin), MILLION);
        assertEq(tokenB.balanceOf(admin), MILLION - HUNDRED_K);

        assertEq(tokenB.balanceOf(depositer), HUNDRED_K);
    }
}

contract Deposit is ZKFarmTestCore {
    function testDeposit() external {
        vm.startPrank(depositer);
        tokenB.approve(address(farming), TEN_K);
        assertTrue(farming.deposit(TEN_K));

        assertEq(tokenB.balanceOf(address(farming)), TEN_K);
        assertEq(tokenB.balanceOf(depositer), HUNDRED_K - TEN_K);

        tokenB.approve(address(farming), TEN_K);
        vm.expectRevert("FARM: Already Deposited");
        farming.deposit(TEN_K);
    }

    function testDepositWithZeroAmount() external {
        vm.startPrank(depositer);
        vm.expectRevert("FARM: Zero Amount");
        farming.deposit(0);
    }
}

contract AdminFunctions is ZKFarmTestCore {
    function testRewardFilment() external {
        assertEq(tokenA.balanceOf(address(farming)), 0);

        tokenA.approve(address(farming), HUNDRED_K);

        vm.expectEmit(address(farming));
        emit RewardFilled(HUNDRED_K, block.timestamp);
        farming.fillRewards(HUNDRED_K);

        assertEq(tokenA.balanceOf(address(farming)), HUNDRED_K);
    }

    function testZeroRewardFilment() external {
        vm.expectRevert("FARM: Zero Filment");
        farming.fillRewards(0);
    }

    function testRewardPercentChange() external {
        assertEq(farming.rewardPercent(), 10);

        vm.expectEmit(address(farming));
        emit RewardPercentChanged(10, 20, block.timestamp);
        farming.setRewardPercent(20);

        assertEq(farming.rewardPercent(), 20);
    }

    function testZeroRewardPercent() external {
        vm.expectRevert("FARM: Invalid Reward Percent");
        farming.setRewardPercent(0);
    }

    function testRewardRateChange() external {
        assertEq(farming.rewardRate(), 1 days);

        vm.expectEmit(address(farming));
        emit RewardRateChanged(1 days, 2 days, block.timestamp);
        farming.setRewardRate(2 days);

        assertEq(farming.rewardRate(), 2 days);
    }

    function testZeroRewardRate() external {
        vm.expectRevert("FARM: Zero Reward Rate");
        farming.setRewardRate(0);
    }

    function testRewardFilmentAccess() external {
        vm.startPrank(depositer);
        vm.expectRevert("FARM: Admin Only");
        farming.fillRewards(HUNDRED_K);
    }

    function testRewardPercentChangeAccess() external {
        vm.startPrank(depositer);
        vm.expectRevert("FARM: Admin Only");
        farming.setRewardPercent(20);
    }

    function testRewardRateChangeAccess() external {
        vm.startPrank(depositer);
        vm.expectRevert("FARM: Admin Only");
        farming.setRewardRate(2 days);
    }
}

contract Claim is ZKFarmTestCore {
    function testClaim() external {
        tokenA.approve(address(farming), HUNDRED_K);
        farming.fillRewards(HUNDRED_K);

        vm.startPrank(depositer);
        tokenB.approve(address(farming), TEN_K);
        assertTrue(farming.deposit(TEN_K));

        assertEq(tokenB.balanceOf(address(farming)), TEN_K);
        assertEq(tokenB.balanceOf(depositer), HUNDRED_K - TEN_K);

        vm.warp(block.timestamp + 2 days);

        uint expectedReward = 200 * 10 ** 18;

        vm.expectEmit(address(farming));
        emit Claimed(depositer, expectedReward, block.timestamp);
        farming.claim();

        assertEq(tokenB.balanceOf(address(farming)), 0);
        assertEq(tokenB.balanceOf(depositer), HUNDRED_K);
        assertEq(tokenA.balanceOf(depositer), expectedReward);
    }

    function testRewardClaim() external {
        uint expectReward = 3_000 * 10 ** 18;
        tokenA.approve(address(farming), expectReward);
        tokenA.transfer(address(farming), expectReward);

        vm.startPrank(depositer);
        tokenB.approve(address(farming), HUNDRED_K);
        farming.deposit(HUNDRED_K);

        vm.warp(block.timestamp + 3 days);
        farming.claim();
        assertEq(tokenA.balanceOf(depositer), expectReward);
    }

    function testZeroRewardClaim() external {
        vm.startPrank(depositer);
        tokenB.approve(address(farming), TEN_K);
        farming.deposit(TEN_K);
        farming.claim();
        assertEq(tokenA.balanceOf(depositer), 0);
    }

    function testClaimWithoutDeposit() external {
        vm.expectRevert("FARM: No deposit");
        farming.claim();
    }
}