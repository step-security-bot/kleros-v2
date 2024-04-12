import { extractChain } from "viem";
import { Chain, arbitrum, mainnet, arbitrumSepolia, gnosisChiado } from "viem/chains";

import { isProductionDeployment } from "./index";

export const DEFAULT_CHAIN = isProductionDeployment() ? arbitrum.id : arbitrumSepolia.id;

export const SUPPORTED_CHAINS: Record<number, Chain> = {
  [arbitrumSepolia.id]: arbitrumSepolia,
  [arbitrum.id]: arbitrum,
};

export const QUERY_CHAINS: Record<number, Chain> = {
  [gnosisChiado.id]: gnosisChiado,
  [mainnet.id]: mainnet,
};

export const ALL_CHAINS = [...Object.values(SUPPORTED_CHAINS), ...Object.values(QUERY_CHAINS)];

export const SUPPORTED_CHAIN_IDS = Object.keys(SUPPORTED_CHAINS);

export const QUERY_CHAIN_IDS = Object.keys(QUERY_CHAINS);

export const getChain = (chainId: number): Chain | null =>
  extractChain({
    chains: ALL_CHAINS,
    id: chainId,
  });
