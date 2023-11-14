// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "../OmniOracle.sol";
import "../interfaces/IOmniOracle.sol";

/**
 * @title TestOmniOracle
 * @notice Unit tests incomplete, but should be sufficient to test the core functionality of the OmniOracle contract.
 */
contract TestOmniOracle is Test {
    OmniOracle oracle;
    address public constant MARKET = 0x4838b106FcE9647BdF1E7877Bf73Ce8b0baD5f99;
    address public constant MOCK_BAND = 0x72AFAECF99C9d9C8215fF44C77B94B99C28741e8;
    address public constant MOCK_CHAINLINK = 0x6Df09E975c830ECae5bd4eD9d90f3A95a4f88012;
    address public constant MOCK_OTHER = 0xAE48c91dF1fE419994FFDa27da09D5aC69c30f55;

    function setUp() public {
        oracle = new OmniOracle();
        oracle.initialize(address(this));
    }

    function test_Initialize() public {
        assertEq(
            oracle.hasRole(oracle.DEFAULT_ADMIN_ROLE(), address(this)),
            true,
            "Deployer should have the DEFAULT_ADMIN_ROLE"
        );
    }

    function test_SetOracleConfig() public {
        oracle.setOracleConfig(
            MARKET, IOmniOracle.OracleConfig(MOCK_BAND, IOmniOracle.Provider.Band, 3 hours, 5 hours, 18), "Test"
        );
        (address oracleAddress, IOmniOracle.Provider provider, uint32 delay, uint32 delayQuote, uint8 decimals) =
            oracle.oracleConfigs(MARKET);
        assertEq(oracleAddress, MOCK_BAND, "Oracle address should be set to MOCK_BAND");
        assertEq(uint256(provider), uint256(IOmniOracle.Provider.Band), "Provider should be set to Band");
        assertEq(delay, 3 hours, "Delay should be set to 3 hours");
        assertEq(delayQuote, 5 hours, "Delay should be set to 5 hours");
        assertEq(decimals, 18, "Decimals should be set to 18");
    }

    function test_RemoveOracleConfig() public {
        test_SetOracleConfig();
        oracle.removeOracleConfig(MARKET);
        (address oracleAddress, IOmniOracle.Provider provider, uint32 delay, uint32 delayQuote, uint8 decimals) =
            oracle.oracleConfigs(MARKET);
        assertEq(oracleAddress, address(0), "Oracle address should be set to zero address");
        assertEq(uint256(provider), uint256(IOmniOracle.Provider.Invalid), "Provider should be set to Invalid");
        assertEq(delay, 0, "Delay should be set to zero");
        assertEq(delayQuote, 0, "Delay quote should be set to zero");
        assertEq(decimals, 0, "Decimals should be set to zero");
    }

    function test_RevertGetPrice() public {
        vm.expectRevert("OmniOracle::getPrice: Invalid provider.");
        oracle.getPrice(MARKET);
    }

    function test_RevertZeroSetOracle() public {
        IOmniOracle.OracleConfig memory config =
            IOmniOracle.OracleConfig(address(0), IOmniOracle.Provider(1), 1 hours, 5 hours, 18);
        vm.expectRevert("OmniOracle::setOracleConfig: Can never use zero address.");
        oracle.setOracleConfig(MARKET, config, "TEST");

        IOmniOracle.OracleConfig memory config2 =
            IOmniOracle.OracleConfig(MOCK_BAND, IOmniOracle.Provider(1), 1 hours, 5 hours, 18);
        oracle.setOracleConfig(MARKET, config2, "TEST");
        vm.expectRevert("OmniOracle::setOracleConfig: Can never use zero address.");
        oracle.setOracleConfig(address(0), config2, "TEST");

        IOmniOracle.OracleConfig memory config3 =
            IOmniOracle.OracleConfig(MOCK_BAND, IOmniOracle.Provider(1), 0, 5 hours, 18);
        vm.expectRevert("OmniOracle::setOracleConfig: Invalid delay.");
        oracle.setOracleConfig(MARKET, config3, "TEST");

        IOmniOracle.OracleConfig memory config4 =
            IOmniOracle.OracleConfig(MOCK_BAND, IOmniOracle.Provider(1), 5 hours, 0, 18);
        vm.expectRevert("OmniOracle::setOracleConfig: Invalid delay quote.");
        oracle.setOracleConfig(MARKET, config4, "TEST");
    }

    function testRevertInvalidSetOracle() public {
        IOmniOracle.OracleConfig memory config =
            IOmniOracle.OracleConfig(MOCK_OTHER, IOmniOracle.Provider(0), 1 hours, 5 hours, 18);
        vm.expectRevert("OmniOracle::setOracleConfig: Invalid provider.");
        oracle.setOracleConfig(MARKET, config, "TEST");
    }
}
