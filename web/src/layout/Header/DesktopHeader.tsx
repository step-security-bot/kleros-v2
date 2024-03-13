import React from "react";
import styled, { css } from "styled-components";

import { Link } from "react-router-dom";
import { useToggle } from "react-use";

import KlerosCourtUniversityLogo from "svgs/header/kleros-court-university.svg";
import KlerosCourtLogo from "svgs/header/kleros-court.svg";
import KlerosSolutionsIcon from "svgs/menu-icons/kleros-solutions.svg";

import { useLockOverlayScroll } from "hooks/useLockOverlayScroll";

import { landscapeStyle } from "styles/landscapeStyle";
import { responsiveSize } from "styles/responsiveSize";

import ConnectWallet from "components/ConnectWallet";
import LightButton from "components/LightButton";
import { Overlay } from "components/Overlay";

import DappList from "./navbar/DappList";
import Explore from "./navbar/Explore";
import Menu from "./navbar/Menu";
import Help from "./navbar/Menu/Help";
import Settings from "./navbar/Menu/Settings";

import { PopupContainer } from ".";

const IS_UNIVERSITY = process.env.REACT_APP_UNIVERSITY_COURT === "true";

const Container = styled.div`
  display: none;
  position: absolute;

  ${landscapeStyle(
    () => css`
      display: flex;
      align-items: center;
      justify-content: space-between;
      width: 100%;
      position: relative;
    `
  )};
`;

const LeftSide = styled.div`
  display: flex;
`;

const MiddleSide = styled.div`
  display: flex;
  position: absolute;
  left: 50%;
  top: 50%;
  transform: translate(-50%, -50%);
  color: ${({ theme }) => theme.white} !important;
`;

const RightSide = styled.div`
  display: flex;
  gap: ${responsiveSize(8, 16, 300, 1024)};

  margin-left: 8px;
  canvas {
    width: 20px;
  }
`;

const LightButtonContainer = styled.div`
  display: flex;
  align-items: center;
  width: 16px;
  margin-left: ${responsiveSize(4, 8)};
  margin-right: ${responsiveSize(12, 16)};
`;

const StyledLink = styled(Link)`
  min-height: 48px;
`;

const StyledKlerosSolutionsIcon = styled(KlerosSolutionsIcon)`
  fill: ${({ theme }) => theme.white} !important;
`;

const ConnectWalletContainer = styled.div`
  label {
    color: ${({ theme }) => theme.white};
  }
`;

const DesktopHeader = () => {
  const [isDappListOpen, toggleIsDappListOpen] = useToggle(false);
  const [isHelpOpen, toggleIsHelpOpen] = useToggle(false);
  const [isSettingsOpen, toggleIsSettingsOpen] = useToggle(false);
  useLockOverlayScroll(isDappListOpen || isHelpOpen || isSettingsOpen);

  return (
    <>
      <Container>
        <LeftSide>
          <LightButtonContainer>
            <LightButton
              text=""
              onClick={() => {
                toggleIsDappListOpen();
              }}
              Icon={StyledKlerosSolutionsIcon}
            />
          </LightButtonContainer>
          <StyledLink to={"/"}>{IS_UNIVERSITY ? <KlerosCourtUniversityLogo /> : <KlerosCourtLogo />}</StyledLink>
        </LeftSide>

        <MiddleSide>
          <Explore />
        </MiddleSide>

        <RightSide>
          <ConnectWalletContainer>
            <ConnectWallet />
          </ConnectWalletContainer>
          <Menu {...{ toggleIsHelpOpen, toggleIsSettingsOpen }} />
        </RightSide>
      </Container>
      {(isDappListOpen || isHelpOpen || isSettingsOpen) && (
        <PopupContainer>
          <Overlay />
          {isDappListOpen && <DappList {...{ toggleIsDappListOpen, isDappListOpen }} />}
          {isHelpOpen && <Help {...{ toggleIsHelpOpen, isHelpOpen }} />}
          {isSettingsOpen && <Settings {...{ toggleIsSettingsOpen, isSettingsOpen }} />}
        </PopupContainer>
      )}
    </>
  );
};
export default DesktopHeader;
