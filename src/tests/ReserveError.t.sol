// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "openzeppelin/contracts/utils/math/Math.sol";

import "./TestOmniToken.t.sol";
import "../interfaces/IOmniPool.sol";

contract TestCustom is Test {
    using SubAccount for address;

    address public constant ALICE = address(uint160(uint256(keccak256("alice.eth"))));
    address public constant reserve = address(uint160(uint256(keccak256("reserve.eth"))));
    address public constant BOB = address(uint160(uint256(keccak256("bob.eth"))));
    OmniPool pool;
    OmniToken oToken;
    MockERC20 uToken;
    MockOracle oracle;
    MockIRM irm;
    address market;

    function setUp() public {
        // initialize OmniPool
        oracle = new MockOracle();
        irm = new MockIRM();
        pool = new OmniPool();
        pool.initialize(address(oracle), reserve, address(this));
        uToken = new MockERC20('Mock', 'Mock');
        address[] memory underlyings = new address[](1);
        uint256[] memory prices = new uint256[](1);
        underlyings[0] = address(uToken);
        prices[0] = 1e18;
        oracle.setPrices(underlyings, prices);

        // initialize OmniToken
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e10 * 1e18;
        borrowCaps[1] = 1e10 * 1e18;
        borrowCaps[2] = 1e10 * 1e18;
        oToken = new OmniToken();
        oToken.initialize(address(pool), address(uToken), address(irm), borrowCaps);

        // mint tokens to Alice and BOB
        uToken.mint(address(ALICE), 1e6 * 1e18);
        vm.prank(ALICE);
        uToken.approve(address(oToken), type(uint256).max);
        uToken.mint(address(BOB), 1e6 * 1e18);
        vm.prank(BOB);
        uToken.approve(address(oToken), type(uint256).max);

        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        market = address(oToken);

        // create mode configs for markets with tranche 1 and 2
        IOmniPool.ModeConfiguration memory modeConfig1 =
            IOmniPool.ModeConfiguration(1e9, 1e9, 1, uint32(block.timestamp + 1000 days), markets);
        IOmniPool.ModeConfiguration memory modeConfig2 =
            IOmniPool.ModeConfiguration(1e9, 1e9, 2, uint32(block.timestamp + 1000 days), markets);
        pool.setModeConfiguration(modeConfig1);
        pool.setModeConfiguration(modeConfig2);
        // create market config for market with tranche 0
        IOmniPool.MarketConfiguration memory marketConfig =
            IOmniPool.MarketConfiguration(1e9, 1e9, uint32(block.timestamp + 1000 days), 0, false);
        pool.setMarketConfiguration(market, marketConfig);

        // enter markets
        vm.prank(ALICE);
        pool.enterMarkets(0, markets);
        vm.prank(ALICE);
        pool.enterMode(1, 1);
        vm.prank(ALICE);
        pool.enterMode(2, 2);
        vm.prank(BOB);
        pool.enterMarkets(0, markets);
        vm.prank(BOB);
        pool.enterMode(1, 1);
        vm.prank(BOB);
        pool.enterMode(2, 2);
    }

    // Here shows that calculation is wrong
    function test_custom1() public {
        // deposit
        vm.prank(ALICE);
        oToken.deposit(2, 2, 20_000e18);
        vm.prank(ALICE);
        oToken.deposit(1, 1, 20_000e18);

        //borrow
        vm.prank(ALICE);
        pool.borrow(2, market, 5_000e18);
        vm.prank(ALICE);
        pool.borrow(1, market, 10_000e18);

        uint256 reserveRevenueBefore = oToken.getAccountDepositInUnderlying(reserve.toAccount(0));

        // wait 1 year
        skip(365 days);
        oToken.accrue();

        uint256 reserveRevenueAfter = oToken.getAccountDepositInUnderlying(reserve.toAccount(0));
        uint256 actualReserveRevenue = reserveRevenueAfter - reserveRevenueBefore;

        // reserve fee is 10%
        uint256 feeFromTranche2 = 5_000e18 * 0.2 * 0.1; // 20% for tranche2
        uint256 feeFromTranche1 = 10_000e18 * 0.1 * 0.1; // 10% for tranche1
        uint256 expectedReserveRevenue = feeFromTranche2 + feeFromTranche1;
        (uint256 tda2,, uint256 tds2,) = oToken.tranches(2);
        (uint256 tda1,, uint256 tds1,) = oToken.tranches(1);
        // uint256 expectedReserve2 = feeFromTranche2 * (tda2) / tds2;
        // uint256 expectedReserve1 = feeFromTranche1 * (tda1) / tds1;

        bytes32 reserveAcc = reserve.toAccount(0);
        (uint256 ads2,) = oToken.getAccountSharesByTranche(reserveAcc, 2);
        (uint256 ads1,) = oToken.getAccountSharesByTranche(reserveAcc, 1);
        console.log("Reserve shares ", ads2 / 1e18, ads1 / 1e18);
        console.log("Amounts ", tda2 / 1e18, tda1 / 1e18);
        console.log("Shares ", tds2 / 1e18, tds1 / 1e18);
        console.log("Actual revenue in reserve (1e18):   ", actualReserveRevenue / 1e18);
        console.log("Expected revenue in reserve (1e18): ", expectedReserveRevenue / 1e18);
        // console.log("Expected new", (expectedReserve1 + expectedReserve2) / 1e18);
    }

    // Here shows values of shares minted to reserve
    function test_custom2() public {
        // deposit
        vm.prank(ALICE);
        oToken.deposit(2, 2, 20_000e18);
        vm.prank(ALICE);
        oToken.deposit(1, 1, 20_000e18);

        //borrow
        vm.prank(ALICE);
        pool.borrow(2, market, 5_000e18);
        vm.prank(ALICE);
        pool.borrow(1, market, 10_000e18);

        console.log("Before: ");
        (uint256 totalDepositAmount2Before,, uint256 totalDepositShare2Before,) = oToken.tranches(2);
        (uint256 totalDepositAmount1Before,, uint256 totalDepositShare1Before,) = oToken.tranches(1);

        console.log("totalDepositAmount2Before", totalDepositAmount2Before / 1e18);
        console.log("totalDepositShare2Before ", totalDepositShare2Before / 1e18);
        console.log("totalDepositAmount1Before", totalDepositAmount1Before / 1e18);
        console.log("totalDepositShare1Before ", totalDepositShare1Before / 1e18);
        console.log();

        // wait 1 year
        skip(365 days);
        oToken.accrue();

        console.log("After: ");
        (uint256 totalDepositAmount2After,, uint256 totalDepositShare2After,) = oToken.tranches(2);
        (uint256 totalDepositAmount1After,, uint256 totalDepositShare1After,) = oToken.tranches(1);

        console.log("totalDepositAmountAfter2", totalDepositAmount2After / 1e18);
        console.log("totalDepositShareAfter2 ", totalDepositShare2After / 1e18);
        console.log("totalDepositAmount1After", totalDepositAmount1After / 1e18);
        console.log("totalDepositShare1After ", totalDepositShare1After / 1e18);
        console.log();
        assertEq(totalDepositAmount2After, 21450e18, "incorrect total deposit amount in tranche 2");
        assertEq(totalDepositAmount1After, 20550e18, "incorrect total deposit amount in tranche 1");

        (uint256 reserveDepositShare2,) = oToken.getAccountSharesByTranche(reserve.toAccount(0), 2);
        (uint256 reserveDepositShare1,) = oToken.getAccountSharesByTranche(reserve.toAccount(0), 1);
        console.log("Deposit shares in Reserve in tranche 2:", reserveDepositShare2 / 1e18);
        console.log("Deposit shares in Reserve in tranche 1:", reserveDepositShare1 / 1e18);
    }
}

contract MockIRM {
    function getInterestRate(address _market, uint8 _tranche, uint256 _totalDeposit, uint256 _totalBorrow)
        external
        pure
        returns (uint256)
    {
        if (_tranche == 2) {
            return 0.2e9;
        } else if (_tranche == 1) {
            return 0.1e9;
        } else if (_tranche == 0) {
            return 0.05e9;
        } else if (_market != address(0) || _totalDeposit > 0 || _totalBorrow > 0) {
            return 1e9;
        }
        return 1e9;
    }
}
