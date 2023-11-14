// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../SubAccount.sol";

contract TestSubAccount is Test {
    using SubAccount for bytes32;
    using SubAccount for address;

    function test_toAccount() public {
        address v = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
        assertEq(v.toAccount(1234), hex"0000000000000000000004d24838b106fce9647bdf1e7877bf73ce8b0bad5f97");
    }

    function test_fromAccount() public {
        bytes32 v = hex"0000000000000000000004d24838b106fce9647bdf1e7877bf73ce8b0bad5f97";
        assertEq(v.toSubId(), 1234);
        assertEq(v.toAddress(), 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97);
    }
}
