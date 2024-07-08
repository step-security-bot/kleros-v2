import React, { createContext, useState, useContext, useMemo } from "react";

import { Address } from "viem";

import { DEFAULT_CHAIN } from "consts/chains";
import { disputeResolverAddress, klerosCoreAddress } from "hooks/contracts/generated";
import { useLocalStorage } from "hooks/useLocalStorage";
import { isUndefined } from "utils/index";

export type Answer = {
  id: string;
  title: string;
  description: string;
  reserved?: boolean;
};

export type AliasArray = {
  id?: string;
  name: string;
  address: string | Address;
  isValid?: boolean;
};

export type Alias = Record<string, string>;
export interface IDisputeTemplate {
  answers: Answer[];
  arbitrableAddress?: string;
  arbitrableChainID?: string;
  arbitratorAddress?: string;
  arbitratorChainID?: string;
  category: string;
  description: string;
  frontendUrl?: string;
  lang?: string;
  policyURI?: string;
  question: string;
  specification?: string;
  title: string;
  aliases?: Alias;
  version: string;
  // attachment: Attachment;
  // type: string;
}

interface IDisputeData extends IDisputeTemplate {
  courtId?: string;
  numberOfJurors: number;
  arbitrationCost?: string;
  aliasesArray?: AliasArray[];
}

interface INewDisputeContext {
  disputeData: IDisputeData;
  setDisputeData: (disputeData: IDisputeData) => void;
  disputeTemplate: IDisputeTemplate;
  resetDisputeData: () => void;
  isSubmittingCase: boolean;
  setIsSubmittingCase: (isSubmittingCase: boolean) => void;
  isPolicyUploading: boolean;
  setIsPolicyUploading: (isPolicyUploading: boolean) => void;
}

const initialDisputeData: IDisputeData = {
  numberOfJurors: 3,
  title: "",
  description: "",
  question: "",
  category: "",
  answers: [
    { title: "", id: "1", description: "" },
    { title: "", id: "2", description: "" },
  ],
  aliasesArray: [{ name: "", address: "", id: "1" }],
  version: "1.0",
};
const initialDisputeTemplate = initialDisputeData as IDisputeTemplate;

const NewDisputeContext = createContext<INewDisputeContext>({
  disputeData: initialDisputeData,
  setDisputeData: () => {},
  disputeTemplate: initialDisputeTemplate,
  resetDisputeData: () => {},
  isSubmittingCase: false,
  setIsSubmittingCase: () => {},
  isPolicyUploading: false,
  setIsPolicyUploading: () => {},
});

export const useNewDisputeContext = () => useContext(NewDisputeContext);

export const NewDisputeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [disputeData, setDisputeData] = useLocalStorage<IDisputeData>("disputeData", initialDisputeData);
  const [isSubmittingCase, setIsSubmittingCase] = useState<boolean>(false);
  const [isPolicyUploading, setIsPolicyUploading] = useState<boolean>(false);

  const disputeTemplate = useMemo(() => constructDisputeTemplate(disputeData), [disputeData]);

  const resetDisputeData = () => {
    setDisputeData(initialDisputeData);
  };

  const contextValues = useMemo(
    () => ({
      disputeData,
      setDisputeData,
      disputeTemplate,
      resetDisputeData,
      isSubmittingCase,
      setIsSubmittingCase,
      isPolicyUploading,
      setIsPolicyUploading,
    }),
    [disputeData, disputeTemplate, resetDisputeData, isSubmittingCase, isPolicyUploading]
  );

  return <NewDisputeContext.Provider value={contextValues}>{children}</NewDisputeContext.Provider>;
};

const constructDisputeTemplate = (disputeData: IDisputeData) => {
  const baseTemplate = { ...disputeData };

  if (!isUndefined(baseTemplate.aliasesArray)) {
    baseTemplate.aliasesArray = baseTemplate.aliasesArray.filter((item) => item.address !== "" && item.isValid);
    if (baseTemplate.aliasesArray.length === 0) delete baseTemplate.aliasesArray;
    else {
      const aliases: Alias = {};

      for (const alias of baseTemplate.aliasesArray) {
        aliases[alias.name] = alias.address;
      }

      baseTemplate.aliases = aliases;
    }
  }

  for (const answer of baseTemplate.answers) {
    answer.id = "0x" + BigInt(answer.id).toString(16);
  }
  if (!isUndefined(baseTemplate.policyURI) && baseTemplate.policyURI === "") delete baseTemplate.policyURI;

  // in future if we support chain switching these would need to be calculated from connected 'chainId'
  baseTemplate.arbitrableAddress = disputeResolverAddress[DEFAULT_CHAIN];
  baseTemplate.arbitrableChainID = DEFAULT_CHAIN.toString();
  baseTemplate.arbitratorAddress = klerosCoreAddress[DEFAULT_CHAIN];
  baseTemplate.arbitratorChainID = DEFAULT_CHAIN.toString();

  return baseTemplate as IDisputeTemplate;
};
