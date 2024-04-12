import fetch from "node-fetch";
import { SubgraphMapping } from "../utils/actionTypes";
import { createResultObject } from "src/dataMappings/utils/createResultObject";

export const subgraphAction = async (mapping: SubgraphMapping) => {
  const { endpoint, query, variables, seek, populate } = mapping;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({ query, variables }),
  });

  const { data } = await response.json();

  return createResultObject(data, seek, populate);
};
