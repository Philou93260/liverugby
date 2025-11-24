#!/bin/bash

# Script pour tester l'API Rugby actuelle
# Usage: ./test-current-api.sh <VOTRE_CLE_API> <MATCH_ID>

API_KEY="${1:-VOTRE_CLE_API}"
MATCH_ID="${2:-49925}"

echo "🔍 Test de l'API Rugby pour le match $MATCH_ID"
echo ""

curl -X GET "https://v1.rugby.api-sports.io/games?id=$MATCH_ID" \
  -H "x-apisports-key: $API_KEY" \
  -H "Content-Type: application/json" | jq '
{
  results: .results,
  match: .response[0] | {
    id: .id,
    teams: (.teams.home.name + " vs " + .teams.away.name),
    status: .status.short,
    score: "\(.scores.home) - \(.scores.away)",
    hasEvents: (.events != null),
    eventsCount: (.events | length),
    events: .events[0:5]
  }
}'
