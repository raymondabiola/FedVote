import { createAppKit } from "@reown/appkit/react";
import { EthersAdapter } from "@reown/appkit-adapter-ethers";
import { type AppKitNetwork } from "@reown/appkit/networks";

const projectId = import.meta.env.VITE_APPKIT_PROJECT_ID;

export const hederaTestnet: AppKitNetwork = {
  id: 296,
  name: "Hedera Testnet",
  nativeCurrency: { name: "HBAR", symbol: "HBAR", decimals: 18 },
  rpcUrls: {
    default: {
      http: ["https://testnet.hashio.io/api"],
    },
  },
  blockExplorers: {
    default: { name: "HashScan", url: "https://hashscan.io/testnet" },
  },
  chainNamespace: "eip155" as const,
  caipNetworkId: "eip155:296" as const,
};

const networks: [AppKitNetwork, ...AppKitNetwork[]] = [hederaTestnet];

const metadata = {
  name: "FedVote",
  description: "Decentralized Federal Voting System on Hedera",
  url: "https://fedvote.app",
  icons: ["https://avatars.githubusercontent.com/u/179229932"],
};

export const appkit = createAppKit({
  adapters: [new EthersAdapter()],
  networks,
  metadata,
  projectId,
  allowUnsupportedChain: false,
  allWallets: "SHOW",
  defaultNetwork: hederaTestnet,
  enableEIP6963: true,
  features: {
    analytics: true,
    allWallets: true,
    email: false,
    socials: [],
  },
});

appkit.switchNetwork(hederaTestnet);
