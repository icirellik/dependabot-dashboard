#!/bin/bash

if [ -z "$GH_TOKEN" ]; then
  echo "Need GH_TOKEN"
  exit 1
fi

if [ -z "$GH_ORG" ]; then
  echo "Need GH_ORG"
  exit 1
fi

# Encoded "cursor:0", to be used as the first cursor.
REPO_CURSOR="Y3Vyc29yOjA="
REPO_HAS_NEXT_PAGE="true"

echo "repository,vulnerability_id,package,created_at,dismissed_at,severity,description" > vulnerabilities.csv

until [ "${REPO_HAS_NEXT_PAGE}" == "false" ]; do
  # echo "Reading page $(echo "${REPO_CURSOR}" | base64 -d)"

  # Fetch next set of data.
  DATA=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" \
    -X POST \
    -d "{ \"query\": \"query {  search(query: \\\"org:\\\"$GH_ORG\\\" archived:false\\\", type:REPOSITORY, first:100, after:\\\"$REPO_CURSOR\\\") {  edges {  node { ...on Repository {  name  }  }  }  pageInfo { endCursor, hasNextPage } repositoryCount }  }\" }" https://api.github.com/graphql)

  # Write to vulnerabilities to csv
  echo "${DATA}" | jq -r -c '.data.search.edges[].node | { repo: .name } | .repo'

  # Look for the next cursor, it will be base64 encoded or "null"
  REPO_CURSOR=$(echo "${DATA}" | jq -r .data.search.pageInfo.endCursor)
  REPO_HAS_NEXT_PAGE=$(echo "${DATA}" | jq -r .data.search.pageInfo.hasNextPage)
  TOTAL_COUNT=$(echo "${DATA}" | jq -r .data.search.repositoryCount)
  # echo "Repo Next?: ${TOTAL_COUNT} ${REPO_HAS_NEXT_PAGE} ${REPO_CURSOR}"
done
