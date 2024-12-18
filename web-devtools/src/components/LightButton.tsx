import React from "react";
import styled from "styled-components";

import { Button } from "@kleros/ui-components-library";

const StyledButton = styled(Button)`
  .button-text {
    font-weight: 400;
  }
  .button-svg {
    fill: ${({ theme }) => theme.klerosUIComponentsSecondaryPurple};
  }
`;

interface ILightButton {
  text: string;
  Icon?: React.FC<React.SVGAttributes<SVGElement>>;
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
  disabled?: boolean;
  className?: string;
}

const LightButton: React.FC<ILightButton> = ({ text, Icon, onClick, disabled, className }) => (
  <StyledButton variant="primary" small {...{ text, Icon, onClick, disabled, className }} />
);

export default LightButton;
