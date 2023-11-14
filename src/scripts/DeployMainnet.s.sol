// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import "./mock/WETH9.sol";
import "../OmniToken.sol";
import "../OmniTokenNoBorrow.sol";
import "../OmniPool.sol";
import "../IRM.sol";
import "../OmniOracle.sol";
import "../WETHGateway.sol";
import "../utils/OmniLens.sol";

contract DeployMainnet is Script {
    IRM irm;
    OmniOracle oracle;
    OmniPool pool;
    ProxyAdmin admin;

    // Define all OmniTokens and OmniTokenNoBorrows here
    OmniToken oWETH;
    OmniTokenNoBorrow oBETA;

    address private constant ADMIN = 0xCdE61DDC37A5bCB61542d408C9DEA56aEbCe76a9; // Safe Multisig
    address private constant FEE_RECEIVER = 0xa7C79328CD88D302dB528CC3cB6468014d45FEE5;

    address private constant BAND_STD_REFERENCE = 0x6ec95bC946DcC7425925801F4e262092E0d1f83b;
    uint256 public immutable TRANCHE_COUNT = 3;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant BETA = 0xBe1a001FE942f96Eea22bA08783140B9Dcc09D28;

    function run() external {
        vm.startBroadcast();
        admin = new ProxyAdmin();
        admin.transferOwnership(ADMIN);

        // Deploy OmniOracle
        OmniOracle oracleImpl = new OmniOracle();
        oracleImpl.initialize(ADMIN);
        bytes memory oracleData = abi.encodeWithSelector(oracleImpl.initialize.selector, ADMIN);
        TransparentUpgradeableProxy oracleProxy =
            new TransparentUpgradeableProxy(address(oracleImpl), address(admin), oracleData);
        oracle = OmniOracle(address(oracleProxy));

        // Deploy IRM
        IRM irmImpl = new IRM();
        irmImpl.initialize(ADMIN);
        bytes memory irmData = abi.encodeWithSelector(irmImpl.initialize.selector, ADMIN);
        TransparentUpgradeableProxy irmProxy =
            new TransparentUpgradeableProxy(address(irmImpl), address(admin), irmData);
        irm = IRM(address(irmProxy));

        // Deploy Pool
        OmniPool poolImpl = new OmniPool();
        poolImpl.initialize(address(oracle), FEE_RECEIVER, ADMIN);
        // Initialize the impl as well
        bytes memory poolData =
            abi.encodeWithSelector(poolImpl.initialize.selector, address(oracle), FEE_RECEIVER, ADMIN);
        TransparentUpgradeableProxy poolProxy =
            new TransparentUpgradeableProxy(address(poolImpl), address(admin), poolData);
        pool = OmniPool(address(poolProxy));

        // Deploy OmniTokenImpl, deploy oWETH first for WETHGateway
        OmniToken oTokenImpl = new OmniToken();
        oTokenImpl.initialize(address(pool), WETH, address(irm), new uint256[](TRANCHE_COUNT));

        uint256[] memory borrowCapsETH = new uint256[](TRANCHE_COUNT);
        borrowCapsETH[0] = 1e6 * 1e18;
        borrowCapsETH[1] = 1e3 * 1e18;
        borrowCapsETH[2] = 0.5e3 * 1e18;
        bytes memory oWETHData =
            abi.encodeWithSelector(oTokenImpl.initialize.selector, address(pool), WETH, address(irm), borrowCapsETH);
        TransparentUpgradeableProxy oWETHProxy =
            new TransparentUpgradeableProxy(address(oTokenImpl), address(admin), oWETHData);
        oWETH = OmniToken(address(oWETHProxy));

        WETHGateway gatewayImpl = new WETHGateway();
        gatewayImpl.initialize(address(oWETH));
        new TransparentUpgradeableProxy(address(gatewayImpl), address(admin), abi.encodeWithSelector(gatewayImpl.initialize.selector, address(oWETH)));

        OmniTokenNoBorrow oTokenNoBorrowImpl = new OmniTokenNoBorrow();
        oTokenNoBorrowImpl.initialize(address(pool), BETA, 0);
        bytes memory oBETAData =
            abi.encodeWithSelector(oTokenNoBorrowImpl.initialize.selector, address(pool), BETA, 2e8 * 1e18);
        TransparentUpgradeableProxy oBETAProxy =
            new TransparentUpgradeableProxy(address(oTokenNoBorrowImpl), address(admin), oBETAData);
        oBETA = OmniTokenNoBorrow(address(oBETAProxy));

        new OmniLens();
    }
}
