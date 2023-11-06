#!/bin/bash

rand1=$(( $RANDOM % 100 ))
rand2=$(( $RANDOM % 100 ))
rand3=$(( $RANDOM % 100 ))
rand4=$(( $RANDOM % 100 ))
rand5=$(( $RANDOM % 100 ))
rand6=$(( $RANDOM % 100 ))

echo "{\"scores\": {\"Problem 1\": $rand1, \"Problem 2\": $rand2, \"Problem 3\": $rand3, \"Problem 4\": $rand4, \"Problem 5\": $rand5, \"Problem 6\": $rand6}}"
