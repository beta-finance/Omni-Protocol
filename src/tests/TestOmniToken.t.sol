// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./mock/MockERC20.sol";
import "./mock/MockOracle.sol";
import "../IRM.sol";
import "../OmniPool.sol";
import "../OmniToken.sol";
import "../interfaces/IOmniToken.sol";
import "../interfaces/IOmniPool.sol";
import "../SubAccount.sol";

contract TestOmniToken is Test {
    using SubAccount for address;

    address public constant ALICE = address(uint160(uint256(keccak256("alice.eth"))));
    address public constant BOB = address(uint160(uint256(keccak256("bob.eth"))));
    OmniPool pool;
    OmniToken oToken;
    OmniToken oToken2;
    IRM irm;
    MockERC20 uToken;
    MockOracle oracle;

    function setUp() public {
        oracle = new MockOracle();
        irm = new IRM();
        irm.initialize(address(this));
        pool = new OmniPool();
        pool.initialize(address(oracle), ALICE, address(this));
        uToken = new MockERC20('Mock', 'Mock');
        address[] memory underlyings = new address[](1);
        uint256[] memory prices = new uint256[](1);
        underlyings[0] = address(uToken);
        prices[0] = 1e18;
        oracle.setPrices(underlyings, prices);
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e5 * (10 ** uToken.decimals());
        borrowCaps[1] = 1e4 * (10 ** uToken.decimals());
        borrowCaps[2] = 1e2 * (10 ** uToken.decimals());
        oToken = new OmniToken();
        oToken2 = new OmniToken();
        oToken.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        oToken2.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        irm.setIRMForMarket(address(oToken), tranches, configs);
        irm.setIRMForMarket(address(oToken2), tranches, configs);
        uToken.mint(address(this), 1e6 * (10 ** uToken.decimals()));
        uToken.mint(address(ALICE), 1e6 * (10 ** uToken.decimals()));
        uToken.mint(address(BOB), 1e2 * (10 ** uToken.decimals()));
        uToken.approve(address(oToken), type(uint256).max);
        uToken.approve(address(oToken2), type(uint256).max);
        vm.prank(ALICE);
        uToken.approve(address(oToken), type(uint256).max);
        vm.prank(BOB);
        uToken.approve(address(oToken), type(uint256).max);
    }

    function test_Initialize() public {
        uint8 trancheCount = 3;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e5 * (10 ** uToken.decimals());
        borrowCaps[1] = 1e3 * (10 ** uToken.decimals());
        borrowCaps[2] = 1e2 * (10 ** uToken.decimals());
        OmniToken oToken1 = new OmniToken();
        oToken1.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        assertEq(oToken1.omniPool(), address(pool), "omniPool address is incorrect");
        assertEq(oToken1.irm(), address(irm), "irm address is incorrect");
        assertEq(oToken1.underlying(), address(uToken), "underlying address is incorrect");
        assertEq(oToken1.trancheCount(), trancheCount, "trancheCount is incorrect");
        assertEq(oToken1.lastAccrualTime(), block.timestamp, "lastAccrualTime is incorrect");
        assertEq(oToken1.reserveReceiver(), ALICE.toAccount(0), "reserveReceiver is incorrect");
        assertEq(oToken1.trancheBorrowCaps(0), borrowCaps[0], "0 tranche borrowCap is incorrect");
        assertEq(oToken1.trancheBorrowCaps(1), borrowCaps[1], "1 tranche borrowCap is incorrect");
        assertEq(oToken1.trancheBorrowCaps(2), borrowCaps[2], "2 tranche borrowCap is incorrect");
    }

    function test_Deposit() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        uint256 balBefore = uToken.balanceOf(address(this));
        oToken.deposit(0, 0, amount);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(balBefore - balAfter, amount, "underlying balanceOf is incorrect");
        {
            (uint256 tda0, uint256 tba0, uint256 tds0, uint256 tbs0) = oToken.tranches(0);
            assertEq(tda0, amount, "0 tranche totalDeposit is incorrect");
            assertEq(tba0, 0, "0 tranche totalBorrow is incorrect");
            assertEq(tds0, amount, "0 tranche totalDepositScaled is incorrect");
            assertEq(tbs0, 0, "0 tranche totalBorrowScaled is incorrect");
        }
        {
            (uint256 ads0, uint256 abs0) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 0);
            assertEq(ads0, amount, "0 tranche accountDepositShares is incorrect");
            assertEq(abs0, 0, "0 tranche accountBorrowShares is incorrect");
        }
        {
            oToken.deposit(0, 1, amount);
            (uint256 tda1, uint256 tba1, uint256 tds1, uint256 tbs1) = oToken.tranches(1);
            assertEq(tda1, amount, "1 tranche totalDeposit is incorrect");
            assertEq(tba1, 0, "1 tranche totalBorrow is incorrect");
            assertEq(tds1, amount, "1 tranche totalDepositScaled is incorrect");
            assertEq(tbs1, 0, "1 tranche totalBorrowScaled is incorrect");
        }
        {
            (uint256 ads1, uint256 abs1) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 1);
            assertEq(ads1, amount, "1 tranche accountDepositShares is incorrect");
            assertEq(abs1, 0, "1 tranche accountBorrowShares is incorrect");
        }
    }

    function test_DepositMultiUsers() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, 0, amount);
        vm.startPrank(ALICE);
        oToken.deposit(0, 0, amount);
        vm.stopPrank();
        (uint256 tda0, uint256 tba0, uint256 tds0, uint256 tbs0) = oToken.tranches(0);
        assertEq(tda0, amount * 2, "0 tranche totalDeposit is incorrect");
        assertEq(tba0, 0, "0 tranche totalBorrow is incorrect");
        assertEq(tds0, amount * 2, "0 tranche totalDepositShares is incorrect");
        assertEq(tbs0, 0, "0 tranche totalBorrowShares is incorrect");
        (uint256 ads0, uint256 abs0) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 0);
        (uint256 adsA, uint256 absA) = oToken.getAccountSharesByTranche(ALICE.toAccount(0), 0);
        assertEq(ads0, amount, "0 tranche accountDepositShares is incorrect");
        assertEq(abs0, 0, "0 tranche accountBorrowShares is incorrect");
        assertEq(adsA, amount, "0 tranche accountDepositShares Alice is incorrect");
        assertEq(absA, 0, "0 tranche accountBorrowShares Alice is incorrect");
        assertEq(oToken.balanceOf(address(this)), amount, "balanceOf is incorrect");
    }

    function setUpDeposits() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, 0, amount);
        oToken.deposit(0, 1, amount);
        oToken.deposit(0, 2, amount);
        vm.startPrank(ALICE);
        oToken.deposit(0, 0, amount);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        setUpDeposits();
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        uint256 balBefore = uToken.balanceOf(address(this));
        oToken.withdraw(0, 0, amount);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(balAfter - balBefore, amount, "underlying balanceOf is incorrect");
        (uint256 tda0, uint256 tba0, uint256 tds0, uint256 tbs0) = oToken.tranches(0);
        assertEq(tda0, amount, "0 tranche totalDeposit is incorrect");
        assertEq(tba0, 0, "0 tranche totalBorrow is incorrect");
        assertEq(tds0, amount, "0 tranche totalDepositScaled is incorrect");
        assertEq(tbs0, 0, "0 tranche totalBorrowScaled is incorrect");

        vm.startPrank(ALICE);
        uint256 balBeforeA = uToken.balanceOf(ALICE);
        oToken.withdraw(0, 0, 0);
        uint256 balAfterA = uToken.balanceOf(ALICE);
        assertEq(balAfterA - balBeforeA, amount, "underlying balanceOf Alice is incorrect");
        (uint256 tdaA, uint256 tbaA, uint256 tdsA, uint256 tbsA) = oToken.tranches(0);
        assertEq(tdaA, 0, "0 tranche totalDeposit Alice is incorrect");
        assertEq(tbaA, 0, "0 tranche totalBorrow Alice is incorrect");
        assertEq(tdsA, 0, "0 tranche totalDepositScaled Alice is incorrect");
        assertEq(tbsA, 0, "0 tranche totalBorrowScaled Alice is incorrect");
    }

    function setUpBorrow() public {
        setUpDeposits();
        address[] memory markets = new address[](1);
        markets[0] = address(oToken);
        IOmniPool.MarketConfiguration memory config =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 10000 days), 0, false);
        pool.setMarketConfiguration(address(oToken), config);
        pool.enterMarkets(0, markets);
        IOmniPool.MarketConfiguration memory config2 =
            IOmniPool.MarketConfiguration(0.9e9, 0, uint32(block.timestamp + 10000 days), 1, true);
        pool.setMarketConfiguration(address(oToken2), config2);
        pool.enterMarkets(1, markets);
        pool.enterIsolatedMarket(1, address(oToken2));
    }

    function test_Borrow() public {
        setUpBorrow();
        uint256 borrowAmount = 10 * (10 ** uToken.decimals());
        (uint256 tda0, uint256 tba0, uint256 tds0,) = oToken.tranches(0);
        uint256 balBefore = uToken.balanceOf(address(this));
        IOmniPool(pool).borrow(0, address(oToken), borrowAmount);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(balAfter - balBefore, borrowAmount, "underlying balanceOf is incorrect");

        (uint256 tda0After, uint256 tba0After, uint256 tds0After, uint256 tbs0After) = oToken.tranches(0);
        assertEq(tda0After, tda0, "0 tranche totalDeposit is incorrect");
        assertEq(tba0After, tba0 + borrowAmount, "0 tranche totalBorrow is incorrect");
        assertEq(tds0After, tds0, "0 tranche totalDepositScaled is incorrect");
        assertEq(tbs0After, borrowAmount, "0 tranche totalBorrowScaled is incorrect");
    }

    function test_Repay() public {
        setUpBorrow();
        uint256 borrowAmount = 10 * (10 ** uToken.decimals());
        IOmniPool(pool).borrow(0, address(oToken), borrowAmount);
        vm.warp(1 days);
        uint256 repayAmount = 5 * (10 ** uToken.decimals());
        uint256 balBefore = uToken.balanceOf(address(this));
        (, uint256 tba0,, uint256 tbs0) = oToken.tranches(0);
        (, uint256 abs0) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 0);
        IOmniPool(pool).repay(0, address(oToken), repayAmount);
        (, uint256 tba0After,, uint256 tbs0After) = oToken.tranches(0);
        (, uint256 abs0After) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 0);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(balBefore - balAfter, repayAmount, "underlying balanceOf is incorrect");
        uint256 shares = repayAmount * tbs0 / tba0;
        assertApproxEqRel(tba0After, tba0 - repayAmount, 0.0001e18, "0 tranche totalBorrow is incorrect");
        assertApproxEqRel(tbs0After, tbs0 - shares, 0.0001e18, "0 tranche totalBorrowScaled is incorrect");
        assertApproxEqRel(abs0After, abs0 - shares, 0.0001e18, "0 tranche accountBorrowShares is incorrect");

        IOmniPool(pool).repay(0, address(oToken), 0); // Repay full amount
        (, uint256 tba0After2,, uint256 tbs0After2) = oToken.tranches(0);
        (, uint256 abs0After2) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 0);
        assertEq(tba0After2, 0, "0 tranche totalBorrow is incorrect");
        assertEq(tbs0After2, 0, "0 tranche totalBorrowScaled is incorrect");
        assertEq(abs0After2, 0, "0 tranche accountBorrowShares is incorrect");
    }

    function test_Accrue() public {
        setUpBorrow();
        (uint256 tda0, uint256 tba0,,) = oToken.tranches(0);
        (uint256 tda1, uint256 tba1,,) = oToken.tranches(1);
        (uint256 tda2, uint256 tba2,,) = oToken.tranches(2);
        uint256 td = tda0 + tda1 + tda2;

        uint256 borrowAmount = 10 * (10 ** uToken.decimals());
        IOmniPool(pool).borrow(0, address(oToken), borrowAmount);

        vm.warp(1 days);

        uint256 interestAmount;
        {
            uint256 interestRate = irm.getInterestRate(address(oToken), 0, td, borrowAmount);
            interestAmount = borrowAmount * interestRate * 1 days / 365 days / oToken.IRM_SCALE();
        }
        uint256 feeInterestAmount = interestAmount * oToken.RESERVE_FEE() / oToken.FEE_SCALE();
        interestAmount -= feeInterestAmount;

        oToken.accrue();

        {
            (uint256 tda0After, uint256 tba0After,,) = oToken.tranches(0);
            assertApproxEqRel(
                tda0After,
                tda0 + feeInterestAmount + interestAmount * tda0 / td,
                0.0001e18,
                "0 tranche totalDeposit is incorrect"
            );
            assertApproxEqRel(
                tba0After,
                tba0 + borrowAmount + interestAmount + feeInterestAmount,
                0.0001e18,
                "0 tranche totalBorrow is incorrect"
            );
        }
        {
            (uint256 tda1After, uint256 tba1After,,) = oToken.tranches(1);
            assertApproxEqRel(
                tda1After, tda1 + interestAmount * tda1 / td, 0.0001e18, "1 tranche totalDeposit is incorrect"
            );
            assertEq(tba1After, tba1, "1 tranche totalBorrow is incorrect");
        }
        (uint256 tda2After, uint256 tba2After,,) = oToken.tranches(2);
        assertApproxEqRel(
            tda2After, tda2 + interestAmount * tda2 / td, 0.0001e18, "2 tranche totalDeposit is incorrect"
        );
        assertEq(tba2After, tba2, "2 tranche totalBorrow is incorrect");
    }

    function test_AccrueMultiple() public {
        setUpBorrow();
        (uint256 tda0,,,) = oToken.tranches(0);
        (uint256 tda1,,,) = oToken.tranches(1);
        (uint256 tda2,,,) = oToken.tranches(2);
        uint256 td = tda0 + tda1 + tda2;

        uint256 borrowAmount = 10 * (10 ** uToken.decimals());
        IOmniPool(pool).borrow(0, address(oToken), borrowAmount);

        oToken2.deposit(1, 0, 1e4 * (10 ** uToken.decimals()));
        IOmniPool(pool).borrow(1, address(oToken), borrowAmount);

        vm.warp(100 days);

        uint256 interestAmount;
        {
            uint256 interestRate = irm.getInterestRate(address(oToken), 0, td, borrowAmount);
            interestAmount = borrowAmount * interestRate * 100 days / 365 days / oToken.IRM_SCALE();
        }
        uint256 feeInterestAmount = interestAmount * oToken.RESERVE_FEE() / oToken.FEE_SCALE();
        interestAmount -= feeInterestAmount;
        oToken.accrue();

        {
            (uint256 tda0After, uint256 tba0After,,) = oToken.tranches(0);
            assertEq(tda0After, 200017161336095925798, "0 tranche totalDeposit is incorrect");
            assertEq(tba0After, 10031202429265319632, "0 tranche totalBorrow is incorrect");
        }
        {
            (uint256 tda1After, uint256 tba1After,,) = oToken.tranches(1);
            assertEq(tda1After, 100042475819330391979, "1 tranche totalDeposit is incorrect");
            assertEq(tba1After, 10064464132264900113, "1 tranche totalBorrow is incorrect");
        }
        (uint256 tda2After, uint256 tba2After,,) = oToken.tranches(2);
        assertEq(tda2After, 100036029406103901968, "2 tranche totalDeposit is incorrect");
        assertEq(tba2After, 0, "2 tranche totalBorrow is incorrect");
    }

    function test_Transfer() public {
        test_AccrueMultiple();
        bytes32 toAlice3 = ALICE.toAccount(3);
        bytes32 fromThis0 = address(this).toAccount(0);
        (uint256 sharesBefore,) = oToken.getAccountSharesByTranche(fromThis0, 0);
        oToken.transfer(0, toAlice3, 0, 10 * 1e18);
        (uint256 toAds,) = oToken.getAccountSharesByTranche(toAlice3, 0);
        assertEq(toAds, 10 * 1e18, "toAlice3 accountDepositShares is incorrect");
        (uint256 sharesAfter,) = oToken.getAccountSharesByTranche(fromThis0, 0);
        assertEq(sharesAfter, sharesBefore - 10e18, "fromThis0 accountDepositShares is incorrect");
    }

    function test_SetTrancheBorrowCaps() public {
        vm.startPrank(address(pool));
        uint256[] memory caps = new uint256[](3);
        caps[0] = 1e6 * (10 ** uToken.decimals());
        caps[1] = 1e5 * (10 ** uToken.decimals());
        caps[2] = 1e3 * (10 ** uToken.decimals());
        oToken.setTrancheBorrowCaps(caps);
        assertEq(oToken.trancheBorrowCaps(0), caps[0], "0 tranche borrowCap is incorrect");
        assertEq(oToken.trancheBorrowCaps(1), caps[1], "1 tranche borrowCap is incorrect");
        assertEq(oToken.trancheBorrowCaps(2), caps[2], "2 tranche borrowCap is incorrect");
    }

    function test_SetTrancheCount() public {
        vm.startPrank(address(pool));
        uint8 trancheCount = 4;
        oToken.setTrancheCount(trancheCount);
        assertEq(oToken.trancheCount(), trancheCount, "trancheCount is incorrect");
        (uint256 tda3, uint256 tba3, uint256 tds3, uint256 tbs3) = oToken.tranches(3);
        assertEq(tda3, 0, "3 tranche totalDepositAmount is incorrect");
        assertEq(tba3, 0, "3 tranche totalBorrowAmount is incorrect");
        assertEq(tds3, 0, "3 tranche totalDepositShares is incorrect");
        assertEq(tbs3, 0, "3 tranche totalBorrowShares is incorrect");
    }

    function test_FetchReserveReceiver() public {
        IOmniPool(pool).setReserveReceiver(BOB);
        oToken.fetchReserveReceiver();
        assertEq(oToken.reserveReceiver(), BOB.toAccount(0), "reserveReceiver is incorrect");
    }

    function test_RevertDepositTrancheInvalid() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        uint8 trancheCount = oToken.trancheCount();
        vm.expectRevert("OmniToken::deposit: Invalid tranche id.");
        oToken.deposit(0, trancheCount, amount);
    }

    function test_RevertWithdrawTrancheInvalid() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        uint8 trancheCount = oToken.trancheCount();
        vm.expectRevert("OmniToken::withdraw: Invalid tranche id.");
        oToken.withdraw(0, trancheCount, amount);
    }

    function test_RevertWithdrawInsufficientAndUnhealthy() public {
        setUpBorrow();
        uint256 borrowAmount = 2.5e2 * (10 ** uToken.decimals());
        (uint256 ads1,) = oToken.getAccountSharesByTranche(address(this).toAccount(0), 1);
        IOmniPool(pool).borrow(0, address(oToken), borrowAmount);

        vm.expectRevert("OmniToken::withdraw: Not healthy.");
        oToken.withdraw(0, 1, ads1);

        (uint256 ads1Alice,) = oToken.getAccountSharesByTranche(ALICE.toAccount(0), 1);
        vm.prank(ALICE);
        oToken.withdraw(0, 0, ads1Alice);
        vm.expectRevert("OmniToken::withdraw: Insufficient withdrawals available.");
        oToken.withdraw(0, 1, ads1);
    }

    function test_RevertBorrowBadCaller() public {
        setUpBorrow();
        uint256 borrowAmount = 10 * (10 ** uToken.decimals());
        vm.expectRevert("OmniToken::borrow: Bad caller.");
        oToken.borrow(address(this).toAccount(0), 0, borrowAmount);
    }

    function test_RevertBorrowInvalidAllocation() public {
        setUpBorrow();
        vm.startPrank(address(pool));
        uint256 borrowAmount = 1e3 * (10 ** uToken.decimals());
        bytes32 account = address(this).toAccount(0);
        vm.expectRevert("OmniToken::borrow: Invalid borrow allocation.");
        oToken.borrow(account, 0, borrowAmount);
        vm.stopPrank();
    }

    function test_RevertBorrowTooMuch() public {
        setUpBorrow();
        vm.startPrank(address(pool));
        uint256 borrowAmount = 1e10 * (10 ** uToken.decimals());
        bytes32 account = address(this).toAccount(0);
        vm.expectRevert("OmniToken::borrow: Borrow cap reached.");
        oToken.borrow(account, 0, borrowAmount);
        vm.stopPrank();
    }

    function test_RevertRepayBadCaller() public {
        uint256 repayAmount = 10 * (10 ** uToken.decimals());
        bytes32 account = address(this).toAccount(0);
        vm.expectRevert("OmniToken::repay: Bad caller.");
        oToken.repay(account, address(this), 0, repayAmount);
    }

    function test_RevertSeizeSocializeBadCaller() public {
        bytes32 account1 = address(this).toAccount(0);
        bytes32 account2 = address(this).toAccount(1);
        uint256 amount = 10 * (10 ** uToken.decimals());
        vm.expectRevert("OmniToken::seize: Bad caller");
        oToken.seize(account1, account2, amount);

        vm.expectRevert("OmniToken::socializeLoss: Bad caller");
        oToken.socializeLoss(account1, 0);
    }

    function test_RevertBorrowCapsTrancheBadCaller() public {
        uint256[] memory caps = new uint256[](3);
        caps[0] = 1e6 * (10 ** uToken.decimals());
        caps[1] = 1e5 * (10 ** uToken.decimals());
        caps[2] = 1e3 * (10 ** uToken.decimals());
        vm.expectRevert("OmniToken::setTrancheBorrowCaps: Bad caller.");
        oToken.setTrancheBorrowCaps(caps);

        vm.expectRevert("OmniToken::setTrancheCount: Bad caller.");
        oToken.setTrancheCount(4);
    }

    function test_RevertBorrowCapsBadLength() public {
        uint256[] memory caps = new uint256[](2);
        caps[0] = 1e6 * (10 ** uToken.decimals());
        caps[1] = 1e3 * (10 ** uToken.decimals());
        vm.startPrank(address(pool));
        vm.expectRevert("OmniToken::setTrancheBorrowCaps: Invalid borrow caps length.");
        oToken.setTrancheBorrowCaps(caps);
        vm.stopPrank();
    }

    function test_RevertTrancheCaps0() public {
        uint256[] memory caps = new uint256[](3);
        caps[0] = 0;
        caps[1] = 1e5 * (10 ** uToken.decimals());
        caps[2] = 1e3 * (10 ** uToken.decimals());
        vm.startPrank(address(pool));
        vm.expectRevert("OmniToken::setTrancheBorrowCaps: Invalid borrow caps, must always allow 0 to borrow.");
        oToken.setTrancheBorrowCaps(caps);
        vm.stopPrank();
    }

    function test_RevertTrancheCountMustIncrease() public {
        vm.startPrank(address(pool));
        vm.expectRevert("OmniToken::setTrancheCount: Invalid tranche count.");
        oToken.setTrancheCount(5);

        vm.expectRevert("OmniToken::setTrancheCount: Invalid tranche count.");
        oToken.setTrancheCount(2);
    }

    function test_RevertTransferNotHealthy() public {
        test_AccrueMultiple();
        bytes32 toAlice3 = ALICE.toAccount(3);
        oToken.transfer(0, toAlice3, 0, 100 * 1e18);
        oToken.transfer(0, toAlice3, 1, 100 * 1e18);
        vm.expectRevert("OmniToken::transfer: Not healthy.");
        oToken.transfer(0, toAlice3, 2, 100 * 1e18);
    }
}
