# Mith Protocol

Solidity files relating to the MITH protocol.

## Getting Started

We're using [dapp-tools](http://dapp.tools/) to compile, and test contracts. To get the dapp binary, you'll first need to [install Nix](https://nixos.org/guides/install-nix.html).

```bash
# Install Nix
curl -L https://nixos.org/nix/install | sh

# Install dapp-tools
curl https://dapp.tools/install | sh
```

```bash
dapp update
dapp build
```

## Dev

```bash
# Using ganche as a caching layer
ganache-cli -f https://mainnet.infura.io/v3/<URL>

DAPP_TEST_NUMBER=$(seth block-number) DAPP_TEST_TIMESTAMP=$(date +%s) DAPP_TEST_BALANCE_CREATE=10000000000000000000000000 dapp test --rpc-url http://localhost:8545 -m <test to run> -vv

# Dapp tools cli args
# -vv - Verbose (Show stacktraces if fail)
# -vv - Very verbose (ALWAYS show stacktraces)
# -m  - Only runs tests whos regex matches this string
```

## Deploy

### Via Remix

```bash
# Flatten
hevm flatten --source-file src/<sol> --json-file out/dapp.sol.json

# Deploy file via remix
```
