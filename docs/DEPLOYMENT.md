# Deployment Guide

## Networks

- Fuji Testnet: `forge script script/Deploy.s.sol --rpc-url fuji --broadcast --verify`
- Avalanche Mainnet: `forge script script/Deploy.s.sol --rpc-url avalanche --broadcast --verify`

## Requirements

- Foundry installed
- `.env` with `PRIVATE_KEY` and `SNOWTRACE_API_KEY`
- RPC URLs set in `.env` (`AVALANCHE_RPC_URL`, `FUJI_RPC_URL`)

## Deployed Contracts

| Network | CrowdFundFactory | EverestOrBust | Date |
|---------|-----------------|---------------|------|
| Fuji Testnet | TBD | TBD | TBD |
| Avalanche Mainnet | TBD | TBD | TBD |

## Deploy Factory

```bash
source .env
forge script script/Deploy.s.sol --rpc-url fuji --broadcast --verify
```

## Deploy EverestOrBust Campaign

After deploying the factory, set `FACTORY_ADDRESS` in `.env` then:

```bash
forge script script/DeployEverestOrBust.s.sol --rpc-url fuji --broadcast --verify
```

## EverestOrBust Campaign Parameters

| Parameter | Value |
|---|---|
| Start | Dec 10 2026 00:00:00 UTC (`1765324800`) |
| End | Feb 17 2027 00:00:00 UTC (start + 69 days) |
| Goal | $69,000 (69_000e18 normalized) |
| Cap per address | $6.9 (6.9e18 normalized) |
| Contributors needed | 10,000 |
| Tokens | USDC, USDT (no DAI, no price oracle) |
| Network | Avalanche C-Chain only |

## Avalanche Mainnet Token Addresses

| Token | Address |
|-------|---------|
| USDC (native) | 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E |
| USDT  | 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7 |

**Verify both addresses against Snowtrace's verified-contract page before any real deployment — do not trust a cached address without a fresh check.** Use native USDC, not the legacy bridged USDC.e.

## Fuji Testnet Token Addresses

TBD — look up before testnet deploy. Not yet verified.
