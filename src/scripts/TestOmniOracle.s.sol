// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "openzeppelin/contracts/token/ERC20/ERC20.sol";
import "openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "../OmniOracle.sol";

contract TestOmniOracle is Script {
    function run() external {
        vm.startBroadcast();
        OmniOracle oracle = new OmniOracle();
        oracle.initialize(msg.sender);
        address SEPOLIA_BAND = 0xdE2022A8aB68AE86B0CD3Ba5EFa10AaB859d0293;
        ERC20 token = new ERC20("ETH", "ETH");
        oracle.setOracleConfig(
            address(token),
            IOmniOracle.OracleConfig(SEPOLIA_BAND, IOmniOracle.Provider.Band, 10 hours, 10 hours, 18),
            "ETH"
        );
        IStdReference.ReferenceData memory data = IStdReference(SEPOLIA_BAND).getReferenceData("ETH", "USD");
        uint256 price = oracle.getPrice(address(token));
        assert(price == data.rate * (1e36 / 1e18) / (10 ** IERC20Metadata(address(token)).decimals()));
        console.log("Price: %s", data.rate, data.lastUpdatedBase, data.lastUpdatedQuote);
        console.log("Block: ", block.timestamp);

        address CHAINLINK_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        ERC20 btc = new ERC20("BTC", "BTC");
        oracle.setOracleConfig(
            address(btc),
            IOmniOracle.OracleConfig(CHAINLINK_BTC_USD, IOmniOracle.Provider.Chainlink, 10 hours, 10 hours, 8),
            "BTC"
        );
        uint256 btcPrice = oracle.getPrice(address(btc));
        (, int256 answer,, uint256 updatedAt,) = IChainlinkAggregator(CHAINLINK_BTC_USD).latestRoundData();
        assert(
            btcPrice
                == uint256(answer) * (1e36 / (10 ** IChainlinkAggregator(CHAINLINK_BTC_USD).decimals()))
                    / (10 ** IERC20Metadata(address(btc)).decimals())
        );
        console.log("Price:", uint256(answer), updatedAt);
        console.log("Oracle: ", btcPrice, block.timestamp);
    }
}
