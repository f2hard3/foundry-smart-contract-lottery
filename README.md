# Foundry Smart Contract Lottery

This project is a decentralized lottery (raffle) system built with Solidity and tested using Foundry. It leverages Chainlink VRF for verifiable randomness and is designed for educational and demonstration purposes.

## Features

- Decentralized lottery contract (`Raffle.sol`)
- Chainlink VRF integration for randomness
- Automated testing with Foundry
- Mock contracts for local testing
- Deployment and interaction scripts

## Project Structure

```
├── src/                # Main contract source code
│   └── Raffle.sol      # Lottery contract
├── script/             # Deployment and helper scripts
│   ├── DeployRaffle.s.sol
│   ├── HelperConfig.s.sol
│   └── Interactions.s.sol
├── test/               # Test contracts
│   ├── unit/           # Unit tests
│   │   └── RaffleTest.t.sol
│   └── mocks/          # Mock contracts (e.g., LinkToken)
├── lib/                # External dependencies (Chainlink, Forge Std, etc.)
├── foundry.toml        # Foundry configuration
├── Makefile            # Common build/test commands
└── README.md           # Project documentation
```

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) (install with `curl -L https://foundry.paradigm.xyz | bash`)
- Node.js (for some scripts, optional)

### Install Dependencies

```sh
forge install
```

### Build Contracts

```sh
forge build
```

### Run Tests

```sh
forge test
```

### Deploy Locally

```sh
forge script script/DeployRaffle.s.sol --fork-url <YOUR_RPC_URL> --broadcast
```

### Directory Details

- `src/`: Main contract(s)
- `script/`: Deployment and helper scripts
- `test/`: Solidity-based tests and mocks
- `lib/`: External libraries (Chainlink, Forge Std, etc.)

## Chainlink VRF

This project uses Chainlink VRF for randomness. For local testing, a mock VRF coordinator is used. For testnets/mainnet, configure your VRF subscription and coordinator address in `HelperConfig.s.sol`.

## License

MIT

---

Feel free to contribute or fork for your own learning and experimentation!
