// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import "../OmniPool.sol";

contract CheckAccountPoolMarkets is Script {
    using SubAccount for address;

    function run() external {
        vm.startBroadcast();
        address user = 0x275870E7BeC9504f50Db97B6bE4EB34Ce0b12D1D;
        bytes32 acc37 = user.toAccount(39);
        OmniPool pool = OmniPool(0x6457180bac592Cd4d032B246D183b5eC09DD31f5);
        (uint8 mode, address isolated, uint32 threshold) = pool.accountInfos(acc37);
        IOmniPool.AccountInfo memory info = IOmniPool.AccountInfo(mode, isolated, threshold);
        console.log(mode, isolated, threshold);
        address[] memory markets = pool.getAccountPoolMarkets(acc37, info);
        for (uint256 i = 0; i < markets.length; i++) {
            console.log(i, markets[i]);
        }
    }
}