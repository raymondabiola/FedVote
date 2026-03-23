import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';
import { ethers } from 'ethers';
import { useAppKitAccount, useAppKitProvider, useDisconnect } from '@reown/appkit/react';
import { appkit } from '../config/appkit';
import {
  ADDRESSES, CHAIN_CONFIG,
  RegistryABI, NationalTokenABI, DemocracyBadgeABI,
  NationalElectionBodyABI, ElectionABI, VoterIncentivesABI,
  PoliticalPartyManagerABI, PoliticalPartiesManagerFactoryABI,
} from '../config/contracts';

// ===== TYPES =====

export interface VoterData {
  name: string;
  address: string;
  streak: number;
  isRegistered: boolean;
}

export interface PartyInfo {
  address: string;
  name: string;
  isMember: boolean;
  isLeader: boolean;
  isAdmin: boolean;
}

export interface Roles {
  isRegistryAdmin: boolean;
  isRegistrationOfficer: boolean;
  isElectionBodyAdmin: boolean;
  isElectionAdmin: boolean;
  isElectionOfficer: boolean;
  isFactoryOwner: boolean;
  isIncentivesOwner: boolean;
  isRegisteredVoter: boolean;
  isAuthorizedCitizen: boolean;
  hasDemocracyBadge: boolean;
  isPartyMember: boolean;
  isPartyLeader: boolean;
  isPartyAdmin: boolean;
  isAdmin: boolean;
}

export interface Contracts {
  registry: ethers.Contract;
  nationalToken: ethers.Contract;
  democracyBadge: ethers.Contract;
  electionBody: ethers.Contract;
  election: ethers.Contract;
  voterIncentives: ethers.Contract;
  factory: ethers.Contract;
}

interface Web3ContextValue {
  account: string | null;
  signer: ethers.Signer | null;
  contracts: Partial<Contracts>;
  roles: Partial<Roles>;
  voterData: VoterData | null;
  loading: boolean;
  partyContracts: PartyInfo[];
  userParty: PartyInfo | null;
  isConnected: boolean;
  openModal: () => void;
  disconnectWallet: () => void;
  refreshRoles: () => Promise<void>;
  getPartyContract: (address: string, s?: ethers.Signer) => ethers.Contract;
  ROLE_HASHES: Record<string, string>;
}

const ROLE_HASHES = {
  DEFAULT_ADMIN: ethers.ZeroHash,
  REGISTRATION_OFFICER: ethers.keccak256(ethers.toUtf8Bytes("REGISTRATION_OFFICER_ROLE")),
  ELECTIONS_CONTRACT: ethers.keccak256(ethers.toUtf8Bytes("ELECTIONS_CONTRACT_ROLE")),
  PARTY_CONTRACT: ethers.keccak256(ethers.toUtf8Bytes("PARTY_CONTRACT_ROLE")),
  ELECTION_OFFICER: ethers.keccak256(ethers.toUtf8Bytes("ELECTION_OFFICER_ROLE")),
  PARTY_PRIMARIES: ethers.keccak256(ethers.toUtf8Bytes("PARTY_PRIMARIES_ROLE")),
  PARTY_LEADER: ethers.keccak256(ethers.toUtf8Bytes("PARTY_LEADER")),
  MEMBER_ROLE: ethers.keccak256(ethers.toUtf8Bytes("MEMBER_ROLE")),
  MINTER_ROLE: ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")),
};

const Web3Context = createContext<Web3ContextValue | null>(null);

export const useWeb3 = (): Web3ContextValue => {
  const ctx = useContext(Web3Context);
  if (!ctx) throw new Error('useWeb3 must be inside Web3Provider');
  return ctx;
};

export function Web3Provider({ children }: { children: React.ReactNode }) {
  const { address, isConnected } = useAppKitAccount();
  const { walletProvider } = useAppKitProvider<any>('eip155');
  const { disconnect } = useDisconnect();

  const [signer, setSigner] = useState<ethers.Signer | null>(null);
  const [contracts, setContracts] = useState<Partial<Contracts>>({});
  const [roles, setRoles] = useState<Partial<Roles>>({});
  const [voterData, setVoterData] = useState<VoterData | null>(null);
  const [loading, setLoading] = useState(false);
  const [partyContracts, setPartyContracts] = useState<PartyInfo[]>([]);
  const [userParty, setUserParty] = useState<PartyInfo | null>(null);

  const account = isConnected && address ? address : null;

  // Open AppKit modal
  const openModal = useCallback(() => {
    appkit.open();
  }, []);

  // Disconnect wallet
  const disconnectWallet = useCallback(() => {
    disconnect();
    setSigner(null);
    setContracts({});
    setRoles({});
    setVoterData(null);
    setPartyContracts([]);
    setUserParty(null);
  }, [disconnect]);

  // Get a party manager contract instance
  const getPartyContract = useCallback((addr: string, s?: ethers.Signer) => {
    return new ethers.Contract(addr, PoliticalPartyManagerABI, s || signer!);
  }, [signer]);

  // Initialize contracts
  const initContracts = useCallback((s: ethers.Signer): Contracts => {
    const c: Contracts = {
      registry: new ethers.Contract(ADDRESSES.Registry, RegistryABI, s),
      nationalToken: new ethers.Contract(ADDRESSES.NationalToken, NationalTokenABI, s),
      democracyBadge: new ethers.Contract(ADDRESSES.DemocracyBadge, DemocracyBadgeABI, s),
      electionBody: new ethers.Contract(ADDRESSES.NationalElectionBody, NationalElectionBodyABI, s),
      election: new ethers.Contract(ADDRESSES.Election, ElectionABI, s),
      voterIncentives: new ethers.Contract(ADDRESSES.VoterIncentives, VoterIncentivesABI, s),
      factory: new ethers.Contract(ADDRESSES.PoliticalPartiesManagerFactory, PoliticalPartiesManagerFactoryABI, s),
    };
    setContracts(c);
    return c;
  }, []);

  // Detect roles for connected address
  const detectRoles = useCallback(async (addr: string, c: Contracts) => {
    const r: Partial<Roles> = {};
    try {
      r.isRegistryAdmin = await c.registry.hasRole(ROLE_HASHES.DEFAULT_ADMIN, addr);
      r.isRegistrationOfficer = await c.registry.hasRole(ROLE_HASHES.REGISTRATION_OFFICER, addr);
      r.isElectionBodyAdmin = await c.electionBody.hasRole(ROLE_HASHES.DEFAULT_ADMIN, addr);
      r.isElectionAdmin = await c.election.hasRole(ROLE_HASHES.DEFAULT_ADMIN, addr);
      r.isElectionOfficer = await c.election.hasRole(ROLE_HASHES.ELECTION_OFFICER, addr);

      try {
        const factoryOwner = await c.factory.owner();
        r.isFactoryOwner = factoryOwner.toLowerCase() === addr.toLowerCase();
      } catch { r.isFactoryOwner = false; }

      try {
        const viOwner = await c.voterIncentives.owner();
        r.isIncentivesOwner = viOwner.toLowerCase() === addr.toLowerCase();
      } catch { r.isIncentivesOwner = false; }

      try {
        const vData = await c.registry.getVoterDataViaAddress(addr);
        r.isRegisteredVoter = vData.isRegistered;
        if (vData.isRegistered) {
          setVoterData({
            name: vData.name,
            address: vData.voterAddress,
            streak: Number(vData.voterStreak),
            isRegistered: vData.isRegistered,
          });
        }
      } catch { r.isRegisteredVoter = false; }

      try {
        r.isAuthorizedCitizen = await c.registry.getValidityOfAddress(addr);
      } catch { r.isAuthorizedCitizen = false; }

      try {
        const badgeBal = await c.democracyBadge.balanceOf(addr);
        r.hasDemocracyBadge = Number(badgeBal) > 0;
      } catch { r.hasDemocracyBadge = false; }

      // Check party memberships
      try {
        const partyAddresses: string[] = await c.factory.getAllPoliticalParty();
        const partyList: PartyInfo[] = [];
        let foundParty: PartyInfo | null = null;

        for (const pAddr of partyAddresses) {
          const pContract = new ethers.Contract(pAddr, PoliticalPartyManagerABI, c.registry.runner);
          try {
            const pName = await pContract.partyName();
            const isMember = await pContract.hasRole(ROLE_HASHES.MEMBER_ROLE, addr);
            const isLeader = await pContract.hasRole(ROLE_HASHES.PARTY_LEADER, addr);
            const isAdmin = await pContract.hasRole(ROLE_HASHES.DEFAULT_ADMIN, addr);
            const info: PartyInfo = { address: pAddr, name: pName, isMember, isLeader, isAdmin };
            partyList.push(info);
            if (isMember || isLeader || isAdmin) foundParty = info;
          } catch {
            partyList.push({ address: pAddr, name: 'Unknown', isMember: false, isLeader: false, isAdmin: false });
          }
        }
        setPartyContracts(partyList);
        setUserParty(foundParty);
        r.isPartyMember = !!foundParty?.isMember;
        r.isPartyLeader = !!foundParty?.isLeader;
        r.isPartyAdmin = !!foundParty?.isAdmin;
      } catch {
        setPartyContracts([]);
        setUserParty(null);
        r.isPartyMember = false;
        r.isPartyLeader = false;
      }

      r.isAdmin = !!(r.isRegistryAdmin || r.isRegistrationOfficer || r.isElectionBodyAdmin ||
                   r.isElectionOfficer || r.isFactoryOwner || r.isIncentivesOwner || r.isElectionAdmin);
    } catch (err) {
      console.error('Role detection error:', err);
    }
    setRoles(r);
    return r;
  }, []);

  // Refresh roles
  const refreshRoles = useCallback(async () => {
    if (account && contracts.registry && signer) {
      const c = initContracts(signer);
      await detectRoles(account, c);
    }
  }, [account, contracts, signer, initContracts, detectRoles]);

  // When wallet connects or address changes, init contracts + detect roles
  useEffect(() => {
    if (!isConnected || !address || !walletProvider) {
      setSigner(null);
      setContracts({});
      setRoles({});
      setVoterData(null);
      setPartyContracts([]);
      setUserParty(null);
      return;
    }

    const setup = async () => {
      setLoading(true);
      try {
        const provider = new ethers.BrowserProvider(walletProvider);
        const s = await provider.getSigner();
        setSigner(s);
        const c = initContracts(s);
        await detectRoles(address, c);
      } catch (err) {
        console.error('Setup error:', err);
      } finally {
        setLoading(false);
      }
    };

    setup();
  }, [isConnected, address, walletProvider, initContracts, detectRoles]);

  return (
    <Web3Context.Provider value={{
      account, signer, contracts, roles, voterData, loading,
      partyContracts, userParty, isConnected,
      openModal, disconnectWallet, refreshRoles, getPartyContract,
      ROLE_HASHES,
    }}>
      {children}
    </Web3Context.Provider>
  );
}