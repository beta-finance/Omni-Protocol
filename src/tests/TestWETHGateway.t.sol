// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import "./mock/MockWETH.sol";
import "./mock/MockOracle.sol";
import "../IRM.sol";
import "../OmniOracle.sol";
import "../OmniPool.sol";
import "../OmniToken.sol";
import "../SubAccount.sol";
import "../WETHGateway.sol";

contract TestWETHGateway is Test {
    using SubAccount for address;

    MockWETH weth;
    OmniToken oWETH;
    WETHGateway gateway;

    function setUp() public {
        MockOracle mockOracle = new MockOracle();
        weth = new MockWETH();
        OmniOracle oracle = new OmniOracle();
        oracle.initialize(address(this));
        address[] memory underlyings = new address[](1);
        underlyings[0] = address(weth);
        uint256[] memory prices = new uint256[](1);
        prices[0] = 1e18;
        mockOracle.setPrices(underlyings, prices);
        IRM irm = new IRM();
        irm.initialize(address(this));
        OmniPool pool = new OmniPool();
        pool.initialize(address(oracle), address(this), address(this));
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e5 * 1e18;
        borrowCaps[1] = 1e4 * 1e18;
        borrowCaps[2] = 1e2 * 1e18;
        oWETH = new OmniToken();
        oWETH.initialize(address(pool), address(weth), address(irm), borrowCaps);
        irm.setIRMForMarket(address(oWETH), tranches, configs);
        gateway = new WETHGateway();
        gateway.initialize(address(oWETH));
    }

    function test_Initialize() public {
        WETHGateway testGateway = new WETHGateway();
        testGateway.initialize(address(oWETH));
        assertEq(testGateway.oweth(), address(oWETH));
        assertEq(testGateway.weth(), address(weth));
    }

    function test_Deposit() public {
        uint256 share = gateway.deposit{value: 1 ether}(0, 0);
        assertEq(share, 1 ether, "incorrect share amount");
        (uint256 tda, uint256 tba, uint256 tds, uint256 tbs) = oWETH.tranches(0);
        assertEq(tda, 1 ether, "incorrect deposit amount in 0 tranche");
        assertEq(tba, 0, "incorrect borrow amount in 0 tranche");
        assertEq(tds, 1 ether, "incorrect deposit shares in 0 tranche");
        assertEq(tbs, 0, "incorrect borrow shares in 0 tranche");
        bytes32 account = address(this).toAccount(0);
        (uint256 ads, uint256 abs) = oWETH.getAccountSharesByTranche(account, 0);
        assertEq(ads, share, "incorrect deposit shares in 0 tranche");
        assertEq(abs, 0, "incorrect borrow shares in 0 tranche");
    }
}
