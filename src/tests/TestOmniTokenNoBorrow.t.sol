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
import "../interfaces/IOmniTokenNoBorrow.sol";
import "../SubAccount.sol";

contract TestOmniTokenNoBorrow is Test {
    using SubAccount for address;

    address public constant ALICE = address(uint160(uint256(keccak256("alice.eth"))));
    address public constant BOB = address(uint160(uint256(keccak256("bob.eth"))));
    OmniPool pool;
    OmniTokenNoBorrow oToken;
    OmniToken oToken2;
    MockERC20 uToken;
    MockOracle oracle;

    function setUp() public {
        oracle = new MockOracle();
        pool = new OmniPool();
        pool.initialize(address(oracle), ALICE, address(this));
        uToken = new MockERC20('Mock', 'Mock');
        address[] memory underlyings = new address[](1);
        uint256[] memory prices = new uint256[](1);
        underlyings[0] = address(uToken);
        prices[0] = 1e18;
        oracle.setPrices(underlyings, prices);
        uToken.mint(address(this), 5e6 * (10 ** uToken.decimals()));
        uToken.mint(address(ALICE), 5e6 * (10 ** uToken.decimals()));
        uToken.mint(address(BOB), 1e2 * (10 ** uToken.decimals()));
        uint256 supplyCap = 2e6 * (10 ** uToken.decimals());
        oToken = new OmniTokenNoBorrow();
        oToken.initialize(address(pool), address(uToken), supplyCap);
        IIRM.IRMConfig[] memory configs = new IIRM.IRMConfig[](3);
        configs[0] = IIRM.IRMConfig(0.9e9, 0.01e9, 0.035e9, 0.635e9);
        configs[1] = IIRM.IRMConfig(0.85e9, 0.02e9, 0.08e9, 1e9);
        configs[2] = IIRM.IRMConfig(0.8e9, 0.03e9, 0.1e9, 1.2e9);
        uint8[] memory tranches = new uint8[](3);
        tranches[0] = 0;
        tranches[1] = 1;
        tranches[2] = 2;
        uint256[] memory borrowCaps = new uint256[](3);
        borrowCaps[0] = 1e7 * (10 ** uToken.decimals());
        borrowCaps[1] = 1e7 * (10 ** uToken.decimals());
        borrowCaps[2] = 1e7 * (10 ** uToken.decimals());
        IRM irm = new IRM();
        irm.initialize(address(this));
        oToken2 = new OmniToken();
        oToken2.initialize(address(pool), address(uToken), address(irm), borrowCaps);
        irm.setIRMForMarket(address(oToken2), tranches, configs);
        uToken.approve(address(oToken), type(uint256).max);
        uToken.approve(address(oToken2), type(uint256).max);
        vm.startPrank(ALICE);
        uToken.approve(address(oToken), type(uint256).max);
        uToken.approve(address(oToken2), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(BOB);
        uToken.approve(address(oToken), type(uint256).max);
        uToken.approve(address(oToken2), type(uint256).max);
        vm.stopPrank();
    }

    function test_Initialize() public {
        OmniTokenNoBorrow oToken1 = new OmniTokenNoBorrow();
        oToken1.initialize(address(pool), address(uToken), 1e3 * (10 ** uToken.decimals()));
        assertEq(oToken1.omniPool(), address(pool), "omniPool address is incorrect");
        assertEq(oToken1.underlying(), address(uToken), "underlying address is incorrect");
        assertEq(oToken1.supplyCap(), 1e3 * (10 ** uToken.decimals()), "supplyCap is incorrect");
    }

    function test_DepositAndInflow() public {
        uint256 balBefore = uToken.balanceOf(address(this));
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);
        assertEq(oToken.totalSupply(), amount, "totalSupply is incorrect");
        assertEq(oToken.balanceOfAccount(address(this).toAccount(0)), amount, "balanceOfAccount is incorrect");
        assertEq(uToken.balanceOf(address(this)), balBefore - amount, "underlying balanceOf is incorrect");
        assertEq(oToken.balanceOf(address(this)), amount, "balanceOf is incorrect");

        vm.startPrank(ALICE);
        uint256 balBeforeA = uToken.balanceOf(ALICE);
        oToken.deposit(1, amount);
        assertEq(oToken.totalSupply(), amount * 2, "Alice totalSupply is incorrect");
        assertEq(oToken.balanceOfAccount(ALICE.toAccount(1)), amount, "Alice balanceOfAccount is incorrect");
        assertEq(uToken.balanceOf(ALICE), balBeforeA - amount, "Alice underlying balanceOf is incorrect");
    }

    function setUp_Borrow() public {
        oToken2.deposit(3, 2, 1e6 * (10 ** uToken.decimals()));
        oToken.deposit(1, 1e6 * (10 ** uToken.decimals()));
        IOmniPool.MarketConfiguration memory config =
            IOmniPool.MarketConfiguration(0.9e9, 0, uint32(block.timestamp + 10000 days), 2, true);
        pool.setMarketConfiguration(address(oToken), config);
        pool.enterIsolatedMarket(1, address(oToken));
        IOmniPool.MarketConfiguration memory config2 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 10000 days), 0, false);
        pool.setMarketConfiguration(address(oToken2), config2);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken2);
        pool.enterMarkets(1, markets);

        pool.borrow(1, address(oToken2), 8e23);
    }

    function test_WithdrawWithBorrows() public {
        setUp_Borrow();
        uint256 balBefore = uToken.balanceOf(address(this));
        oToken.withdraw(1, 10e18);
        uint256 balAfter = uToken.balanceOf(address(this));
        assertEq(balAfter - balBefore, 10e18, "underlying balanceOf is incorrect");
    }

    function test_WithdrawNoBorrows() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);

        uint256 balBefore = uToken.balanceOf(address(this));
        oToken.withdraw(0, amount / 2);
        assertEq(oToken.totalSupply(), amount - amount / 2, "totalSupply is incorrect");
        assertEq(
            oToken.balanceOfAccount(address(this).toAccount(0)), amount - amount / 2, "balanceOfAccount is incorrect"
        );
        assertEq(uToken.balanceOf(address(this)), balBefore + amount / 2, "underlying balanceOf is incorrect");

        oToken.withdraw(0, 0); // 0 withdraws maximum amount
        assertEq(oToken.totalSupply(), 0, "2 totalSupply is incorrect");
        assertEq(oToken.balanceOfAccount(address(this).toAccount(0)), 0, "2 balanceOfAccount is incorrect");
        assertEq(uToken.balanceOf(address(this)), balBefore + amount, "2 underlying balanceOf is incorrect");
    }

    function test_Seize() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);
        bytes32 badAccount = address(this).toAccount(0);
        bytes32 alice0 = ALICE.toAccount(0);
        assertEq(oToken.balanceOfAccount(badAccount), amount, "balanceOfAccount before is incorrect");
        assertEq(oToken.balanceOfAccount(alice0), 0, "balanceOfAccount before is incorrect");
        vm.startPrank(address(pool));
        uint256[] memory seizedShares = oToken.seize(badAccount, alice0, amount);
        vm.stopPrank();
        assertEq(oToken.totalSupply(), amount, "totalSupply is incorrect");
        assertEq(seizedShares[0], amount, "seizedShares is incorrect");
        assertEq(oToken.getAccountDepositInUnderlying(badAccount), 0, "balanceOfAccount is incorrect");
        assertEq(oToken.getAccountDepositInUnderlying(alice0), amount, "balanceOfAccount is incorrect");
    }

    function test_SeizeOver() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);
        bytes32 badAccount = address(this).toAccount(0);
        bytes32 alice0 = ALICE.toAccount(0);
        assertEq(oToken.balanceOfAccount(badAccount), amount, "balanceOfAccount before is incorrect");
        assertEq(oToken.balanceOfAccount(alice0), 0, "balanceOfAccount before is incorrect");
        vm.startPrank(address(pool));
        uint256[] memory seizedShares = oToken.seize(badAccount, alice0, amount * 2);
        vm.stopPrank();
        assertEq(oToken.totalSupply(), amount, "totalSupply is incorrect");
        assertEq(seizedShares[0], amount, "seizedShares is incorrect");
        assertEq(oToken.getAccountDepositInUnderlying(badAccount), 0, "balanceOfAccount is incorrect");
        assertEq(oToken.getAccountDepositInUnderlying(alice0), amount, "balanceOfAccount is incorrect");
    }

    function test_SetSupplyCap() public {
        vm.startPrank(address(pool));
        oToken.setSupplyCap(1e6 * (10 ** uToken.decimals()));
        vm.stopPrank();

        oToken.deposit(0, 1e6 * (10 ** uToken.decimals()));
    }

    function test_Transfer() public {
        test_DepositAndInflow();
        bytes32 toBob5 = BOB.toAccount(5);
        vm.startPrank(ALICE);
        bytes32 fromAlice1 = ALICE.toAccount(1);
        uint256 balBefore = oToken.balanceOfAccount(fromAlice1);
        oToken.transfer(1, toBob5, 100e18);
        assertEq(oToken.balanceOfAccount(toBob5), 100e18, "balanceOfAccount is incorrect");
        assertEq(oToken.balanceOfAccount(fromAlice1), balBefore - 100e18, "balanceOfAccount is incorrect");
    }

    function test_TransferWithBorrow() public {
        setUp_Borrow();
        bytes32 toBob5 = BOB.toAccount(5);
        bytes32 fromThis1 = address(this).toAccount(1);
        uint256 balAccountBefore = oToken.balanceOfAccount(fromThis1);
        oToken.transfer(1, toBob5, 10e18);
        assertEq(oToken.balanceOfAccount(toBob5), 10e18, "balanceOfAccount is incorrect");
        assertEq(oToken.balanceOfAccount(fromThis1), balAccountBefore - 10e18, "balanceOfAccount is incorrect");
    }

    function test_RevertDepositSupplyCap() public {
        uint256 amount = 3e6 * (10 ** uToken.decimals());
        vm.expectRevert("OmniTokenNoBorrow::deposit: Supply cap exceeded.");
        oToken.deposit(0, amount);
    }

    function test_RevertDepositBadInflow() public {
        uint256 amount = 1e7 * (10 ** uToken.decimals());
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        oToken.deposit(0, amount);
    }

    function test_RevertWithdrawBadOutflow() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);
        vm.expectRevert(); // Underflow error due to insufficient balance
        oToken.withdraw(0, amount + 1);
    }

    function test_RevertSeizeBadCaller() public {
        uint256 amount = 1e2 * (10 ** uToken.decimals());
        oToken.deposit(0, amount);
        bytes32 badAccount = address(this).toAccount(0);
        bytes32 alice0 = ALICE.toAccount(0);
        vm.expectRevert("OmniTokenNoBorrow::seize: Bad caller.");
        oToken.seize(badAccount, alice0, amount);
    }

    function test_RevertSetSupplyCapBadCaller() public {
        uint256 cap = 3e6 * (10 ** uToken.decimals());
        vm.expectRevert("OmniTokenNoBorrow::setSupplyCap: Bad caller.");
        oToken.setSupplyCap(cap);
    }

    function test_RevertTransferNotHealthy() public {
        setUp_Borrow();
        bytes32 toBob5 = BOB.toAccount(5);
        vm.expectRevert("OmniTokenNoBorrow::transfer: Not healthy.");
        oToken.transfer(1, toBob5, 2e23);
    }

    function test_RevertWithdrawNotHealthy() public {
        vm.startPrank(ALICE);
        oToken2.deposit(3, 2, 1e6 * (10 ** uToken.decimals()));
        vm.stopPrank();
        oToken.deposit(1, 1e6 * (10 ** uToken.decimals()));
        IOmniPool.MarketConfiguration memory config =
            IOmniPool.MarketConfiguration(0.9e9, 0, uint32(block.timestamp + 10000 days), 2, true);
        pool.setMarketConfiguration(address(oToken), config);
        pool.enterIsolatedMarket(1, address(oToken));
        IOmniPool.MarketConfiguration memory config2 =
            IOmniPool.MarketConfiguration(0.9e9, 0.9e9, uint32(block.timestamp + 10000 days), 0, false);
        pool.setMarketConfiguration(address(oToken2), config2);
        address[] memory markets = new address[](1);
        markets[0] = address(oToken2);
        pool.enterMarkets(1, markets);

        pool.borrow(1, address(oToken2), 8e23);

        vm.expectRevert("OmniTokenNoBorrow::withdraw: Not healthy.");
        oToken.withdraw(1, 1e6 * 1e18);
    }
}
