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
  echo "Reading page $(echo "${REPO_CURSOR}" | base64 -d)"

  # Fetch next set of data.
  DATA=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" \
    -X POST \
    -d "{ \"query\": \"query {  search(query: \\\"org:\\\"$GH_ORG\\\" archived:false\\\", type:REPOSITORY, first:100, after:\\\"$REPO_CURSOR\\\") {  edges {  node { ...on Repository {  name vulnerabilityAlerts(first: 100) {  nodes {  id createdAt dismissedAt securityVulnerability {  package { name } advisory { description } severity  }  } pageInfo { endCursor, hasNextPage } totalCount }  }  }  }  pageInfo { endCursor, hasNextPage } repositoryCount }  }\" }" https://api.github.com/graphql)

  echo "Vulnerability: hasNextPage"
  echo "${DATA}" | jq -r -c .data.search.edges[].node | while read -r line ; do
    VULN_CURSOR=$(echo "${line}" | jq -r .vulnerabilityAlerts.pageInfo.endCursor)
    VULN_HAS_NEXT_PAGE=$(echo "${line}" | jq -r .vulnerabilityAlerts.pageInfo.hasNextPage)
    TOTAL_COUNT=$(echo "${line}" | jq -r .vulnerabilityAlerts.totalCount)
    NAME=$(echo "${line}" | jq -r .name)

    if [ "${VULN_HAS_NEXT_PAGE}" == "true" ]; then
      echo "Vulnerability Next?: ${NAME} ${VULN_HAS_NEXT_PAGE} ${VULN_CURSOR} ${TOTAL_COUNT}"
    fi

    until [ "${VULN_HAS_NEXT_PAGE}" == "false" ]; do
      # Fetch next set of vuln data.
      DATA=$(curl -s -H "Authorization: Bearer ${GH_TOKEN}" \
        -X POST \
        -d "{ \"query\": \"query {  search(query: \\\"repo:\\\"$GH_ORG\\\"/${NAME}\\\", type:REPOSITORY, first:100) {  edges {  node { ...on Repository {  name vulnerabilityAlerts(first: 100, after:\\\"${VULN_CURSOR}\\\") {  nodes {  id createdAt dismissedAt securityVulnerability {  package { name } advisory { description } severity  }  } pageInfo { endCursor, hasNextPage } totalCount }  }  }  }  pageInfo { endCursor, hasNextPage } repositoryCount }  }\" }" https://api.github.com/graphql)

      # Write to vulnerabilities to csv
      echo "${DATA}" | jq -r '.data.search.edges[].node | {repo: .name, vulnerabilityAlert: .vulnerabilityAlerts.nodes[]} | [.repo, .vulnerabilityAlert.id, .vulnerabilityAlert.securityVulnerability.package.name, .vulnerabilityAlert.createdAt, .vulnerabilityAlert.dismissedAt, .vulnerabilityAlert.securityVulnerability.severity, .vulnerabilityAlert.securityVulnerability.advisory.description] | @csv' >> vulnerabilities.csv

      # Look for next vulnerability cursor.
      VULN_CURSOR=$(echo "${DATA}" | jq -r .data.search.edges[].node.vulnerabilityAlerts.pageInfo.endCursor)
      VULN_HAS_NEXT_PAGE=$(echo "${DATA}" | jq -r .data.search.edges[].node.vulnerabilityAlerts.pageInfo.hasNextPage)
      TOTAL_COUNT=$(echo "${DATA}" | jq -r .data.search.edges[].node.vulnerabilityAlerts.totalCount)
      echo "Vulnerability Next?: ${TOTAL_COUNT} ${VULN_HAS_NEXT_PAGE} ${VULN_CURSOR}"
    done
  done

  # Write to vulnerabilities to csv
  echo "${DATA}" | jq -r '.data.search.edges[].node | {repo: .name, vulnerabilityAlert: .vulnerabilityAlerts.nodes[]} | [.repo, .vulnerabilityAlert.id, .vulnerabilityAlert.securityVulnerability.package.name, .vulnerabilityAlert.createdAt, .vulnerabilityAlert.dismissedAt, .vulnerabilityAlert.securityVulnerability.severity, .vulnerabilityAlert.securityVulnerability.advisory.description] | @csv' >> vulnerabilities.csv

  # Look for the next cursor, it will be base64 encoded or "null"
  REPO_CURSOR=$(echo "${DATA}" | jq -r .data.search.pageInfo.endCursor)
  REPO_HAS_NEXT_PAGE=$(echo "${DATA}" | jq -r .data.search.pageInfo.hasNextPage)
  TOTAL_COUNT=$(echo "${DATA}" | jq -r .data.search.repositoryCount)
  echo "Repo Next?: ${TOTAL_COUNT} ${REPO_HAS_NEXT_PAGE} ${REPO_CURSOR}"
done

