# Architecture

## Contracts

- **CrowdFund.sol** — single campaign escrow (ETH or ERC20). All-or-nothing: creator withdraws on success, contributors refund on failure. Chain-agnostic, unaffected by network choice below.
- **CrowdFundFactory.sol** — CREATE2 deployer with predictable addresses and per-creator campaign tracking. Chain-agnostic.
- **MilestoneCrowdFund.sol** — milestone-based fund release with contribution-weighted voting. Rejected milestones trigger pro-rata refunds. Chain-agnostic, standalone portfolio piece — not used by EverestOrBust, which needs a simpler one-time all-or-nothing outcome rather than staged release.
- **EverestOrBust.sol** — the actual Everest 2027 fundraise contract, on Avalanche C-Chain. USDC + USDT only, $6.9 per-address cap, $69,000 goal (10,000 contributors), 69-day campaign starting Dec 10 2026. No price oracle — stablecoins only, no DAI. Contributions close automatically once the goal is reached. Fully independent contract, no dependency on the other three.

## Design Patterns

- **CEI (Checks-Effects-Interactions)** — all state changes happen before external calls
- **Pull-over-push refunds** — contributors call `refund()` themselves; no loops, no push failures
- **Custom errors** — gas-efficient reverts with descriptive selectors
- **Inline reentrancy guard** — no external dependencies, same pattern across all contracts
- **Normalized accounting** — EverestOrBust scales USDC/USDT (both 6 decimals on Avalanche) to 18 decimals internally for consistent cap and goal arithmetic. No mixed-decimal complexity since both accepted tokens share the same decimal count.
- **Isolated token transfers** — `withdraw()`/`refund()` treat each token's transfer independently (`_trySendToken`), so a single blacklisted/frozen token (a real risk with USDC/USDT compliance controls) cannot trap funds in the other token. Failed transfers are tracked in `stuckBalance` and reclaimable via `claimStuck()`.
- **Balance-diff crediting** — `contribute()` measures the actual token balance delta rather than trusting the requested amount, defending against any future fee-on-transfer or deflationary token behavior.

## Networks

**Avalanche C-Chain (Fuji testnet → mainnet).** EverestOrBust holds real contributor money for a real Everest attempt — the network choice prioritizes sub-2-second finality, low fees, and full EVM compatibility (Solidity/MetaMask/Foundry work unchanged). `CrowdFund.sol`/`CrowdFundFactory.sol`/`MilestoneCrowdFund.sol` are chain-agnostic and not tied to this decision.
