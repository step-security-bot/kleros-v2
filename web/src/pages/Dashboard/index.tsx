import React, { useState } from "react";
import styled from "styled-components";
import { useAccount } from "wagmi";
import { useCasesQuery } from "queries/useCasesQuery";
import JurorInfo from "./JurorInfo";
import Courts from "./Courts";
import CasesDisplay from "components/CasesDisplay";
import ConnectWallet from "components/ConnectWallet";

const Container = styled.div`
  width: 100%;
  min-height: calc(100vh - 144px);
  background-color: ${({ theme }) => theme.lightBackground};
  padding: calc(32px + (136 - 32) * (min(max(100vw, 375px), 1250px) - 375px) / 875);
  padding-top: calc(32px + (80 - 32) * (min(max(100vw, 375px), 1250px) - 375px) / 875);
  padding-bottom: calc(64px + (96 - 64) * (min(max(100vw, 375px), 1250px) - 375px) / 875);
`;

const StyledCasesDisplay = styled(CasesDisplay)`
  margin-top: 64px;

  h1 {
    margin-bottom: calc(16px + (48 - 16) * (min(max(100vw, 375px), 1250px) - 375px) / 875);
  }
`;

const ConnectWalletContainer = styled.div`
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  color: ${({ theme }) => theme.primaryText};
`;

const Dashboard: React.FC = () => {
  const { isConnected } = useAccount();
  const [currentPage, setCurrentPage] = useState(1);
  const casesPerPage = 3;
  const { data } = useCasesQuery(casesPerPage * (currentPage - 1));

  return (
    <Container>
      {isConnected ? (
        <>
          <JurorInfo />
          <Courts />
          <StyledCasesDisplay
            title="My Cases"
            disputes={data ? data.disputes : []}
            numberDisputes={data ? data.counter?.cases : 0}
            {...{ currentPage, setCurrentPage, casesPerPage }}
          />
        </>
      ) : (
        <ConnectWalletContainer>
          To see your dashboard, connect first
          <hr />
          <ConnectWallet />
        </ConnectWalletContainer>
      )}
    </Container>
  );
};

export default Dashboard;
