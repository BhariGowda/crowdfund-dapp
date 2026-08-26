# SummitFund

A decentralized crowdfunding protocol built in Solidity — the smart contract infrastructure behind my personal Everest summit fundraise.

## The Real Use Case

In April 2027 I'm attempting to summit Mount Everest. The goal is $69,000. No bank, no Kickstarter, no middleman — the funds are held on-chain, contributors get auto-refunds if the goal isn't met by the deadline.

This protocol is what makes that possible. It started as a single crowdfund contract for the EverestOrBust campaign. It grew into a full protocol suite with a factory and milestone-based fund releases as standalone portfolio pieces, alongside EverestOrBust as the real, deployed campaign.

[Follow the climb →](https://twitter.com/gowdabhari)

## Protocol

**EverestOrBust.sol** — the actual campaign contract, on Avalanche C-Chain. USDC and USDT only. $6.9 cap per address. $69,000 goal, 10,000 contributors. 69-day campaign (Dec 10 2026 – Feb 17 2027). Auto-refund if goal not met. Contributions close automatically once the goal is reached. No price oracle — stablecoins only.

**CrowdFund.sol** — general-purpose single campaign escrow. ETH or any ERC20 token. Auto-refund if the goal isn't met by the deadline. Chain-agnostic, standalone.

**CrowdFundFactory.sol** — CREATE2 deployer. Predictable addresses, per-creator campaign tracking, ETH and ERC20 variants. Chain-agnostic.

**MilestoneCrowdFund.sol** — milestone-based fund release with contributor voting. The creator requests each milestone; contributors vote to approve or reject. Rejected milestones trigger a pro-rata refund of the remaining pool. Standalone — not used by EverestOrBust, which is a simpler one-time all-or-nothing campaign.

## Stack

- Solidity ^0.8.20 + Foundry
- Avalanche C-Chain (Fuji testnet → mainnet)

## Tests

```bash
forge install
forge build
forge test
```

206 tests passing — unit, fuzz (1000 runs/property), and invariant (500,000 calls/invariant). Every custom error has an explicit revert test. Reentrancy guards verified by execution trace against malicious token and creator contracts.

## Security Highlights

Five real defects found and fixed during self-audit, including a denial-of-service where a single blacklisted USDC/USDT address could trap a contributor's entire refund. Full findings in [docs/AUDIT.md](docs/AUDIT.md). A professional third-party audit is planned before mainnet deployment.

## Documentation

- [Architecture](docs/ARCHITECTURE.md) — design decisions and contract relationships
- [Audit](docs/AUDIT.md) — self-audit checklist and findings
- [Deployment Guide](docs/DEPLOYMENT.md) — step-by-step deployment instructions
- [Security Policy](SECURITY.md) — vulnerability disclosure process
- [Slither Findings](docs/SLITHER.md) — static analysis results and notes
- [Coverage Report](docs/COVERAGE.md) — per-contract test coverage breakdown

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, code standards, and PR process.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a full version history.
