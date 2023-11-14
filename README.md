
# Overview
The Omni protocol is a novel composable, dynamic, and capital efficient money market primitive. In comparison to existing money market
designs that make trade-offs between asset capital
efficiency and liquidity to support more assets, the
Omni protocol is able to support a wide array of
collateral and borrow assets with zero fragmentation and maximal capital efficiency. The protocol introduces a novel concept of ”risk tranches”
for asset pools that allows lenders to opt-in and
opt-out of lending to certain collateral assets, so
lenders earn the maximum yield for their risk profile and borrowers have access to maximum liquidity. In addition, the protocol introduces collisionfree sub-accounts for asset management, high efficiency borrowing modes, a joint risk and utilization interest model, timed collateral, proportional
loss socialization, and dynamic liquidations using
dutch auctions. Through these advancements, the
Omni Protocol elevates the capital efficiency and
fluidity of the money market landscape, offering
a robust foundation for fostering a more inclusive
and efficient financial ecosystem.

There are eight files that are in the scope for the audit:
- `OmniPool.sol`: The main contract of the protocol, responsible for managing configurations and risk management for the protocol.
- `OmniToken.sol`: Contract responsible for handling pooling assets that may be used as collateral and are borrowable for the protocol.
- `OmniTokenNoBorrow.sol`: Contract responsible for handling deposits of tokens that are not borrowable, i.e. will only be used as collateral for the protocol.
- `IRM.sol`: The interest rate model for the protocol. Interest rates for the protocol depend on both utilization and the tranche of the borrow.
- `OmniOracle.sol`: The oracle contract for the protocol. Responsible for returning prices in the base unit of the token.
- `WETHGateway.sol`: A contract to assist with depositing of native ETH into the protocol only. This contract does not support withdrawing ETH natively.
- `WithUnderlying.sol`: An abstract contract that is responsible for handling transfers of the underlying token and storing address data.
- `SubAccount.sol`: A library for retrieving the subaccount for any user address given a uint96 subId. Provides helper methods to convert between the subaccount and the original argument inputs.

All contracts follow the `TransparentUpgradeableProxy` pattern with `ProxyAdmin`, for more information see [here](https://docs.openzeppelin.com/contracts/4.x/api/proxy#TransparentUpgradeableProxy).

It is highly encouraged that auditors read the [Omni Protocol Whitepaper](https://www.betafinance.org/OmniByBeta_Whitepaper.pdf) within the repository. 
