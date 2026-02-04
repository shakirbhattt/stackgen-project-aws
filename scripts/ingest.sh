#!/bin/bash
# StackGen Data Ingestion Script
# Inserts 10,000 rows of sensor data into ClickHouse

# Configuration
CLICKHOUSE_HOST="localhost"
CLICKHOUSE_PORT="8123"
DB_NAME="stackgen"
TABLE_NAME="readings"
USER="default"
PASSWORD=""

echo "========================================"
echo "StackGen ClickHouse Data Ingestion"
echo "========================================"
echo "Target: $DB_NAME.$TABLE_NAME"
echo "Host: $CLICKHOUSE_HOST:$CLICKHOUSE_PORT"
echo ""

echo "Generating 10,000 rows of sensor data..."

FILE="stackgen-data.csv"
> $FILE

for i in {1..10000}; do
  if [[ "$OSTYPE" == "darwin"* ]]; then
    TS=$(date -v-$((RANDOM % 86400))S -u +'%Y-%m-%d %H:%M:%S')
  else
    TS=$(date -u -d "today -$((RANDOM % 86400)) seconds" +'%Y-%m-%d %H:%M:%S' 2>/dev/null)
  fi
  
  SID=$((RANDOM % 100 + 1))
  TEMP="$((RANDOM % 30 + 20)).$((RANDOM % 99))"
  HUM="$((RANDOM % 50 + 30)).$((RANDOM % 99))"
  
  echo "$TS,$SID,$TEMP,$HUM" >> $FILE
  
  if [ $((i % 1000)) -eq 0 ]; then
    echo "  Generated $i rows..."
  fi
done

echo "✓ Generated 10,000 rows"
echo ""

echo "Inserting data into $DB_NAME.$TABLE_NAME..."

RESPONSE=$(curl -sS -w "\nHTTP_CODE:%{http_code}" -X POST \
  "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/?query=INSERT+INTO+$DB_NAME.$TABLE_NAME+FORMAT+CSV" \
  -u "$USER:$PASSWORD" \
  --data-binary @$FILE)

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)

if [ "$HTTP_CODE" = "200" ]; then
  echo "✓ Data inserted successfully!"
else
  echo "✗ Error inserting data (HTTP $HTTP_CODE)"
  rm $FILE
  exit 1
fi

echo ""
echo "Verifying total row count..."

COUNT=$(curl -sS \
  "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/?query=SELECT+count()+FROM+$DB_NAME.$TABLE_NAME" \
  -u "$USER:$PASSWORD")

echo "✓ Total rows in table: $COUNT"

if [ "$COUNT" -ge "10000" ]; then
  echo "✓ Verification passed!"
else
  echo "⚠ Warning: Expected 10000+ rows, got $COUNT"
fi

echo ""
echo "Data distribution across shards:"
curl -sS \
  "http://$CLICKHOUSE_HOST:$CLICKHOUSE_PORT/?query=SELECT+_shard_num+as+shard,+count()+as+rows+FROM+$DB_NAME.$TABLE_NAME+GROUP+BY+_shard_num+ORDER+BY+_shard_num+FORMAT+PrettyCompact" \
  -u "$USER:$PASSWORD"

rm $FILE
echo ""
echo "✓ Cleanup completed"
echo "========================================"
echo "StackGen ingestion complete!"
echo "========================================"
