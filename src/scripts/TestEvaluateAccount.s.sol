// Check deposit amounts from evaluateAccount to check that the amounts are correct
// Check that the evaluateaccount values make sense given current price oracle
// Make sure that it makes sense in USD values because that's the price feed we are using

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../OmniToken.sol";
import "../OmniTokenNoBorrow.sol";
import "../OmniPool.sol";
import "../IRM.sol";
import "../OmniOracle.sol";
import "../WETHGateway.sol";

contract TestEvaluateAccount is Script {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address public constant SHIB = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address public constant STABLE_WHALE = 0xf6976f773B68E4EA1Aa7E2efE1C62916f1A0D87a;
    address public constant WSTETH_WHALE = 0x176F3DAb24a159341c0509bB36B833E7fdd0a132;
    address public constant WBTC_WHALE = 0x051d091B254EcdBBB4eB8E6311b7939829380b27;
    address public constant SHIB_WHALE = 0x5a52E96BAcdaBb82fd05763E25335261B270Efcb;

    address public constant ADMIN = address(uint160(uint256(keccak256("admin.eth"))));
    address public constant FEE_RECEIVER = address(uint160(uint256(keccak256("fee.eth"))));
    uint256 public constant TRANCHE_COUNT = 3;

    address USDCUSD = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address USDTUSD = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address DAIUSD = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
    address ETHUSD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address STETHUSD = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8;
    address BTCUSD = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address DOGEUSD = 0x2465CefD3b488BE410b941b1d4b2767088e2A028;

    IRM irm;
    OmniOracle oracle;
    OmniPool pool;
    ProxyAdmin admin;
    WETHGateway gateway;

    OmniToken oUSDC;
    OmniToken oUSDT;
    OmniToken oDAI;
    OmniToken oWETH;
    OmniToken oWSTETH;
    OmniTokenNoBorrow oWBTC;
    OmniTokenNoBorrow oSHIB;

    using SubAccount for address;
    using SafeERC20 for IERC20;

    function run() external {
        vm.broadcast();
        admin = new ProxyAdmin();
        vm.startPrank(ADMIN);

        // Deploy OmniOracle
        OmniOracle oracleImpl = new OmniOracle();
        bytes memory oracleData = abi.encodeWithSelector(oracleImpl.initialize.selector, ADMIN);
        TransparentUpgradeableProxy oracleProxy =
            new TransparentUpgradeableProxy(address(oracleImpl), address(admin), oracleData);
        oracle = OmniOracle(address(oracleProxy));

        // Deploy IRM
        IRM irmImpl = new IRM();
        bytes memory irmData = abi.encodeWithSelector(irmImpl.initialize.selector, ADMIN);
        TransparentUpgradeableProxy irmProxy =
            new TransparentUpgradeableProxy(address(irmImpl), address(admin), irmData);
        irm = IRM(address(irmProxy));

        // Deploy Pool
        OmniPool poolImpl = new OmniPool();
        bytes memory poolData =
            abi.encodeWithSelector(poolImpl.initialize.selector, address(oracle), FEE_RECEIVER, ADMIN);
        TransparentUpgradeableProxy poolProxy =
            new TransparentUpgradeableProxy(address(poolImpl), address(admin), poolData);
        pool = OmniPool(address(poolProxy));
        {
            // Borrow caps for stables
            uint256[] memory borrowCaps = new uint256[](TRANCHE_COUNT);
            borrowCaps[0] = 3e7 * 1e6;
            borrowCaps[1] = 1e6 * 1e6;
            borrowCaps[2] = 0.5e6 * 1e6;

            OmniToken oTokenImpl = new OmniToken();
            bytes memory oUSDCData =
                abi.encodeWithSelector(oTokenImpl.initialize.selector, address(pool), USDC, address(irm), borrowCaps);
            TransparentUpgradeableProxy oUSDCProxy =
                new TransparentUpgradeableProxy(address(oTokenImpl), address(admin), oUSDCData);
            oUSDC = OmniToken(address(oUSDCProxy));

            uint256[] memory borrowCapsUSDT = new uint256[](TRANCHE_COUNT);
            borrowCapsUSDT[0] = 3e7 * 1e8;
            borrowCapsUSDT[1] = 1e6 * 1e8;
            borrowCapsUSDT[2] = 0.5e6 * 1e8;
            bytes memory oUSDTData = abi.encodeWithSelector(
                oTokenImpl.initialize.selector, address(pool), USDT, address(irm), borrowCapsUSDT
            );
            TransparentUpgradeableProxy oUSDTProxy =
                new TransparentUpgradeableProxy(address(oTokenImpl), address(admin), oUSDTData);
            oUSDT = OmniToken(address(oUSDTProxy));

            uint256[] memory borrowCapsDAI = new uint256[](TRANCHE_COUNT);
            borrowCapsDAI[0] = 3e7 * 1e18;
            borrowCapsDAI[1] = 1e6 * 1e18;
            borrowCapsDAI[2] = 0.5e6 * 1e18;
            bytes memory oDAIData =
                abi.encodeWithSelector(oTokenImpl.initialize.selector, address(pool), DAI, address(irm), borrowCapsDAI);
            TransparentUpgradeableProxy oDAIProxy = new TransparentUpgradeableProxy(
                address(oTokenImpl), address(admin), oDAIData
            );
            oDAI = OmniToken(address(oDAIProxy));

            uint256[] memory borrowCapsETH = new uint256[](TRANCHE_COUNT);
            borrowCapsETH[0] = 1e4 * 1e18;
            borrowCapsETH[1] = 1e3 * 1e18;
            borrowCapsETH[2] = 0.5e3 * 1e18;

            bytes memory oWETHData =
                abi.encodeWithSelector(oTokenImpl.initialize.selector, address(pool), WETH, address(irm), borrowCapsETH);
            TransparentUpgradeableProxy oWETHProxy =
                new TransparentUpgradeableProxy(address(oTokenImpl), address(admin), oWETHData);
            oWETH = OmniToken(address(oWETHProxy));
            WETHGateway gatewayImpl = new WETHGateway();
            TransparentUpgradeableProxy gatewayProxy =
            new TransparentUpgradeableProxy(address(gatewayImpl), address(admin), abi.encodeWithSelector(gatewayImpl.initialize.selector, address(oWETH)));
            gateway = WETHGateway(payable(gatewayProxy));

            bytes memory oWSTETHData = abi.encodeWithSelector(
                oTokenImpl.initialize.selector, address(pool), WSTETH, address(irm), borrowCapsETH
            );
            TransparentUpgradeableProxy oWSTETHProxy =
                new TransparentUpgradeableProxy(address(oTokenImpl), address(admin), oWSTETHData);
            oWSTETH = OmniToken(address(oWSTETHProxy));

            OmniTokenNoBorrow oTokenNoBorrowImpl = new OmniTokenNoBorrow();

            bytes memory oWBTCData =
                abi.encodeWithSelector(oTokenNoBorrowImpl.initialize.selector, address(pool), WBTC, 1e3 * 1e8);
            TransparentUpgradeableProxy oWBTCProxy =
                new TransparentUpgradeableProxy(address(oTokenNoBorrowImpl), address(admin), oWBTCData);
            oWBTC = OmniTokenNoBorrow(address(oWBTCProxy));

            bytes memory oSHIBData =
                abi.encodeWithSelector(oTokenNoBorrowImpl.initialize.selector, address(pool), SHIB, 1e12 * 1e18);
            TransparentUpgradeableProxy oSHIBProxy =
                new TransparentUpgradeableProxy(address(oTokenNoBorrowImpl), address(admin), oSHIBData);
            oSHIB = OmniTokenNoBorrow(address(oSHIBProxy));
        }
        // Set IRM configs
        {
            IIRM.IRMConfig[] memory irmConfigs = new IIRM.IRMConfig[](TRANCHE_COUNT);
            uint8[] memory tranches = new uint8[](TRANCHE_COUNT);
            tranches[0] = 0;
            tranches[1] = 1;
            tranches[2] = 2;

            irmConfigs[0] = IIRM.IRMConfig(0.91e9, 0.001e9, 0.0345e9, 0.63e9); // 80% / 0.1% / 3.45% / 63%
            irmConfigs[1] = IIRM.IRMConfig(0.85e9, 0.01e9, 0.06e9, 0.75e9); // 70% / 1% / 8% / 75%
            irmConfigs[2] = IIRM.IRMConfig(0.8e9, 0.02e9, 0.1e9, 0.9e9); // 80% / 2% / 10% / 90%

            IIRM.IRMConfig[] memory irmConfigsETH = new IIRM.IRMConfig[](TRANCHE_COUNT);
            irmConfigsETH[0] = IIRM.IRMConfig(0.81e9, 0.001e9, 0.04e9, 0.8e9); // 81% / 0.1% / 4% / 80%
            irmConfigsETH[1] = IIRM.IRMConfig(0.75e9, 0.01e9, 0.08e9, 0.9e9); // 75% / 1% / 8% / 90%
            irmConfigsETH[2] = IIRM.IRMConfig(0.7e9, 0.02e9, 0.1e9, 0.95e9); // 70% / 2% / 10% / 95%

            irm.setIRMForMarket(address(oUSDC), tranches, irmConfigs);
            irm.setIRMForMarket(address(oUSDT), tranches, irmConfigs);
            irm.setIRMForMarket(address(oDAI), tranches, irmConfigs);
            irm.setIRMForMarket(address(oWETH), tranches, irmConfigsETH);
            irm.setIRMForMarket(address(oWSTETH), tranches, irmConfigsETH);
        }

        pool.setMarketConfiguration(
            address(oUSDC), IOmniPool.MarketConfiguration(0.9e9, 0.95e9, type(uint32).max, 0, false)
        );
        pool.setMarketConfiguration(
            address(oUSDT), IOmniPool.MarketConfiguration(0.9e9, 0.95e9, type(uint32).max, 0, false)
        );
        pool.setMarketConfiguration(
            address(oDAI), IOmniPool.MarketConfiguration(0.9e9, 0.95e9, type(uint32).max, 0, false)
        );
        pool.setMarketConfiguration(
            address(oWETH), IOmniPool.MarketConfiguration(0.85e9, 0.9e9, type(uint32).max, 0, false)
        );
        pool.setMarketConfiguration(
            address(oWSTETH), IOmniPool.MarketConfiguration(0.85e9, 0.9e9, type(uint32).max, 0, false)
        );
        pool.setMarketConfiguration(address(oWBTC), IOmniPool.MarketConfiguration(0.6e9, 0, type(uint32).max, 1, true));
        pool.setMarketConfiguration(address(oSHIB), IOmniPool.MarketConfiguration(0.3e9, 0, type(uint32).max, 2, true));
        {
            oracle.setOracleConfig(
                address(USDC),
                IOmniOracle.OracleConfig(USDCUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 6),
                "USDC"
            );
            oracle.setOracleConfig(
                address(USDT),
                IOmniOracle.OracleConfig(USDTUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 8),
                "USDT"
            );
            oracle.setOracleConfig(
                address(DAI), IOmniOracle.OracleConfig(DAIUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 18), "DAI"
            );
            oracle.setOracleConfig(
                address(WETH), IOmniOracle.OracleConfig(ETHUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 18), "ETH"
            );
            oracle.setOracleConfig(
                address(WSTETH),
                IOmniOracle.OracleConfig(STETHUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 18),
                "STETH"
            );
            oracle.setOracleConfig(
                address(WBTC), IOmniOracle.OracleConfig(BTCUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 8), "BTC"
            );
            oracle.setOracleConfig(
                address(SHIB),
                IOmniOracle.OracleConfig(DOGEUSD, IOmniOracle.Provider.Chainlink, 86400, 86400, 18),
                "SHIB"
            );
        }
        vm.stopPrank();
        {
            vm.startPrank(STABLE_WHALE);
            IERC20(DAI).approve(address(oDAI), type(uint256).max);
            IERC20(USDC).approve(address(oUSDC), type(uint256).max);
            IERC20(USDT).safeApprove(address(oUSDT), type(uint256).max);
            vm.stopPrank();
        }
        {
            vm.startPrank(STABLE_WHALE);
            oUSDC.deposit(0, 0, 1_000e6);
            oUSDC.deposit(0, 2, 20_000e6);
            oUSDT.deposit(0, 2, 1_000e8);
            oDAI.deposit(0, 2, 100e18);
            IOmniPool.Evaluation memory eval = pool.evaluateAccount(STABLE_WHALE.toAccount(0));
            console.log("Evaluation StableWhale True: ", eval.depositTrueValue, eval.borrowTrueValue);
            console.log("Eval StableWhale Adj: ", eval.depositAdjValue, eval.borrowAdjValue);
            console.log("Evaluation StableWhale Stat: ", eval.numDeposit, eval.numBorrow, eval.isExpired);
            vm.stopPrank();
        }
        {
            vm.startPrank(WSTETH_WHALE);
            uint256 ethShares = gateway.deposit{value: 10 ether}(0, 2);
            console.log("Deposited ETH: %s", ethShares);
            IERC20(WSTETH).approve(address(oWSTETH), type(uint256).max);
            oWSTETH.deposit(0, 2, 10e18);
            vm.stopPrank();
        }
        {
            vm.startPrank(WBTC_WHALE);
            address[] memory stableMarkets = new address[](3);
            stableMarkets[0] = address(oUSDC);
            stableMarkets[1] = address(oUSDT);
            stableMarkets[2] = address(oDAI);
            IERC20(WBTC).approve(address(oWBTC), type(uint256).max);
            oWBTC.deposit(0, 3e8);
            pool.enterIsolatedMarket(0, address(oWBTC));
            pool.enterMarkets(0, stableMarkets);
            pool.borrow(0, address(oUSDC), 1_000e6);
            pool.borrow(0, address(oUSDT), 900e8);
            pool.borrow(0, address(oDAI), 100e18);
            IOmniPool.Evaluation memory eval = pool.evaluateAccount(WBTC_WHALE.toAccount(0));
            console.log("Evaluation WBTCWhale True: ", eval.depositTrueValue, eval.borrowTrueValue);
            console.log("Eval Relative: ", eval.depositTrueValue / eval.borrowTrueValue);
            console.log("Eval WBTCWhale Adj: ", eval.depositAdjValue, eval.borrowAdjValue);
            console.log("Evaluation WBTCWhale Stat: ", eval.numDeposit, eval.numBorrow, eval.isExpired);
            vm.stopPrank();
        }
        {
            vm.startPrank(SHIB_WHALE);
            IERC20(SHIB).approve(address(oSHIB), type(uint256).max);
            address[] memory ethMarkets = new address[](2);
            ethMarkets[0] = address(oWETH);
            ethMarkets[1] = address(oWSTETH);
            oSHIB.deposit(0, 1.2e5 * 1e18);
            pool.enterIsolatedMarket(0, address(oSHIB));
            pool.enterMarkets(0, ethMarkets);
            pool.borrow(0, address(oWETH), 0.9e18);
            pool.borrow(0, address(oWSTETH), 0.1e18);
            IOmniPool.Evaluation memory eval = pool.evaluateAccount(SHIB_WHALE.toAccount(0));
            console.log("Evaluation SHIBWhale True: ", eval.depositTrueValue, eval.borrowTrueValue);
            console.log("Eval Relative: ", eval.depositTrueValue / eval.borrowTrueValue);
            console.log("Eval SHIBWhale Adj: ", eval.depositAdjValue, eval.borrowAdjValue);
            console.log("Evaluation SHIBWhale Stat: ", eval.numDeposit, eval.numBorrow, eval.isExpired);
            vm.stopPrank();
        }
    }
}
