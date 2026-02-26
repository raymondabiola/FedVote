# FedVote

**A Transparent, Incentived, and Tamper-Resistant On-Chain Voting Infrastructure**

A decentralized election protocol inspired by the Nigerian voting system, designed to work globally while preventing double voting and rewarding civic participation.

---

## Vision

FedVote redefines democratic participation by combining:

- Cryptographic identity hashing

- On-chain transparency

- Incentivized civic participation

- Long-term patriotism rewards via NFTs

We believe democracy should be:

- Transparent

- Tamper-resistant

- Verifiable

- Incentivized

---

## The Problem

Traditional voting systems suffer from:

- Double voting
- Identity fraud
- Opaque result collation
- Low youth participation
- No incentive for civic responsibility
- Poor long-term engagement tracking

Even electronic systems are centralized and trust-based.

---

## Our Solution

FedVote is a modular Solidity-based election protocol that:

1. Prevents double voting using hashed identity mapping

2. Publishes anonymized voter hashes for public verification

3. Rewards voters with ERC20 tokens

4. Rewards consistent voters with milestone NFTs

## Tech Stack

- Next.js ^16.1.x

- Solidity ^0.8.x

- OpenZeppelin contracts

- Foundry / Hardhat

- ERC20 (reward token)

- ERC721 (patriot NFT)

- Custom Prize Pool contract

- Keccak256 hashing

---

# Architecture Overview

# FedVote Implementation Strategy

The following contracts are to be implemented for this project.

- NationalToken.sol
- Registry.sol
- NationalElectionBody.sol
- PoliticalPartiesManager.sol
- Elections.sol
- VoterIncentives.sol
- DemocracyBadge.sol

---

# Description

## National Token Contract

- Token Name: NAT
- ERC20 token contract for national currency
- Initial Supply 1_000_000 Tokens and does not have a cap

#### Functional implementation

```
mint()
approve()
transfer()
transferFrom()
every other ERC20 standard function.
```

#### Dependencies

- OpenZeppelin
- IERC20

---

## Registry Contract

- Contract implements registering a fixed json list of citizens using their National Identification number.
- Contract author will be able to get off-chain NIN data onchain and use it to register citizens via a registerVoter function.
- Contract also implements a change voter address which can be called by only an address with the role "ELECTION_OFFICER". Such an address can change the address tied to a voter data in the case that such voter loses their private keys to their address and needs to change it.
- Implements a struct that stores how consistent a vote is

#### Functional requirement

```
registerVoter()
changeVoterAddress()
Voter struct must implement booleans isRegistered and isAccredited
```

#### Dependencies

- Offchain scripting logic
- Elections contract

---

## National Election Body Contract

- Contract implements registration of a list of JSON parties.
- Party registration will include registration of party name, party chairman, and party candidate for a list of elections. In the case of no candidate for an election at a time, the string value of candidate name for such party and for such election will default to an empty string.

#### Functional requirement

```
registerParty()  // populates a Party struct mapping
changePartyChairman()
partyCandidate()
// 2D Party candidate mapping: Party name => ElectionID => // Party Candidate struct
mapping(string => mapping(uint => PartyCandidate)) partyCandidate
```

#### Dependencies

- PoliticalPartiesManager contract

---

## Political Parties Manager Contract

- Contract will have candidates that contest for party elections.
- A partyPrimaries function will allow party members to chose their candidate, making sure only eligible party members can vote and can only vote once.

#### Functions

```
registerPartyMember()
registerCandidate()
primaryElection()
declareWinner()
```

---


## Elections Contract

- National voting contract among candidates of registered parties for National elections.
- Each National election is represented by an ID.
- Only Voters who are registered and accredited for an election can vote.
- Import registry contract and Party contracts

#### Functional requirements

```
vote()
declareWinner()
```

#### Dependencies

- Election Body Contract
- Political Parties Manager Contract

---

## Democracy Badge Contract

- Implements the ERC721 token contract standard.
- Voters can claim(mint) NFT to their address for consistent voting.
- Internal helper to check if a voter has been consistent.

#### Functional Implementation

```
checkEligibility() internal helper
claimNFT()
Other function implementation in ERC721 standard
```

#### Dependencies

- IERC721 Interface
- Registry Contract

---

## Voter Incentives Contract

- Contract rewards patriotic voters who are consistent for a specified period of time and as a result have received the patriot NFT.
- Imports the NAT token contract.

#### Functional Implementation

```
getVoterReward()  // checks if voter has the patriot NFT. Voter can claim rewards once a year.
```

#### Dependencies

- Democracy Badge contract

---

# Future Roadmap

- Zero-knowledge proof identity verification
- Soulbound civic NFTs
- Mobile-friendly voting portal

# Team

Built by Web3 developers passionate about goverance, transparency and democratic innovation

- Raymond ([@raymondabiola](https://github.com/raymondabiola))
- Gogo ([@GoGo-Eng](https://github.com/GoGo-Eng))
- Anthony ([@Anthony-19](https://github.com/Anthony-19))
- Musab ([@musab1258](https://github.com/musab1258))
- Dolapo ([@Dydex](https://github.com/Dydex))
