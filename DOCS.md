# FedVote

**A Tokenized, Transparent, Incentived, Secure, and Tamper-Resistant On-Chain Voting Infrastructure**

A decentralized election protocol inspired by the Nigerian voting system, designed to work globally while preventing double voting and rewarding civic participation.

## MVP Website


## Vision 

FedVote redefines democratic participation by combining:

- Cryptographic identity hashing

- On-chain transparency

- Incentivized civic participation

- Citizen long-term voting incentivization via tokenized rewards and NFTs


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
- Low citizen (especially youth) participation
- Rigging and insecurity of lives and properties
- No incentive for civic responsibility
- Forces citizens to endure outdoor queues and travel to polling stations for both accreditation and voting.
- Poor long-term engagement tracking

Even electronic systems are centralized and trust-based.

---

## Our Solution 

FedVote is a modular blockchain election protocol that:

1. Prevents double voting using hashed identity mapping

2. Abstracts citizen's National Identification Number using onchain hashing techniques

3. Rewards voters' consistency with a Democracy Badge NFT and the federal ERC20 National tokens

4. Eligible voters can vote their candidate choice at the comfort of their homes without pressure or oppresion in public polling centres

## Tech Stack 
- Next.js ^16.1.x

- Solidity ^0.8.x

- OpenZeppelin contracts

- Foundry

- ethers.js

<br>

# Architecture Overview 

## FedVote Implementation Strategy
**The following contracts were implemented for this project.**
- NationalToken.sol
- Registry.sol
- NationalElectionBody.sol
- PoliticalPartiesManager.sol
- PoliticalPartyManagerFactory.sol
- Elections.sol
- VoterIncentives.sol
- DemocracyBadge.sol

<br>

# Contract Description
## National Token Contract (ERC20)
- Token Name: National Token
- Symbol: NAT
- This contract is controlled by the National central bank. 
- Token is primarily used to incentivize voter long term committment.

#### Admin Roles
```
DEFAULT_ADMIN_ROLE
MINTER_ROLE
```
#### Dependencies
- OpenZeppelin ERC20 
- OpenZeppelin Access Control 
- Openzeppelin Reentrancy Guard 

---

## Registry Contract
- This contract is controlled by the National voter registration body.
- Contract implements authorizing citizens in batches onchain. Such authorization granted by the registration body gives citizens the possibility of self-registering on-chain.
- The National registration body can change a voter onchain address in the event that the voter loses access to the private key tied to their account. However, such voter must visit the registration office for kyc checks.
- Implements a struct that describes typical voter data.

#### Admin Roles
```
DEFAULT_ADMIN_ROLE
REGISTRATION_OFFICER_ROLE
ELECTIONS_CONTRACT_ROLE
PARTY_CONTRACT_ROLE
```

#### Dependencies
- openZeppelin Access Control
<br>

## National Election Body Contract
- Contract implements registration of political parties
- Also provides a function for each party to provide their aspiring candidate for national elections
- Provides election Id to the elections contract whenever there is an election

#### Admin Roles
```
DEFAULT_ADMIN_ROLE
PARTY_PRIMARIES_ROLE
```

#### Dependencies
- OpenZeppelin Access Control
- OpenZeppelin Reentrancy Guard
- National Token

## Political Parties Manager Contract
- This contract manages the activies of a single political party
- Each political party can have their deployed version using a factory contract
- Contract manages member and candidate registrations and also primary election processes.
- Only eligible party members can participate in primary elections
- Implements a secure system that ensures members can join a new party only if they are unregistered from their current party.

#### Admin Roles
```
DEFAULT_ADMIN_ROLE
PARTY_LEADER
MEMBER_ROLE
```
#### Dependencies
- OpenZeppelin Access Control
- National Token
- Registry
- National Election Body
- OpenZeppelin Reentrancy Guard
<br>

## Political Party Manager Factory Contract
- Manages creation of new child contracts for political parties manager contract

#### Dependencies
- Political Parties Manager

## Elections Contract
- This contract handles voting procedure for National elections
- Each National election is represented by an ID
- Only Voters who are registered and accredited for an election can vote for that election
- Mints the Democracy Badge NFT to citizens that can consistently attain a threshold of 3 voter streak.

#### Admin Roles
```
DEFAULT_ADMIN_ROLE
ELECTION_OFFICER_ROLE
```

#### Dependencies
- Registry
- National Election Body
- Democracy Badge
<br>

## Democracy Badge Contract
- Citizens are awarded a soul bound National badge of honor for voting participation
- Implements the ERC721 standard with some modifications
- Voters automatically receives the badge at their onchain address when their vote streak reaches the initial threshold of 3.

#### Admin Roles
```
ELECTIONS_CONTRACT_ROLE
```

#### Dependencies
- OpenZeppelin ERC71
- OpenZeppelin Access Control
---

## Voter Incentives Contract
- Contract rewards patriotic voters with at least vote streak of 3 and as a result have received the patriot NFT.
- Streak threshold levels are in the order of 3, 6, 9, 12, 15 ........
- Voter can claim rewards **once** for every streak threshold
- Rewards for each streak threshold are not linear but  follows a fair upward scale with increasing threshold
- In the event that a voter loses their streak, it resets to 0. **They can claim rewards again when their streak reaches a threshold that is one step ahead of their last claim**. This is to encourage voter committment to National elections.

#### Admin Role
```
onlyOwner
```

#### Dependencies
- OpenZeppelin Ownable
- OpenZeppelin Reentrancy Guard
- Democracy Badge
- National Token
- Registry
<br>

## Reward Breakdown Example
*Assuming Base Reward = 100 NAT (with 1.3x growth factor per threshold)*

| Streak Threshold | Eligible Reward | Difference from Previous |
|:----------------:|:----------------:|:------------------------:|
| 3                | 100 NAT          | -                        |
| 6                | 130 NAT          | +30 NAT                  |
| 9                | 169 NAT          | +39 NAT                  |
| 12               | 220 NAT          | +51 NAT                  |
| 15               | 286 NAT          | +66 NAT                  |
| 18               | 371 NAT          | +85 NAT                  |
| 21               | 482 NAT          | +111 NAT                 |
| 24               | 627 NAT          | +145 NAT                 |
| 27               | 815 NAT          | +188 NAT                 |
| 30               | 1,059 NAT        | +244 NAT                 |

### How It Works:
- **Streak 3**: Base reward (100 NAT)
- **Streak 6**: 100 × 1.3 = 130 NAT
- **Streak 9**: 130 × 1.3 = 169 NAT
- **Streak 12**: 169 × 1.3 = 219.7 ≈ 220 NAT (rounded)

*Note: Rewards compound at each threshold (every 3 consecutive votes), incentivizing long-term voter participation.*
<br><br>

# Future Roadmap
- Zero-knowledge proof identity verification
- Mobile-friendly voting portal
<br><br>

# Team
Built by Web3 developers passionate about goverance, transparency and democratic innovation

- Raymond (github)
- Gogo (github)
- Anthony (github)
- Musab (github)
- Dolapo (github)