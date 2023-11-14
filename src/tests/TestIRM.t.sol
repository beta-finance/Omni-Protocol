// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../IRM.sol";
import "../interfaces/IIRM.sol";

contract TestIRM is Test {
    IRM public irm;
    address public constant MARKET = 0x4838B106FCe9647Bdf1E7877BF73cE8B0BAD5f97;
    address alice = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;

    function setUp() public {
        irm = new IRM();
        irm.initialize(address(this));
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](1);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9); // 90% kink, 1% start, 3.5% mid, 63.5% end
        uint8[] memory tranches = new uint8[](1);
        tranches[0] = 0;
        irm.setIRMForMarket(MARKET, tranches, configs);
    }

    function test_Initialize() public {
        assertEq(
            irm.hasRole(irm.DEFAULT_ADMIN_ROLE(), address(this)), true, "Deployer should have the DEFAULT_ADMIN_ROLE"
        );
    }

    function test_GetInterestRateZeroUtilization() public {
        uint256 interestRate = irm.getInterestRate(MARKET, 0, 1000, 0);
        assertEq(interestRate, 0.01e9, "Interest rate should be 0 at 0% utilization");

        uint256 interestRateDepositZero = irm.getInterestRate(MARKET, 0, 0, 0);
        assertEq(interestRateDepositZero, 0.01e9, "Interest rate should be 0 at 0% utilization with 0 deposit");
    }

    function test_GetInterestRateBeforeKink() public {
        uint256 interestRate = irm.getInterestRate(MARKET, 0, 1000, 400);
        assertApproxEqRel(
            interestRate, 0.02111e9, 0.001e18, "Interest rate should be ~2.11% within 0.1% precision at 40% utilization"
        );
    }

    function test_GetInterestRateAtKink() public {
        uint256 interestRate = irm.getInterestRate(MARKET, 0, 1000, 900);
        assertEq(interestRate, 0.035e9, "Interest rate should be 3.5% at 90% utilization");
    }

    function test_GetInterestRateAfterKink() public {
        uint256 interestRate = irm.getInterestRate(MARKET, 0, 1000, 950);
        assertEq(interestRate, 0.335e9, "Interest rate should be 33.5% at 95% utilization");
    }

    function test_GetInterestRateMaxUtilization() public {
        uint256 interestRate = irm.getInterestRate(MARKET, 0, 1000, 1000); // 200% utilization exceeds the kink
        assertEq(interestRate, 0.635e9, "Interest rate should be 63.5% at 100% utilization");

        uint256 interestRateBadDebt = irm.getInterestRate(MARKET, 0, 1000, 1001); // Slighlty more borrows than deposits in case of potential rounding error
        assertEq(interestRateBadDebt, 0.635e9, "Interest rate should be 63.5% at utilization above 100%");
    }

    function test_SetIRMForMarket() public {
        address market1 = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](2);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        uint8[] memory tranches = new uint8[](2);
        tranches[0] = 0;
        tranches[1] = 1;
        irm.setIRMForMarket(market1, tranches, configs);
        (uint64 kink0, uint64 start0, uint64 mid0, uint64 end0) = irm.marketIRMConfigs(market1, 0);
        assertEq(kink0, 0.9e9, "Kink should be 90%");
        assertEq(start0, 0.01e9, "Start should be 1%");
        assertEq(mid0, 0.035e9, "Mid should be 3.5%");
        assertEq(end0, 0.635e9, "End should be 63.5%");

        (uint64 kink1, uint64 start1, uint64 mid1, uint64 end1) = irm.marketIRMConfigs(market1, 1);
        assertEq(kink1, 0.85e9, "Kink should be 85%");
        assertEq(start1, 0.02e9, "Start should be 2%");
        assertEq(mid1, 0.08e9, "Mid should be 8%");
        assertEq(end1, 1e9, "End should be 100%");
    }

    function test_RevertSetIRMBadRole() public {
        vm.startPrank(alice);
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](1);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        uint8[] memory tranches = new uint8[](1);
        tranches[0] = 0;
        vm.expectRevert(
            "AccessControl: account 0xd8da6bf26964af9d7eed9e03e53415d37aa96045 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        irm.setIRMForMarket(MARKET, tranches, configs);
    }

    function test_RevertNoConfigGetInterest() public {
        // Empty tranche
        uint8 emptyTranche = 1;
        vm.expectRevert("IRM::_getInterestRateLinear: Interest config not set.");
        irm.getInterestRate(MARKET, emptyTranche, 1000, 500);

        // Empty market
        address emptyMarket = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
        vm.expectRevert("IRM::_getInterestRateLinear: Interest config not set.");
        irm.getInterestRate(emptyMarket, 0, 1000, 500);
    }

    function test_RevertLengthMismatchSetIRM() public {
        address market1 = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](2);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        uint8[] memory tranches = new uint8[](1);
        tranches[0] = 0;
        vm.expectRevert("IRM::setIRMForMarket: Tranches and configs length mismatch.");
        irm.setIRMForMarket(market1, tranches, configs);
    }

    function test_RevertBadKinkSetIRM() public {
        address market1 = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](1);
        configs[0] = IIRM.IRMConfig(0, 0.01e9, 0.035e9, 0.635e9);
        uint8[] memory tranches = new uint8[](1);
        tranches[0] = 0;

        // Kink = 0%
        vm.expectRevert("IRM::setIRMForMarket: Bad kink value.");
        irm.setIRMForMarket(market1, tranches, configs);

        // Kink = 100%
        configs[0] = IIRM.IRMConfig(1e9, 0.01e9, 0.035e9, 0.635e9);
        vm.expectRevert("IRM::setIRMForMarket: Bad kink value.");
        irm.setIRMForMarket(market1, tranches, configs);
    }

    function test_RevertInvalidInterestSetIRM() public {
        address market1 = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](1);
        uint8[] memory tranches = new uint8[](1);
        tranches[0] = 0;

        // Start > Mid
        configs[0] = IIRM.IRMConfig(0.9e9, 0.035e9, 0.01e9, 0.635e9);
        vm.expectRevert("IRM::setIRMForMarket: Bad interest value.");
        irm.setIRMForMarket(market1, tranches, configs);

        // Mid > End
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.635e9, 0.035e9);
        vm.expectRevert("IRM::setIRMForMarket: Bad interest value.");
        irm.setIRMForMarket(market1, tranches, configs);

        // End > MAX_INTEREST_RATE
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 10.001e9);
        vm.expectRevert("IRM::setIRMForMarket: Bad interest value.");
        irm.setIRMForMarket(market1, tranches, configs);
    }
}
