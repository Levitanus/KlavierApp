#!/bin/bash

# Script to create 30 test students
# Usage: ./create_test_students.sh <admin_token>

if [ -z "$1" ]; then
    echo "Usage: $0 <admin_token>"
    echo "Please provide an admin JWT token"
    exit 1
fi

TOKEN="$1"
BASE_URL="http://localhost:8080"

# Array of sample first names
FIRST_NAMES=("Alice" "Bob" "Charlie" "Diana" "Emma" "Frank" "Grace" "Henry" "Iris" "Jack" "Kate" "Leo" "Maya" "Noah" "Olivia" "Peter" "Quinn" "Rose" "Sam" "Tina" "Uma" "Victor" "Wendy" "Xander" "Yara" "Zack" "Anna" "Ben" "Clara" "David")

# Array of sample last names
LAST_NAMES=("Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis" "Rodriguez" "Martinez" "Hernandez" "Lopez" "Gonzalez" "Wilson" "Anderson" "Thomas" "Taylor" "Moore" "Jackson" "Martin" "Lee" "Walker" "Hall" "Allen" "Young" "King" "Wright" "Scott" "Torres" "Nguyen")

# Array of sample streets
STREETS=("Main St" "Oak Ave" "Pine Rd" "Maple Dr" "Cedar Ln" "Elm Way" "Birch Ct" "Willow St" "Cherry Ave" "Spruce Rd")

for i in {1..30}; do
    # Generate random data
    FIRST=${FIRST_NAMES[$((i-1))]}
    LAST=${LAST_NAMES[$((i-1))]}
    FULL_NAME="$FIRST $LAST"
    USERNAME="student$(printf "%02d" $i)"
    PASSWORD="password$i"
    ADDRESS="$((100 + RANDOM % 900)) ${STREETS[$((RANDOM % 10))]}"
    
    # Generate random birthday between 2005-2018
    YEAR=$((2005 + RANDOM % 14))
    MONTH=$(printf "%02d" $((1 + RANDOM % 12)))
    DAY=$(printf "%02d" $((1 + RANDOM % 28)))
    BIRTHDAY="$YEAR-$MONTH-$DAY"
    
    echo "Creating student $i: $USERNAME ($FULL_NAME)"
    
    curl -X POST "$BASE_URL/api/admin/students" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"username\": \"$USERNAME\",
            \"password\": \"$PASSWORD\",
            \"full_name\": \"$FULL_NAME\",
            \"address\": \"$ADDRESS\",
            \"birthday\": \"$BIRTHDAY\"
        }" \
        -s -o /dev/null -w "Status: %{http_code}\n"
    
    # Small delay to avoid overwhelming the server
    sleep 0.1
done

echo "Done! Created 30 test students."
echo "Usernames: student01 to student30"
echo "Passwords: password1 to password30"
