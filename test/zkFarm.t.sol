// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/zkFarm.sol";

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CounterTest is Test {
    ZKFarming public farming;
    uint32 time;

    function setUp() public {
        farming = new ZKFarming();
        // farming.setNumber(0);
    }

    function testMaxUint() external view {
    }

}
