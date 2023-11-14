// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./mock/MockERC20.sol";
import "./mock/MockOracle.sol";
import "../IRM.sol";
import "../OmniPool.sol";
import "../OmniToken.sol";
import "../OmniTokenNoBorrow.sol";
import "../interfaces/IOmniToken.sol";
import "../interfaces/IOmniPool.sol";
import "../SubAccount.sol";

contract TestOmniPool is Test {
    using SubAccount for address;

    address public constant ALICE = address(uint160(uint256(keccak256("alice.eth"))));
    address public constant BOB = address(uint160(uint256(keccak256("bob.eth"))));
    OmniPool pool;
    OmniToken oToken;
    OmniToken oToken2;
    OmniTokenNoBorrow oToken3;
    OmniTokenNoBorrow oToken4;
    IRM irm;
    MockERC20 uToken;
    MockERC20 uToken2;
    MockERC20 uToken3;
    MockOracle oracle;

    function setUp() public {
        // Init contracts
        oracle = new MockOracle();
        irm = new IRM();
        irm.initialize(address(this));
        pool = new OmniPool();
        pool.initialize(address(oracle), BOB, address(this));
        uToken = new MockERC20('USD Coin', 'USDC');
        uToken2 = new MockERC20('Wrapped Ethereum', 'WETH');
        uToken3 = new MockERC20('Shiba Inu', 'SHIB');

        // Oracle configs
        address[] memory underlyings = new address[](3);
        uint256[] memory prices = new uint256[](3);
        underlyings[0] = address(uToken);
        underlyings[1] = address(uToken2);
        underlyings[2] = address(uToken3);
        prices[0] = 1e18;
        prices[1] = 10e18;
        prices[2] = 0.1e18;
        oracle.setPrices(underlyings, prices);

        // Configs for oTokens
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        IIRM.IRMConfig[] memory configs2 = new IIRM.IRMConfig[](3);
        configs2[0] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.055e9, 0.825e9);
        configs2[1] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1e9);
        configs2[2] = IIRM.IRMConfig(0.75e9, 0.04e9, 0.12e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e9 * (10 ** uToken.decimals());
        borrowCaps[1] = 1e3 * (10 ** uToken.decimals());
        borrowCaps[2] = 1e2 * (10 ** uToken.decimals());

        // Init oTokens
        oToken = new OmniToken();
        oToken.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        oToken2 = new OmniToken();
        oToken2.initialize(address(pool), address(uToken2), address(irm), borrowCaps);
        uint256 supplyCap = 1e7 * (10 ** uToken3.decimals());
        oToken3 = new OmniTokenNoBorrow();
        oToken3.initialize(address(pool), address(uToken3), supplyCap);
        oToken4 = new OmniTokenNoBorrow();
        oToken4.initialize(address(pool), address(uToken3), supplyCap);
        irm.setIRMForMarket(address(oToken), tranches, configs);
        irm.setIRMForMarket(address(oToken2), tranches, configs2);

        // Set MarketConfigs for Pool
        IOmniPool.MarketConfiguration memory mConfig1 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 1000 days), 0, false);
        IOmniPool.MarketConfiguration memory mConfig2 =
            IOmniPool.MarketConfiguration(0.8e9, 0.8e9, uint32(block.timestamp + 1000 days), 0, false);
        IOmniPool.MarketConfiguration memory mConfig3 =
            IOmniPool.MarketConfiguration(0.4e9, 0, uint32(block.timestamp + 7 days), 2, true);
        IOmniPool.MarketConfiguration memory mConfig4 =
            IOmniPool.MarketConfiguration(0.4e9, 0, uint32(block.timestamp + 1000 days), 2, true);
        pool.setMarketConfiguration(address(oToken), mConfig1);
        pool.setMarketConfiguration(address(oToken2), mConfig2);
        pool.setMarketConfiguration(address(oToken3), mConfig3);
        pool.setMarketConfiguration(address(oToken4), mConfig4);

        // Set ModeConfigs for Pool
        address[] memory modeMarkets = new address[](2);
        modeMarkets[0] = address(oToken);
        modeMarkets[1] = address(oToken2);
        IOmniPool.ModeConfiguration memory modeStableMode =
            IOmniPool.ModeConfiguration(0.95e9, 0.95e9, 0, uint32(block.timestamp + 7 days), modeMarkets);
        pool.setModeConfiguration(modeStableMode);
        pool.setModeConfiguration(modeStableMode);

        // Minting tokens
        uToken.mint(address(this), 1e6 * (10 ** uToken.decimals()));
        uToken.mint(address(ALICE), 1e6 * (10 ** uToken.decimals()));
        uToken.mint(address(BOB), 1e2 * (10 ** uToken.decimals()));
        uToken2.mint(address(this), 1e6 * (10 ** uToken2.decimals()));
        uToken2.mint(address(ALICE), 1e6 * (10 ** uToken2.decimals()));
        uToken2.mint(address(BOB), 1e2 * (10 ** uToken2.decimals()));
        uToken3.mint(address(this), 1e7 * (10 ** uToken3.decimals()));
        uToken3.mint(address(ALICE), 1e7 * (10 ** uToken3.decimals()));
        uToken3.mint(address(BOB), 1e5 * (10 ** uToken3.decimals()));

        // Approvals
        uToken.approve(address(oToken), type(uint256).max);
        uToken2.approve(address(oToken2), type(uint256).max);
        uToken3.approve(address(oToken3), type(uint256).max);
        uToken3.approve(address(oToken4), type(uint256).max);
        vm.startPrank(ALICE);
        uToken.approve(address(oToken), type(uint256).max);
        uToken2.approve(address(oToken2), type(uint256).max);
        uToken3.approve(address(oToken3), type(uint256).max);
        uToken3.approve(address(oToken4), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(BOB);
        uToken.approve(address(oToken), type(uint256).max);
        uToken2.approve(address(oToken2), type(uint256).max);
        uToken3.approve(address(oToken3), type(uint256).max);
        uToken3.approve(address(oToken4), type(uint256).max);
        vm.stopPrank();
    }

    function test_Initialize() public {
        OmniPool pool1 = new OmniPool();
        pool1.initialize(address(oracle), ALICE, address(this));
        assertEq(pool1.oracle(), address(oracle), "oracle address is incorrect");
        assertEq(pool1.pauseTranche(), type(uint8).max, "pauseTranche is incorrect");
        assertEq(pool1.reserveReceiver(), ALICE.toAccount(0), "reserveReceiver is incorrect");
        assertEq(
            pool1.hasRole(pool1.DEFAULT_ADMIN_ROLE(), address(this)),
            true,
            "Deployer should have the DEFAULT_ADMIN_ROLE"
        );
        assertEq(
            pool1.hasRole(pool1.SOFT_LIQUIDATION_ROLE(), address(this)),
            true,
            "Deployer should have the SOFT_LIQUIDATION_ROLE"
        );
        assertEq(
            pool1.hasRole(pool1.MARKET_CONFIGURATOR_ROLE(), address(this)),
            true,
            "Deployer should have the MARKET_CONFIGURATOR_ROLE"
        );
    }

    function test_EnterIsolatedMarket() public {
        IOmniPool(pool).enterIsolatedMarket(0, address(oToken3));
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.isolatedCollateralMarket, address(oToken3), "isolatedCollateralMarket is incorrect");
    }

    function test_EnterMarkets() public {
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        markets[0] = address(oToken2);
        pool.enterMarkets(0, markets);
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        address[] memory enteredMarkets = pool.getAccountPoolMarkets(account, info);
        assertEq(enteredMarkets[0], address(oToken), "enteredMarkets[0] is incorrect");
        assertEq(enteredMarkets[1], address(oToken2), "enteredMarkets[1] is incorrect");
        assertEq(enteredMarkets.length, 2, "enteredMarkets.length is incorrect");
    }

    function test_ExitMarkets() public {
        test_EnterMarkets();
        test_EnterIsolatedMarket();

        pool.exitMarket(0, address(oToken2));
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        address[] memory enteredMarkets = pool.getAccountPoolMarkets(account, info);
        assertEq(enteredMarkets[0], address(oToken), "enteredMarkets[0] is incorrect");
        assertEq(enteredMarkets.length, 1, "enteredMarkets.length is incorrect");
        pool.exitMarket(0, address(oToken));
        address[] memory enteredMarkets2 = pool.getAccountPoolMarkets(account, info);
        assertEq(enteredMarkets2.length, 0, "enteredMarkets.length is incorrect");
        pool.exitMarket(0, address(oToken3));
        IOmniPool.AccountInfo memory info2 = _getAccountInfo(account);
        assertEq(info2.isolatedCollateralMarket, address(0), "isolatedCollateralMarket is incorrect");
    }

    function test_ClearMarkets() public {
        test_EnterMarkets();
        test_EnterIsolatedMarket();

        pool.clearMarkets(0);
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        address[] memory enteredMarkets = pool.getAccountPoolMarkets(account, info);
        assertEq(enteredMarkets.length, 0, "enteredMarkets.length is incorrect");
        assertEq(info.isolatedCollateralMarket, address(0), "isolatedCollateralMarket is incorrect");
    }

    function test_EnterMode() public {
        pool.enterMode(0, 1);
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.modeId, 1, "modeId is incorrect");
    }

    function test_ExitMode() public {
        test_EnterMode();
        vm.warp(1 days);
        pool.exitMode(0);
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.modeId, 0, "modeId is incorrect");
    }

    function test_SetTrancheCount() public {
        pool.setTrancheCount(address(oToken), 4);
        assertEq(oToken.trancheCount(), 4, "trancheCount is incorrect");
    }

    function test_BorrowNotIsolatedCollateral() public {
        uint256 amount1 = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, 2, amount1);
        vm.startPrank(ALICE);
        uint256 amount2 = 1e2 * (10 ** uToken2.decimals());
        oToken2.deposit(0, 2, amount2);
        {
            address[] memory markets = new address[](2);
            markets[0] = address(oToken);
            markets[1] = address(oToken2);
            pool.enterMarkets(0, markets);
            uint256 balBefore = uToken.balanceOf(ALICE);
            pool.borrow(0, address(oToken), amount1);
            uint256 balAfter = uToken.balanceOf(ALICE);
            assertEq(balAfter - balBefore, amount2, "balanceOf is incorrect");
        }
        _assertTrancheValues(address(oToken), 0, 0, amount1, 0, 0, amount1, amount1, 0, 0, amount1, 0, 0);
        _assertTrancheValues(address(oToken2), 0, 0, amount2, 0, 0, amount2, 0, 0, 0, 0, 0, 0);

        (uint256 ads, uint256 abs) = oToken.getAccountSharesByTranche(address(ALICE).toAccount(0), 0);
        assertEq(ads, 0, "ads is incorrect");
        assertEq(abs, amount1, "abs is incorrect");
        vm.stopPrank();
    }

    function test_BorrowIsolatedCollateral() public {
        uint256 amount1 = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, 2, amount1);
        vm.startPrank(ALICE);
        oToken3.deposit(0, 1e5 * (10 ** uToken3.decimals()));
        {
            address[] memory markets = new address[](1);
            markets[0] = address(oToken);
            pool.enterIsolatedMarket(0, address(oToken3));
            pool.enterMarkets(0, markets);
        }
        uint256 balBefore = uToken.balanceOf(ALICE);
        pool.borrow(0, address(oToken), amount1);
        uint256 balAfter = uToken.balanceOf(ALICE);
        assertEq(balAfter - balBefore, amount1, "balanceOf is incorrect");

        _assertTrancheValues(address(oToken), 0, 0, amount1, 0, 0, amount1, 0, 0, amount1, 0, 0, amount1);

        (uint256 ads, uint256 abs) = oToken.getAccountSharesByTranche(address(ALICE).toAccount(0), 2);
        assertEq(ads, 0, "ads is incorrect");
        assertEq(abs, amount1, "abs is incorrect");
        vm.stopPrank();
    }

    function test_BorrowInMode() public {
        test_EnterMode();
        vm.prank(ALICE);
        oToken2.deposit(0, 2, 100e18);
        oToken.deposit(0, 0, 1000e18);
        pool.borrow(0, address(oToken2), 90.2e18);
        bytes32 account = address(this).toAccount(0);
        IOmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        _assertEvaluationValues(eval, 1000e18, 902e18, 950e18, 949473684210526315789, 1, 1);
    }

    function test_Repay() public {
        test_BorrowIsolatedCollateral();
        uint256 repayAmount = 50 * (10 ** uToken.decimals()); // 1/2 of the existing borrow
        vm.startPrank(ALICE);
        uint256 balBefore = uToken.balanceOf(ALICE);
        pool.repay(0, address(oToken), repayAmount);
        uint256 balAfter = uToken.balanceOf(ALICE);
        assertEq(balBefore - balAfter, repayAmount, "balanceOf is incorrect");
        (uint256 ads, uint256 abs) = oToken.getAccountSharesByTranche(address(ALICE).toAccount(0), 2);
        assertEq(ads, 0, "ads is incorrect");
        assertEq(abs, repayAmount, "abs is incorrect");

        vm.warp(2 days); // Trigger interest

        oToken.accrue();
        pool.repay(0, address(oToken), 0); // repay full
        (ads, abs) = oToken.getAccountSharesByTranche(address(ALICE).toAccount(0), 2);
        assertEq(ads, 0, "ads is incorrect");
        assertEq(abs, 0, "abs is incorrect");
        vm.stopPrank();
    }

    function test_EvaluateAccountSingle() public {
        test_BorrowIsolatedCollateral();
        vm.startPrank(ALICE);
        bytes32 account = address(ALICE).toAccount(0);
        OmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        _assertEvaluationValues(eval, 1e4 * 1e18, 1e2 * 1e18, 4e3 * 1e18, 111111111111111111111, 1, 1);
        vm.stopPrank();
    }

    function test_EvaluateAccountSelfCollateral() public {
        uint256 amount1 = 1e3 * (10 ** uToken.decimals());
        oToken.deposit(3, 1, amount1);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(3, markets);
        pool.borrow(3, address(oToken), 0.9216e18 * amount1 / 1e18); // max self collateral borrow
        bytes32 account = address(this).toAccount(3);
        OmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        _assertEvaluationValues(eval, 1e3 * 1e18, 1e3 * 0.9216e18, 1e3 * 0.96e18, 1e3 * 0.96e18, 1, 1);
    }

    function test_EvaluateAccountMultiple() public {
        uint256 amount1 = 1e3 * (10 ** uToken.decimals()); // $1000, 900
        uint256 amount2 = 1e2 * (10 ** uToken2.decimals()); // $1000, 800
        uint256 amount3 = 1e4 * (10 ** uToken3.decimals()); // $1000, 400
        oToken.deposit(0, 2, amount1);
        vm.startPrank(ALICE);
        oToken.deposit(0, 2, amount1 / 2);
        oToken.deposit(0, 1, amount1 / 2);
        oToken2.deposit(0, 0, amount2 / 4);
        oToken2.deposit(0, 1, amount2 * 2 / 4);
        oToken2.deposit(0, 2, amount2 / 4);
        oToken3.deposit(0, amount3);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](2);
        markets[0] = address(oToken);
        markets[1] = address(oToken2);
        pool.enterMarkets(0, markets);
        bytes32 account = address(ALICE).toAccount(0);
        OmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        _assertEvaluationValues(eval, 3e3 * 1e18, 0, 2.1e3 * 1e18, 0, 3, 0);
        pool.borrow(0, address(oToken2), amount2 / 4); // Utilization 100%
        OmniPool.Evaluation memory eval2 = pool.evaluateAccount(account);
        _assertEvaluationValues(eval2, 3e3 * 1e18, 1e3 * 1e18 / 4, 2.1e3 * 1e18, 1e3 * 1e18 / 4 * 1e18 / 0.8e18, 3, 1);
        pool.borrow(0, address(oToken), 1e2 * 1e18); // Utilization 10%
        OmniPool.Evaluation memory eval3 = pool.evaluateAccount(account);
        _assertEvaluationValues(
            eval3,
            3e3 * 1e18,
            100e18 + 1e3 * 1e18 / 4,
            2.1e3 * 1e18,
            1e3 * 1e18 / 4 * 1e18 / 0.8e18 + 111111111111111111111,
            3,
            2
        );
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.isolatedCollateralMarket, address(oToken3), "isolatedCollateralMarket is incorrect");

        // Test with accrued intesrest
        vm.warp(100 days); // Trigger interest
        OmniPool.Evaluation memory eval4 = pool.evaluateAccount(account);
        uint256 dtv = 3074267114689199645166;
        uint256 btv = 433173506346038391035;
        uint256 dav = 2159443143802471461471;
        uint256 bav = 527441641955178797411;
        _assertEvaluationValues(eval4, dtv, btv, dav, bav, 3, 2);
    }

    function test_EvaluateAccountMultipleNoIsolated() public {
        uint256 amount1 = 1e3 * (10 ** uToken.decimals()); // $1000, 900
        uint256 amount2 = 1e2 * (10 ** uToken2.decimals()); // $1000, 800
        oToken.deposit(2, 2, amount1 / 2);
        oToken.deposit(2, 1, amount1 / 2);
        oToken2.deposit(2, 0, amount2 / 4);
        oToken2.deposit(2, 1, amount2 * 2 / 4);
        oToken2.deposit(2, 2, amount2 / 4);
        address[] memory markets = new address[](2);
        markets[0] = address(oToken);
        markets[1] = address(oToken2);
        pool.enterMarkets(2, markets);
        bytes32 account = address(this).toAccount(2);
        IOmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        _assertEvaluationValues(eval, 2e3 * 1e18, 0, 1.7e3 * 1e18, 0, 2, 0);
        pool.borrow(2, address(oToken2), amount2);
        IOmniPool.Evaluation memory eval2 = pool.evaluateAccount(account);
        _assertEvaluationValues(eval2, 2e3 * 1e18, 1e3 * 1e18, 1.7e3 * 1e18, 1.25e3 * 1e18, 2, 1);
        pool.borrow(2, address(oToken), 3e2 * 1e18);
        IOmniPool.Evaluation memory eval3 = pool.evaluateAccount(account);
        _assertEvaluationValues(
            eval3, 2e3 * 1e18, 1e3 * 1e18 + 3e2 * 1e18, 1.7e3 * 1e18, 1.25e3 * 1e18 + 3 * 111111111111111111111, 2, 2
        );
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.isolatedCollateralMarket, address(0), "isolatedCollateralMarket is incorrect");
        pool.repay(2, address(oToken), 1e2 * 1e18);
        IOmniPool.Evaluation memory eval4 = pool.evaluateAccount(account);
        _assertEvaluationValues(
            eval4, 2e3 * 1e18, 1e3 * 1e18 + 2e2 * 1e18, 1.7e3 * 1e18, 1.25e3 * 1e18 + 2 * 111111111111111111111, 2, 2
        );
        pool.repay(2, address(oToken), 0);
        IOmniPool.Evaluation memory eval5 = pool.evaluateAccount(account);
        _assertEvaluationValues(eval5, 2e3 * 1e18, 1e3 * 1e18, 1.7e3 * 1e18, 1.25e3 * 1e18, 2, 1);
    }

    function test_LeverageBorrowDeposit() public {
        uint256 amount = 1e6 * (10 ** uToken.decimals());
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        oToken.deposit(0, 0, amount);
        for (uint256 i = 1; i < 14; i++) {
            pool.borrow(0, address(oToken), (amount * (0.85e2 ** i)) / (1e2 ** i));
            oToken.deposit(0, 0, (amount * (0.85e2 ** i)) / (1e2 ** i));
        }
        OmniToken.OmniTokenTranche memory tranche = _getOmniTokenTranche(address(oToken), 0);
        assertEq(tranche.totalDepositAmount, 5981535536460770959472656, "totalDepositAmount is incorrect");
        assertEq(tranche.totalBorrowAmount, 4981535536460770959472656, "totalBorrowAmount is incorrect");
        assertEq(
            tranche.totalDepositAmount - tranche.totalBorrowAmount,
            amount,
            "totalDepositAmount - totalBorrowAmount is incorrect"
        );
        vm.warp(365 days);
        bytes32 account = address(this).toAccount(0);
        OmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.isolatedCollateralMarket, address(0), "isolatedCollateralMarket is incorrect");
        bool healthy = pool.isAccountHealthy(account);
        assertEq(healthy, true, "healthy is incorrect");
    }

    function test_LeverageRepayWithdraw() public {
        test_LeverageBorrowDeposit();
        bytes32 account = address(this).toAccount(0);
        uint256 balBefore = uToken.balanceOf(address(this));
        assertEq(balBefore, 0, "balanceOf is incorrect");
        IOmniPool.Evaluation memory eval = pool.evaluateAccount(account);
        uint256 amount = Math.min(eval.borrowTrueValue, (eval.depositAdjValue - eval.borrowAdjValue) * 0.96e9 / 1e9);
        oToken.withdraw(0, 0, amount);
        for (uint256 i = 1; i < 14; i++) {
            pool.repay(0, address(oToken), amount);
            if (amount == 0) {
                break;
            }
            eval = pool.evaluateAccount(account);
            amount = Math.min(eval.borrowTrueValue, (eval.depositAdjValue - eval.borrowAdjValue) * 0.96e9 / 1e9);
            oToken.withdraw(0, 0, amount);
            if (amount == eval.borrowTrueValue) {
                amount = 0;
            }
        }
        IOmniPool.Evaluation memory eval2 = pool.evaluateAccount(account);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(eval2.borrowTrueValue, 0, "borrowTrueValue is incorrect");
        assertEq(eval2.depositTrueValue, 855678362630444128588900, "depositTrueValue is incorrect");
        assertEq(balAfter, 127815889780552317129622, "balanceOf After is incorrect");
    }

    function test_SetLiquidationBonus() public {
        address _market = address(oToken3);
        IOmniPool.LiquidationBonusConfiguration memory lbconfig =
            IOmniPool.LiquidationBonusConfiguration(0.05e9, 0.3e9, 0.2e9, 0.04e9, 1.4e9);
        pool.setLiquidationBonusConfiguration(_market, lbconfig);
        (uint64 s, uint64 e, uint64 k, uint64 eb, uint64 st) = pool.liquidationBonusConfigurations(_market);
        assertEq(s, 0.05e9, "s is incorrect");
        assertEq(e, 0.3e9, "e is incorrect");
        assertEq(k, 0.2e9, "k is incorrect");
        assertEq(eb, 0.04e9, "eb is incorrect");
        assertEq(st, 1.4e9, "st is incorrect");
    }

    function test_GetLiquidationBonusAndThresholdNoAccount() public {
        test_SetLiquidationBonus();
        (uint256 bonus, uint256 threshold) = pool.getLiquidationBonusAndThreshold(100, 120, address(oToken3));
        assertEq(bonus, 0.3e9, "bonus is incorrect");
        assertEq(threshold, 1.4e9, "threshold is incorrect");
        (uint256 b1, uint256 t1) = pool.getLiquidationBonusAndThreshold(100, 150, address(oToken3));
        assertEq(b1, 0.3e9, "bonus1 is incorrect");
        assertEq(t1, 1.4e9, "threshold1 is incorrect");
        (uint256 b2,) = pool.getLiquidationBonusAndThreshold(100, 105, address(oToken3));
        assertEq(b2, 0.1125e9, "bonus2 is incorrect");
        (uint256 b3,) = pool.getLiquidationBonusAndThreshold(100, 103, address(oToken3));
        assertEq(b3, 0.0875e9, "bonus3 is incorrect");
        vm.warp(8 days);
        (uint256 eb,) = pool.getLiquidationBonusAndThreshold(100, 0, address(oToken3));
        assertEq(eb, 0.04e9, "eb is incorrect");
    }

    function test_Liquidate() public {
        test_SetLiquidationBonus();
        oToken.deposit(0, 2, 1e2 * (10 ** uToken.decimals()));
        vm.startPrank(ALICE);
        oToken3.deposit(0, 2780e18);
        oToken3.deposit(3, 1e4 * 1e18);
        pool.enterIsolatedMarket(3, address(oToken3)); // Persist
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 1e2 * (10 ** uToken.decimals()));
        OmniToken.OmniTokenTranche memory tranche0 = _getOmniTokenTranche(address(oToken), 2);
        assertEq(tranche0.totalDepositAmount, tranche0.totalBorrowAmount, "totalDepositAmount is incorrect"); // Max utilization
        vm.warp(1 days);
        OmniToken.OmniTokenTranche memory tranche0A = _getOmniTokenTranche(address(oToken), 2);
        assertEq(
            tranche0A.totalDepositAmount, tranche0A.totalBorrowAmount, "totalDepositAmount is incorrect after accrue"
        ); // Max utilization
        vm.stopPrank();
        bytes32 accountLiq = address(this).toAccount(0);
        bytes32 accountTarget = address(ALICE).toAccount(0);
        address liquidateMarket = address(oToken);
        address collateralMarket = address(oToken3);
        assertEq(pool.isAccountHealthy(accountTarget), false, "isAccountHealthy false is incorrect");
        uint256 targetBalBefore = oToken3.balanceOfAccount(accountTarget);
        uint256 balBeforeLiquidate = uToken.balanceOf(address(this));
        uint256[] memory seizedShares = pool.liquidate(
            IOmniPool.LiquidationParams(accountTarget, accountLiq, liquidateMarket, collateralMarket, 10e18)
        );
        uint256 balSeized = oToken3.balanceOfAccount(accountLiq);
        uint256 balAfterLiquidate = uToken.balanceOf(address(this));
        assertEq(balBeforeLiquidate - balAfterLiquidate, 10e18, "balanceOf is incorrect");
        assertEq(balSeized, 105310705700000000000, "balanceOfAccount is incorrect");
        assertEq(seizedShares[0], 105310705700000000000, "seizedShares[0] is incorrect");
        assertEq(pool.isAccountHealthy(accountTarget), true, "isAccountHealthy true is incorrect");
        uint256 targetBalAfter = oToken3.balanceOfAccount(accountTarget);
        assertEq(targetBalBefore - targetBalAfter, balSeized, "balanceOfAccount is incorrect");
        OmniPool.AccountInfo memory info = _getAccountInfo(accountTarget);
        uint8 borrowTier = pool.getAccountBorrowTier(info);
        uint256 targetBorrowBal = oToken.getAccountBorrowInUnderlying(accountTarget, borrowTier);
        assertEq(targetBorrowBal, 90328763318112633181, "targetBorrowBal is incorrect");
    }

    function test_LiquidateExpired() public {
        test_SetLiquidationBonus();
        oToken.deposit(0, 2, 100e18);
        vm.startPrank(ALICE);
        oToken3.deposit(0, 1e4 * 1e18);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 100e18);
        vm.warp(8 days); // Market is now expired
        bytes32 accountLiq = address(this).toAccount(0);
        bytes32 accountTarget = address(ALICE).toAccount(0);
        address liquidateMarket = address(oToken);
        address collateralMarket = address(oToken3);
        assertEq(pool.isAccountHealthy(accountTarget), false, "isAccountHealthy false is incorrect");
        uint256[] memory seizedShares = pool.liquidate(
            IOmniPool.LiquidationParams(accountTarget, accountLiq, liquidateMarket, collateralMarket, 100e18)
        );
        assertEq(seizedShares[0], 1040000000000000000000, "seizedShares[0] is incorrect");
        assertEq(oToken3.balanceOfAccount(accountLiq), 1040000000000000000000, "balanceOfAccount is incorrect");
    }

    function test_LiquidateBadDebtSocialize() public {
        test_SetLiquidationBonus();
        vm.prank(BOB);
        oToken.deposit(0, 2, 30e18);
        oToken.deposit(0, 2, 70e18);
        vm.startPrank(ALICE);
        oToken3.deposit(0, 2780 * 1e18);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 100e18); // 100% utilization at 120% interest per year
        vm.warp(700 days); // A lot of interest
        bytes32 accountLiq = address(this).toAccount(0);
        bytes32 accountTarget = address(ALICE).toAccount(0);
        address liquidateMarket = address(oToken);
        address collateralMarket = address(oToken3);
        assertEq(pool.isAccountHealthy(accountTarget), false, "isAccountHealthy false is incorrect");
        uint256[] memory seizedShares = pool.liquidate(
            IOmniPool.LiquidationParams(accountTarget, accountLiq, liquidateMarket, collateralMarket, 213.846e18)
        );
        assertEq(seizedShares[0], 2779998000000000000000, "seizedShares[0] is incorrect");
        assertEq(oToken3.balanceOfAccount(accountLiq), 2779998000000000000000, "balanceOfAccount is incorrect");
        assertEq(pool.pauseTranche(), 2, "pauseTranche is incorrect");
        vm.stopPrank();

        vm.expectRevert("OmniToken::deposit: Tranche paused.");
        oToken.deposit(0, 2, 1e18);

        vm.expectRevert("OmniToken::withdraw: Tranche paused.");
        oToken.withdraw(0, 2, 1e18);

        vm.expectRevert("OmniToken::transfer: Tranche paused.");
        oToken.transfer(0, accountTarget, 2, 1e18);

        oToken.deposit(0, 0, 1000e18);
        address[] memory markets2 = new address[](1);
        markets2[0] = address(oToken);
        pool.enterMarkets(0, markets2);
        pool.borrow(0, address(oToken), 10e18);
        oToken4.deposit(1, 1e4 * 1e18);
        pool.enterIsolatedMarket(1, address(oToken4));
        pool.enterMarkets(1, markets2);
        vm.expectRevert("OmniToken::borrow: Tranche paused.");
        pool.borrow(1, address(oToken), 10e18);

        OmniToken.OmniTokenTranche memory tranche2 = _getOmniTokenTranche(address(oToken), 2);
        pool.socializeLoss(address(oToken), accountTarget);
        OmniToken.OmniTokenTranche memory tranche2After = _getOmniTokenTranche(address(oToken), 2);
        assertEq(tranche2.totalDepositAmount, 330136982496194824961, "totalDepositAmount is incorrect"); // ~330
        assertEq(tranche2.totalBorrowAmount, 116290982496194824961, "totalBorrowAmount is incorrect"); // ~$116
        assertEq(tranche2After.totalDepositAmount, 213846000000000000000, "totalDepositAmount is incorrect"); // ~213
        assertEq(tranche2After.totalBorrowAmount, 0, "totalBorrowAmount is incorrect"); // ~$0
        assertEq(tranche2After.totalBorrowShare, 0, "totalBorrowShare is incorrect"); // ~$0
        (uint256 adsl, uint256 absl) = oToken.getAccountSharesByTranche(accountTarget, 2);
        assertEq(adsl, 0, "adsl is incorrect");
        assertEq(absl, 0, "absl is incorrect");

        pool.resetPauseTranche();
        pool.borrow(1, address(oToken), 10e18);
        (uint256 ads, uint256 abs) = oToken.getAccountSharesByTranche(address(this).toAccount(1), 2);
        assertEq(ads, 0, "ads is incorrect");
        assertEq(abs, 10e18, "abs is incorrect");
    }

    function test_LiquidateNoIsolatedAccrue() public {
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.01e9, 1e9, 1e9, 1e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        irm.setIRMForMarket(address(oToken), tranches, configs);
        oToken.deposit(0, 2, 1e2 * 1e18);
        vm.startPrank(ALICE);
        oToken.deposit(0, 0, 0.1e2 * 1e18);
        oToken.deposit(0, 1, 0.1e2 * 1e18);
        oToken.deposit(0, 2, 0.8e2 * 1e18);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 0.9216e2 * 1e18);
        vm.stopPrank();
        vm.warp(365 days);
        oToken.accrue();
        OmniToken.OmniTokenTranche memory tranche0 = _getOmniTokenTranche(address(oToken), 0);
        assertApproxEqRel(
            tranche0.totalDepositAmount,
            1e19 + 0.9216e20 * 0.1 + 0.9216e20 * 0.9 * 0.05,
            0.0001e18,
            "Incorrect total deposit amount"
        );
        assertApproxEqRel(tranche0.totalBorrowAmount, 2 * 0.9216e20, 0.0001e18, "Incorrect total borrow amount");
        assertApproxEqRel(tranche0.totalDepositShare, 1e19 + 6.51436e18, 0.0001e18, "Incorrect total deposit shares");
        assertEq(tranche0.totalBorrowShare, 0.9216e20, "Incorrect total borrow shares");
        OmniToken.OmniTokenTranche memory tranche1 = _getOmniTokenTranche(address(oToken), 1);
        assertApproxEqRel(
            tranche1.totalDepositAmount, 1e19 + 0.9216e20 * 0.9 * 0.05, 0.0001e18, "Incorrect total deposit amount"
        );
        assertEq(tranche1.totalDepositShare, 1e19, "Incorrect total deposit shares");
        assertEq(tranche1.totalBorrowAmount, 0, "Incorrect total borrow amount");
        assertEq(tranche1.totalBorrowShare, 0, "Incorrect total borrow shares");
        OmniToken.OmniTokenTranche memory tranche2 = _getOmniTokenTranche(address(oToken), 2);
        assertApproxEqRel(
            tranche2.totalDepositAmount, 1.8e20 + 0.9216e20 * 0.9 * 0.9, 0.0001e18, "Incorrect total deposit amount"
        );
        assertEq(tranche2.totalDepositShare, 1.8e20, "Incorrect total deposit shares");
        assertEq(tranche2.totalBorrowAmount, 0, "Incorrect total borrow amount");
        assertEq(tranche2.totalBorrowShare, 0, "Incorrect total borrow shares");

        IOmniPool.LiquidationBonusConfiguration memory lbconfig =
            IOmniPool.LiquidationBonusConfiguration(0.1e9, 0.1e9, 0e9, 0.1e9, 1.4e9);
        pool.setLiquidationBonusConfiguration(address(oToken), lbconfig);

        uint256[] memory seizedShares = pool.liquidate(
            IOmniPool.LiquidationParams(
                address(ALICE).toAccount(0), address(this).toAccount(1), address(oToken), address(oToken), 0.2e2 * 1e18
            )
        );

        // Liquidator receives 10% liquidation bonus for liquidating, should receive 0.22e20 worth of tokens from shares
        assertEq(seizedShares[0], 10000000000000000000, "seizedShares[0] is incorrect");
        assertEq(seizedShares[1], 5550780510986919631, "seizedShares[1] is incorrect");
        assertEq(seizedShares[2], 0, "seizedShares[2] is incorrect");
        assertApproxEqRel(
            seizedShares[0] * tranche0.totalDepositAmount / tranche0.totalDepositShare
                + seizedShares[1] * tranche1.totalDepositAmount / tranche1.totalDepositShare,
            0.22e20,
            0.0001e18,
            "Incorrect total seized amount"
        );
    }

    function test_SocializeLossMultiTranche() public {
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.01e9, 1e9, 1e9, 1e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        irm.setIRMForMarket(address(oToken), tranches, configs);

        address _market = address(oToken2);
        IOmniPool.LiquidationBonusConfiguration memory lbconfig =
            IOmniPool.LiquidationBonusConfiguration(0.05e9, 0.3e9, 0.2e9, 0.04e9, 1.4e9);
        pool.setLiquidationBonusConfiguration(_market, lbconfig);
        oToken2.deposit(0, 0, 10e18);
        oToken.deposit(1, 1, 100e18);
        oToken.deposit(2, 2, 100e18);

        {
            address[] memory markets = new address[](2);
            markets[0] = address(oToken);
            markets[1] = address(oToken2);
            pool.enterMarkets(0, markets);
        }
        pool.borrow(0, address(oToken), 70e18);
        vm.warp(365 days);

        {
            bytes32 accountTarget = address(this).toAccount(0);
            bytes32 accountLiq = address(ALICE).toAccount(0);
            address liquidateMarket = address(oToken);
            address collateralMarket = address(oToken2);
            assertEq(pool.isAccountHealthy(accountTarget), false, "isAccountHealthy false is incorrect");
            pool.liquidate(
                IOmniPool.LiquidationParams(accountTarget, accountLiq, liquidateMarket, collateralMarket, 76.923e18)
            );
            pool.socializeLoss(address(oToken), accountTarget);
        }
        _assertTrancheValues(
            address(oToken),
            5364670244361049698,
            100779164877819475151,
            100779164877819475151,
            6999999778031456113,
            100000000000000000000,
            100000000000000000000,
            0,
            0,
            0,
            0,
            0,
            0
        );
    }

    function test_IsAccountHealthy() public {
        test_SetLiquidationBonus();

        vm.prank(ALICE);
        oToken.deposit(0, 2, 100e18);

        oToken3.deposit(0, 1e4 * 1e18);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 10e18);
        bytes32 account = address(this).toAccount(0);
        bool healthy = pool.isAccountHealthy(account);
        assertEq(healthy, true, "healthy is incorrect");
        vm.warp(8 days);
        bool healthAfter = pool.isAccountHealthy(account);
        assertEq(healthAfter, false, "healthAfter is incorrect");
    }

    function test_CheckSoftLiquidation() public {
        bytes32 account = address(this).toAccount(0);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        bool noBorrow = pool.checkSoftLiquidation(0, 0, 1.4e9, info);
        assertEq(noBorrow, false, "noBorrow is incorrect");
        bool noAccountSoft = pool.checkSoftLiquidation(140, 100, 1.4e9, info);
        assertEq(noAccountSoft, true, "noAccountSoft is incorrect");
        bool noAccountSoft2 = pool.checkSoftLiquidation(120, 100, 1.4e9, info);
        assertEq(noAccountSoft2, true, "noAccountSoft2 is incorrect");

        test_SetAccountSoftLiq();
        IOmniPool.AccountInfo memory info2 = _getAccountInfo(account);
        bool accountSoft = pool.checkSoftLiquidation(130, 100, 1.4e9, info2);
        assertEq(accountSoft, true, "accountSoft is incorrect");
        bool accountSoft2 = pool.checkSoftLiquidation(140, 100, 1.4e9, info2);
        assertEq(accountSoft2, false, "accountSoft2 is incorrect");
    }

    function test_SetAccountSoftLiq() public {
        bytes32 account = address(this).toAccount(0);
        pool.setAccountSoftLiquidation(account, 1.3e9);
        IOmniPool.AccountInfo memory info = _getAccountInfo(account);
        assertEq(info.softThreshold, 1.3e9, "softThreshold is incorrect");
    }

    function test_SetBorrowCap() public {
        uint256[] memory caps = new uint256[](3);
        caps[0] = 1e8 * 10e18;
        caps[1] = 1e7 * 10e18;
        caps[2] = 1e6 * 10e18;
        pool.setBorrowCap(address(oToken), caps);
        uint256[] memory newCaps = new uint256[](3);
        newCaps[0] = oToken.trancheBorrowCaps(0);
        newCaps[1] = oToken.trancheBorrowCaps(1);
        newCaps[2] = oToken.trancheBorrowCaps(2);
        assertEq(newCaps[0], 1e8 * 10e18, "newCaps[0] is incorrect");
        assertEq(newCaps[1], 1e7 * 10e18, "newCaps[1] is incorrect");
        assertEq(newCaps[2], 1e6 * 10e18, "newCaps[2] is incorrect");
    }

    function test_SetSupplyCap() public {
        pool.setNoBorrowSupplyCap(address(oToken3), 1e2 * 1e18);
        assertEq(oToken3.supplyCap(), 1e2 * 1e18, "noBorrowSupplyCap is incorrect");
    }

    function test_SetReserveReceiver() public {
        pool.setReserveReceiver(ALICE);
        assertEq(pool.reserveReceiver(), ALICE.toAccount(0), "reserveReceiver is incorrect");
    }

    function test_LiquidatePauseTrancheLowest() public {
        IIRM.IRMConfig[] memory configs2 = new IIRM.IRMConfig[](3);
        configs2[0] = IIRM.IRMConfig(0.001e9, 1e9, 1e9, 1e9);
        configs2[1] = IIRM.IRMConfig(0.001e9, 1e9, 1e9, 1e9);
        configs2[2] = IIRM.IRMConfig(0.001e9, 1e9, 1e9, 1e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        IOmniPool.MarketConfiguration memory mconfig =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, type(uint32).max, 0, false);
        IOmniPool.MarketConfiguration memory mconfig2 =
            IOmniPool.MarketConfiguration(0.9e9, 0, type(uint32).max, 2, true);
        pool.setMarketConfiguration(address(oToken), mconfig);
        pool.setMarketConfiguration(address(oToken3), mconfig2);
        irm.setIRMForMarket(address(oToken), tranches, configs2);

        vm.startPrank(ALICE);
        oToken.deposit(0, 2, 10000e18);
        vm.stopPrank();

        oToken.deposit(0, 2, 100e18);
        oToken3.deposit(1, 1000e18);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.enterMarkets(1, markets);
        pool.enterIsolatedMarket(1, address(oToken3));

        pool.borrow(0, address(oToken), 50e18);
        pool.borrow(1, address(oToken), 50e18);

        vm.warp(730 days);
        vm.startPrank(ALICE);
        pool.liquidate(
            IOmniPool.LiquidationParams(
                address(this).toAccount(0), address(ALICE).toAccount(0), address(oToken), address(oToken), 10e18
            )
        );
        assertEq(pool.pauseTranche(), 0, "pauseTranche is incorrect liq 1");
        pool.liquidate(
            IOmniPool.LiquidationParams(
                address(this).toAccount(1), address(ALICE).toAccount(0), address(oToken), address(oToken3), 10e18
            )
        );
        assertEq(pool.pauseTranche(), 0, "pauseTranche is incorrect liq 2");
        vm.stopPrank();
    }

    function test_RepayWhenPaused() public {
        oToken.deposit(0, 2, 100e18);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 50e18);
        pool.pause();
        assertEq(pool.paused(), true, "paused is incorrect");
        pool.repay(0, address(oToken), 50e18);
        OmniToken.OmniTokenTranche memory tranche = _getOmniTokenTranche(address(oToken), 0);
        assertEq(tranche.totalBorrowAmount, 0, "totalBorrowAmount is incorrect");
        assertEq(tranche.totalBorrowShare, 0, "totalBorrowShare is incorrect");
    }

    function test_RevertIsolatedMarketNotIsolated() public {
        vm.expectRevert("OmniPool::enterIsolatedMarket: Isolated market invalid.");
        IOmniPool(pool).enterIsolatedMarket(0, address(oToken));
    }

    function test_RevertIsolatedMarketExistingBorrow() public {
        oToken.deposit(0, 0, 1000e18);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 1e18);
        vm.expectRevert("OmniPool::enterIsolatedMarket: Non-zero borrow count.");
        pool.enterIsolatedMarket(0, address(oToken3));
    }

    function test_RevertIsolatedMarketExpired() public {
        vm.warp(8 days);
        vm.expectRevert("OmniPool::enterIsolatedMarket: Isolated market invalid.");
        IOmniPool(pool).enterIsolatedMarket(0, address(oToken3));
    }

    function test_RevertAlreadyInIsolated() public {
        pool.enterIsolatedMarket(0, address(oToken3));
        vm.expectRevert("OmniPool::enterIsolatedMarket: Already has isolated collateral.");
        pool.enterIsolatedMarket(0, address(oToken4));

        vm.startPrank(ALICE);
        pool.enterMode(0, 1);
        vm.expectRevert("OmniPool::enterIsolatedMarket: Already in a mode.");
        pool.enterIsolatedMarket(0, address(oToken3));
        vm.stopPrank();
    }

    function test_RevertEnterMarkets() public {
        address[] memory marketsIsolated = new address[](1);
        marketsIsolated[0] = address(oToken3);
        vm.expectRevert("OmniPool::enterMarkets: Market invalid.");
        pool.enterMarkets(0, marketsIsolated);

        pool.enterMode(0, 1);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        vm.expectRevert("OmniPool::enterMarkets: Already in a mode.");
        pool.enterMarkets(0, markets);

        vm.startPrank(ALICE);
        pool.enterMarkets(0, markets);
        vm.expectRevert("OmniPool::enterMarkets: Already in the market.");
        pool.enterMarkets(0, markets);
        vm.stopPrank();

        uint256 supplyCap = 1e7 * (10 ** uToken3.decimals());
        OmniTokenNoBorrow onbToken = new OmniTokenNoBorrow();
        onbToken.initialize(address(pool), address(uToken3), supplyCap);
        IOmniPool.MarketConfiguration memory mConfig1 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 1000 days), 0, false);
        pool.setMarketConfiguration(address(onbToken), mConfig1);

        vm.startPrank(ALICE);
        markets[0] = address(onbToken);
        vm.expectRevert(); // Reverts because function doesn't exist on non-borrowable markets
        pool.enterMarkets(0, markets);
        vm.stopPrank();

        vm.startPrank(BOB);
        vm.warp(1200 days);
        vm.expectRevert("OmniPool::enterMarkets: Market invalid.");
        pool.enterMarkets(0, markets);
    }

    function test_RevertEnterMarketsTooMany() public {
        uint256 length = 10;
        address[] memory newMarkets = new address[](length);

        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e9 * (10 ** uToken.decimals());
        borrowCaps[1] = 1e3 * (10 ** uToken.decimals());
        borrowCaps[2] = 1e2 * (10 ** uToken.decimals());

        for (uint256 i; i < length; ++i) {
            OmniToken oooToken = new OmniToken();
            oooToken.initialize(address(pool), address(uToken), address(irm), borrowCaps);
            IOmniPool.MarketConfiguration memory mConfig1 =
                IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 1000 days), 0, false);
            pool.setMarketConfiguration(address(oooToken), mConfig1);
            newMarkets[i] = address(oooToken);
        }
        test_SetLiquidationBonus();
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.01e9, 1e9, 1e9, 1e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        irm.setIRMForMarket(address(oToken), tranches, configs);
        oToken.deposit(0, 2, 1e2 * 1e18);
        vm.startPrank(ALICE);

        oToken.deposit(0, 0, 0.1e2 * 1e18);
        oToken.deposit(0, 1, 0.1e2 * 1e18);
        oToken.deposit(0, 2, 0.8e2 * 1e18);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        pool.borrow(0, address(oToken), 0.9216e2 * 1e18);

        vm.stopPrank();
        vm.warp(365 days);

        vm.expectRevert("OmniPool::enterMarkets: Too many markets.");
        pool.enterMarkets(0, newMarkets);
    }

    function test_RevertExitMarket() public {
        pool.enterMode(0, 1);
        vm.expectRevert("OmniPool::exitMarkets: In a mode, need to call exitMode.");
        pool.exitMarket(0, address(oToken));

        vm.startPrank(ALICE);
        vm.expectRevert("OmniPool::exitMarkets: No markets to exit");
        pool.exitMarket(0, address(oToken));

        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        vm.expectRevert("OmniPool::exitMarkets: Market not entered");
        pool.exitMarket(0, address(oToken2));

        oToken.deposit(0, 0, 1000e18);
        pool.borrow(0, address(oToken), 10e18);
        vm.expectRevert("OmniPool::exitMarkets: Non-zero borrow count.");
        pool.exitMarket(0, address(oToken));
    }

    function test_RevertClearMarkets() public {
        pool.enterMode(0, 1);
        vm.expectRevert("OmniPool::clearMarkets: Already in a mode.");
        pool.clearMarkets(0);
        pool.exitMode(0);

        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        oToken.deposit(0, 0, 1000e18);
        pool.borrow(0, address(oToken), 10e18);
        vm.expectRevert("OmniPool::exitMarkets: Non-zero borrow count.");
        pool.exitMarket(0, address(oToken));
    }

    function test_RevertEnterMode() public {
        vm.expectRevert("OmniPool::enterMode: Invalid mode ID.");
        pool.enterMode(0, 3);

        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        vm.expectRevert("OmniPool::enterMode: Non-zero market count.");
        pool.enterMode(0, 1);

        vm.startPrank(ALICE);
        pool.enterMode(0, 1);
        vm.expectRevert("OmniPool::enterMode: Already in a mode.");
        pool.enterMode(0, 1);

        vm.warp(10 days);
        vm.expectRevert("OmniPool::enterMode: Mode expired.");
        pool.enterMode(1, 1);
    }

    function test_RevertEnterModeIsolated() public {
        pool.enterIsolatedMarket(0, address(oToken3));
        vm.expectRevert("OmniPool::enterMode: Non-zero market count.");
        pool.enterMode(0, 1);
    }

    function test_RevertExitMode() public {
        vm.expectRevert("OmniPool::exitMode: Not in a mode.");
        pool.exitMode(0);

        pool.enterMode(0, 1);
        oToken.deposit(0, 0, 1000e18);
        pool.borrow(0, address(oToken), 500e18);
        vm.expectRevert("OmniPool::exitMode: Non-zero borrow count.");
        pool.exitMode(0);
    }

    function test_RevertBorrow() public {
        vm.expectRevert("OmniPool::borrow: Not in pool markets.");
        pool.borrow(0, address(oToken), 10e18);

        vm.prank(ALICE);
        oToken.deposit(0, 0, 1000e18);

        pool.enterMode(0, 1);
        oToken.deposit(0, 2, 10e18);
        vm.expectRevert("OmniPool::borrow: Not healthy after borrow.");
        pool.borrow(0, address(oToken), 100e18);

        vm.startPrank(ALICE);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        oToken3.deposit(0, 1e4 * 1e18);
        vm.warp(8 days);
        vm.expectRevert("OmniPool::borrow: Not healthy after borrow.");
        pool.borrow(0, address(oToken), 1e18);
    }

    function test_RevertBorrowCap() public {
        oToken3.deposit(0, 1e7 * 1e18);
        pool.enterIsolatedMarket(0, address(oToken3));
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        vm.expectRevert("OmniToken::borrow: Borrow cap reached.");
        pool.borrow(0, address(oToken), 1.01e2 * 1e18);
    }

    function test_RevertRepay() public {
        vm.expectRevert("OmniPool::repay: Not in pool markets.");
        pool.repay(0, address(oToken), 10e18);
    }

    function test_RevertLiquidateSocialize() public {
        bytes32 targetAccount = address(this).toAccount(0);
        bytes32 liquidatorAccount = address(ALICE).toAccount(0);
        address badlm = address(oToken2);
        address cm = address(oToken);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        pool.enterMarkets(0, markets);
        vm.expectRevert("OmniPool::liquidate: LiquidateMarket not in pool markets.");
        pool.liquidate(IOmniPool.LiquidationParams(targetAccount, liquidatorAccount, badlm, cm, 1e18));

        address badcm = address(oToken2);
        vm.expectRevert("OmniPool::liquidate: CollateralMarket not available to seize.");
        pool.liquidate(IOmniPool.LiquidationParams(targetAccount, liquidatorAccount, cm, badcm, 1e18));

        vm.expectRevert("OmniPool::liquidate: CollateralMarket not available to seize.");
        pool.liquidate(IOmniPool.LiquidationParams(targetAccount, liquidatorAccount, cm, address(oToken3), 1e18));

        vm.expectRevert("OmniPool::liquidate: No borrow to liquidate.");
        pool.liquidate(IOmniPool.LiquidationParams(targetAccount, liquidatorAccount, cm, cm, 1e18));

        oToken.deposit(0, 2, 5e18);
        oToken.deposit(0, 0, 50e18);
        pool.borrow(0, address(oToken), 10e18);
        vm.expectRevert("OmniPool::liquidate: Account still healthy.");
        pool.liquidate(IOmniPool.LiquidationParams(targetAccount, liquidatorAccount, cm, cm, 1e18));

        vm.startPrank(ALICE);
        pool.enterIsolatedMarket(0, address(oToken4));
        pool.enterMarkets(0, markets);
        oToken4.deposit(0, 250e18);
        pool.borrow(0, address(oToken), 5e18);
        vm.stopPrank();

        bytes32 targetAccount2 = address(ALICE).toAccount(0);
        bytes32 liquidatorAccount2 = address(this).toAccount(0);
        vm.expectRevert("OmniPool::liquidate: Account still healthy.");
        pool.liquidate(
            IOmniPool.LiquidationParams(targetAccount2, liquidatorAccount2, address(oToken), address(oToken4), 1e18)
        );

        vm.warp(365 days);
        vm.expectRevert("OmniPool::liquidate: Too much has been liquidated.");
        pool.liquidate(
            IOmniPool.LiquidationParams(targetAccount2, liquidatorAccount2, address(oToken), address(oToken4), 5e18)
        );

        vm.expectRevert(
            "OmniPool::socializeLoss: Account not fully liquidated, please call liquidate prior to fully liquidate account."
        );
        pool.socializeLoss(address(oToken), targetAccount2);
    }

    function test_RevertBadRoleConfigurator() public {
        vm.startPrank(ALICE);
        vm.expectRevert();
        pool.setReserveReceiver(ALICE);

        uint256[] memory caps = new uint256[](3);
        caps[0] = 1e8 * 10e18;
        caps[1] = 1e7 * 10e18;
        caps[2] = 1e6 * 10e18;
        vm.expectRevert();
        pool.setBorrowCap(address(oToken), caps);

        vm.expectRevert();
        pool.setNoBorrowSupplyCap(address(oToken3), 1e2 * 1e18);

        IOmniPool.LiquidationBonusConfiguration memory lbconfig =
            IOmniPool.LiquidationBonusConfiguration(0.05e9, 0.3e9, 0.2e9, 0.04e9, 1.4e9);
        vm.expectRevert();
        pool.setLiquidationBonusConfiguration(address(oToken3), lbconfig);

        vm.expectRevert();
        pool.setAccountSoftLiquidation(address(this).toAccount(0), 1.3e9);

        vm.expectRevert();
        pool.setModeExpiration(1, uint32(block.timestamp + 1 days));

        IOmniPool.MarketConfiguration memory mConfig1 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 1000 days), 0, false);
        vm.expectRevert();
        pool.setMarketConfiguration(address(oToken), mConfig1);

        vm.expectRevert();
        pool.socializeLoss(address(oToken), address(this).toAccount(0));

        vm.expectRevert();
        pool.resetPauseTranche();

        address[] memory modeMarkets = new address[](2);
        modeMarkets[0] = address(oToken);
        modeMarkets[1] = address(oToken2);
        IOmniPool.ModeConfiguration memory modeStableMode =
            IOmniPool.ModeConfiguration(0.95e9, 0.95e9, 0, uint32(block.timestamp + 7 days), modeMarkets);
        vm.expectRevert();
        pool.setModeConfiguration(modeStableMode);

        vm.stopPrank();
    }

    function test_RevertSetMarketConfiguration() public {
        IOmniPool.MarketConfiguration memory config =
            IOmniPool.MarketConfiguration(0.9e9, 0.8e9, uint32(block.timestamp - 1), 0, false);
        vm.expectRevert("OmniPool::setMarketConfiguration: Bad expiration timestamp.");
        pool.setMarketConfiguration(address(oToken), config);

        IOmniPool.MarketConfiguration memory config2 =
            IOmniPool.MarketConfiguration(0.9e9, 0, uint32(block.timestamp + 1), 0, true);
        vm.expectRevert("OmniPool::setMarketConfiguration: Bad configuration for isolated collateral.");
        pool.setMarketConfiguration(address(oToken), config2);

        IOmniPool.MarketConfiguration memory config3 =
            IOmniPool.MarketConfiguration(0.9e9, 0.8e9, uint32(block.timestamp + 1), 2, true);
        vm.expectRevert("OmniPool::setMarketConfiguration: Bad configuration for isolated collateral.");
        pool.setMarketConfiguration(address(oToken), config3);

        IOmniPool.MarketConfiguration memory config4 =
            IOmniPool.MarketConfiguration(0, 0.8e9, uint32(block.timestamp + 1), 0, false);
        vm.expectRevert("OmniPool::setMarketConfiguration: Invalid configuration for borrowable long tail asset.");
        pool.setMarketConfiguration(address(oToken), config4);

        IOmniPool.MarketConfiguration memory config5 =
            IOmniPool.MarketConfiguration(0, 0, uint32(block.timestamp + 1), type(uint8).max, false);
        vm.expectRevert("OmniPool::setMarketConfiguration: Invalid configuration for borrowable long tail asset.");
        pool.setMarketConfiguration(address(oToken), config5);
    }

    function test_RevertWhenPaused() public {
        vm.expectRevert("Pausable: not paused");
        pool.unpause();

        pool.pause();
        vm.expectRevert("Pausable: paused");
        pool.borrow(0, address(oToken), 10e18);

        vm.expectRevert("Pausable: paused");
        pool.liquidate(
            IOmniPool.LiquidationParams(
                address(this).toAccount(0), address(ALICE).toAccount(0), address(oToken), address(oToken3), 1e18
            )
        );

        vm.expectRevert("Pausable: paused");
        pool.pause();

        pool.unpause();
    }

    function test_RevertEnterMarketsDuplicates() public {
        address[] memory markets = new address[](5);
        markets[0] = address(oToken);
        markets[1] = address(oToken);
        markets[2] = address(oToken);
        markets[3] = address(oToken);
        markets[4] = address(oToken);
        vm.expectRevert("OmniPool::enterMarkets: Already in the market.");
        pool.enterMarkets(0, markets);
    }

    function test_RevertSetModeConfiguration() public {
        IOmniPool.ModeConfiguration memory modeStableMode =
            IOmniPool.ModeConfiguration(0.95e9, 0.95e9, 0, uint32(block.timestamp + 7 days), new address[](0));
        uint32 timeNow = uint32(block.timestamp);
        vm.warp(8 days);
        vm.expectRevert("OmniPool::setModeConfiguration: Bad expiration timestamp.");
        pool.setModeConfiguration(modeStableMode);

        vm.expectRevert("OmniPool::setModeExpiration: Bad expiration timestamp.");
        pool.setModeExpiration(1, timeNow);

        vm.expectRevert("OmniPool::setModeExpiration: Bad mode ID.");
        pool.setModeExpiration(0, uint32(block.timestamp + 1 days));
    }

    function test_RevertBadBorrowCaps() public {
        uint256[] memory caps = new uint256[](3);
        caps[0] = 1e2 * 10e18;
        caps[1] = 1e7 * 10e18;
        caps[2] = 1e6 * 10e18;
        vm.expectRevert("OmniPool::setBorrowCap: Invalid borrow cap.");
        pool.setBorrowCap(address(oToken), caps);

        caps[0] = 1e8 * 10e18;
        caps[1] = 1e7 * 10e18;
        caps[2] = 1e9 * 10e18;
        vm.expectRevert("OmniPool::setBorrowCap: Invalid borrow cap.");
        pool.setBorrowCap(address(oToken), caps);

        caps[0] = 0;
        caps[1] = 1e7 * 10e18;
        caps[2] = 1e6 * 10e18;
        vm.expectRevert("OmniPool::setBorrowCap: Invalid borrow cap.");
        pool.setBorrowCap(address(oToken), caps);
    }

    function _assertEvaluationValues(
        OmniPool.Evaluation memory eval,
        uint256 dtv,
        uint256 btv,
        uint256 dav,
        uint256 bav,
        uint256 nd,
        uint256 nb
    ) internal {
        assertEq(eval.depositTrueValue, dtv, "depositTrueValue is incorrect");
        assertEq(eval.borrowTrueValue, btv, "borrowTrueValue is incorrect");
        assertEq(eval.depositAdjValue, dav, "depositAdjustment is incorrect");
        assertEq(eval.borrowAdjValue, bav, "borrowAdjustment is incorrect");
        assertEq(eval.numDeposit, nd, "numDeposit is incorrect");
        assertEq(eval.numBorrow, nb, "numBorrow is incorrect");
    }

    function _assertTrancheValues(
        address _market,
        uint256 tda0,
        uint256 tda1,
        uint256 tda2,
        uint256 tds0,
        uint256 tds1,
        uint256 tds2,
        uint256 tba0,
        uint256 tba1,
        uint256 tba2,
        uint256 tbs0,
        uint256 tbs1,
        uint256 tbs2
    ) internal {
        {
            OmniToken.OmniTokenTranche memory tranche0 = _getOmniTokenTranche(_market, 0);
            assertEq(tranche0.totalDepositAmount, tda0, "totalDepositAmount is incorrect");
            assertEq(tranche0.totalDepositShare, tds0, "totalDepositShare is incorrect");
            assertEq(tranche0.totalBorrowAmount, tba0, "totalBorrowAmount is incorrect");
            assertEq(tranche0.totalBorrowShare, tbs0, "totalBorrowShare is incorrect");
        }
        {
            OmniToken.OmniTokenTranche memory tranche1 = _getOmniTokenTranche(_market, 1);
            assertEq(tranche1.totalDepositAmount, tda1, "totalDepositAmount is incorrect");
            assertEq(tranche1.totalDepositShare, tds1, "totalDepositShare is incorrect");
            assertEq(tranche1.totalBorrowAmount, tba1, "totalBorrowAmount is incorrect");
            assertEq(tranche1.totalBorrowShare, tbs1, "totalBorrowShare is incorrect");
        }
        {
            OmniToken.OmniTokenTranche memory tranche2 = _getOmniTokenTranche(_market, 2);
            assertEq(tranche2.totalDepositAmount, tda2, "totalDepositAmount is incorrect");
            assertEq(tranche2.totalDepositShare, tds2, "totalDepositShare is incorrect");
            assertEq(tranche2.totalBorrowAmount, tba2, "totalBorrowAmount is incorrect");
            assertEq(tranche2.totalBorrowShare, tbs2, "totalBorrowShare is incorrect");
        }
    }

    function _getOmniTokenTranche(address _market, uint8 _tranche)
        internal
        view
        returns (OmniToken.OmniTokenTranche memory)
    {
        (uint256 totalDeposit, uint256 totalBorrow, uint256 totalDepositShares, uint256 totalBorrowShares) =
            OmniToken(_market).tranches(_tranche);
        return OmniToken.OmniTokenTranche(totalDeposit, totalBorrow, totalDepositShares, totalBorrowShares);
    }

    function _getAccountInfo(bytes32 account) internal view returns (IOmniPool.AccountInfo memory) {
        (uint8 modeId, address isolatedCollateralMarket, uint32 softThreshold) = pool.accountInfos(account);
        return IOmniPool.AccountInfo(modeId, isolatedCollateralMarket, softThreshold);
    }
}
