import React, { useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import styled from "styled-components";
import Identicon from "react-identicons";
import ArrowIcon from "assets/svgs/icons/arrow.svg";
import { useKlerosCoreCurrentRuling } from "hooks/contracts/generated";
import { useDisputeDetailsQuery } from "queries/useDisputeDetailsQuery";
import { useDisputeTemplate } from "queries/useDisputeTemplate";
import LightButton from "../LightButton";
import VerdictBanner from "./VerdictBanner";
import { responsiveSize } from "styles/responsiveSize";
import { useVotingContext } from "hooks/useVotingContext";
import Skeleton from "react-loading-skeleton";
import { useAccount } from "wagmi";

const Container = styled.div`
  width: 100%;
`;

const JuryContainer = styled.div`
  display: flex;
  flex-direction: column;
  gap: 8px;
  h3 {
    line-height: 21px;
    margin-bottom: 0px;
  }
`;

const JuryDecisionTag = styled.small`
  font-weight: 400;
  line-height: 19px;
  color: ${({ theme }) => theme.secondaryText};
`;

const UserContainer = styled.div`
  display: flex;
  align-items: center;
  margin: 22px 0px;
  gap: 10px;
`;

const AliasTag = styled.div`
  display: flex;
  flex-direction: column;
  small {
    font-weight: 400;
    line-height: 19px;
  }
`;

const StyledIdenticon = styled(Identicon)`
  width: 24px;
  height: 24px;
  border-radius: 100%;
`;

const Title = styled.small`
  color: ${({ theme }) => theme.secondaryText};
`;

const StyledButton = styled(LightButton)`
  display: flex;
  flex-direction: row-reverse;
  gap: 8px;
  > .button-text {
    color: ${({ theme }) => theme.primaryBlue};
  }
  padding-top: 0px;
`;

const AnswerTitle = styled.h3`
  margin: 0;
`;

const Divider = styled.hr`
  display: flex;
  border: none;
  height: 1px;
  background-color: ${({ theme }) => theme.stroke};
  margin: ${responsiveSize(16, 32)} 0px;
`;

interface IFinalDecision {
  arbitrable?: `0x${string}`;
}

const FinalDecision: React.FC<IFinalDecision> = ({ arbitrable }) => {
  const { id } = useParams();
  const { isDisconnected } = useAccount();
  const { data: disputeTemplate } = useDisputeTemplate(id, arbitrable);
  const { data: disputeDetails } = useDisputeDetailsQuery(id);
  const { wasDrawn, hasVoted, isLoading, isCommitPeriod, isVotingPeriod, commited } = useVotingContext();
  const ruled = disputeDetails?.dispute?.ruled ?? false;
  const navigate = useNavigate();
  const { data: currentRulingArray } = useKlerosCoreCurrentRuling({ args: [BigInt(id ?? 0)], watch: true });
  const currentRuling = Number(currentRulingArray?.[0]);
  const answer = disputeTemplate?.answers?.[currentRuling! - 1];
  const buttonText = useMemo(() => {
    if (!wasDrawn || isDisconnected) return "Check how the jury voted";
    if (disputeDetails?.dispute?.period === "evidence") return "You were drawn";
    if (isCommitPeriod) return commited ? "You have committed" : "Commit your vote";
    if (isVotingPeriod && !commited) return "You failed to commit";
    if (isVotingPeriod && !hasVoted) return "Cast your vote";
    return hasVoted ? "You have voted" : "You have not appeared for juror duty";
  }, [wasDrawn, hasVoted, isCommitPeriod, isVotingPeriod, commited]);

  return (
    <Container>
      <VerdictBanner ruled={ruled} />

      <JuryContainer>
        {ruled ? (
          <JuryDecisionTag>The jury decided in favor of:</JuryDecisionTag>
        ) : (
          <JuryDecisionTag>This option is winning:</JuryDecisionTag>
        )}
        {answer ? (
          <div>
            <AnswerTitle>{answer.title}</AnswerTitle>
            <small>{answer.description}</small>
          </div>
        ) : (
          <>{currentRuling !== 0 ? <h3>Answer 0x{currentRuling}</h3> : <h3>Refuse to Arbitrate</h3>}</>
        )}
      </JuryContainer>
      <Divider />
      {disputeTemplate?.aliases && (
        <>
          <UserContainer>
            <StyledIdenticon size="24" />
            <AliasTag>
              {disputeTemplate?.aliases?.challenger && <small>Alice.eth</small>}
              <Title>Claimant</Title>
            </AliasTag>
          </UserContainer>
          <Divider />
        </>
      )}
      {isLoading && !isDisconnected ? (
        <Skeleton width={250} height={20} />
      ) : (
        <StyledButton
          onClick={() => navigate(`/cases/${id?.toString()}/voting`)}
          text={buttonText}
          Icon={ArrowIcon}
          className="reverse-button"
        />
      )}
    </Container>
  );
};

export default FinalDecision;
