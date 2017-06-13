#!/bin/bash
shopt -s expand_aliases

# prepare
## be sure at elements-next folder
cd "$(dirname "${BASH_SOURCE[0]}")"
for i in elementsd elements-cli elements-tx ; do
	which $i > /dev/null
	if [ ""$? != "0" ];then
		echo "cannot find [" $i "]"
		exit 1
	fi
done

DEMOD=$PWD/demo
ELDAE=elementsd
ELCLI=elements-cli
ELTX=elements-tx

## cleanup previous data
if [ -e ./demo.tmp ]; then
    ./stop_demo.sh
fi
echo "ELCLI=$ELCLI" >> ./demo.tmp

## cleanup previous data
rm -rf ${DEMOD}/data

echo "initial setup - asset generation"

## setup nodes
PORT=0
for i in alice bob charlie dave fred; do
    mkdir -p ${DEMOD}/data/$i
    cat <<EOF > ${DEMOD}/data/$i/elements.conf
rpcuser=user
rpcpassword=pass
rpcport=$((10000 + $PORT))
port=$((10001 + $PORT))

connect=localhost:$((10001 + $(($PORT + 10)) % 50))
regtest=1
daemon=0
listen=1
txindex=1
keypool=10
EOF
    let PORT=PORT+10
    alias ${i}-dae="${ELDAE} -datadir=${DEMOD}/data/$i"
    alias ${i}-tx="${ELTX}"
    alias ${i}="${ELCLI} -datadir=${DEMOD}/data/$i"
    echo "${i}_dir=\"-datadir=${DEMOD}/data/$i\"" >> ./demo.tmp
done

fred-dae &

LDW=1
while [ "${LDW}" = "1" ]
do
  LDW=0
  fred getwalletinfo > /dev/null 2>&1 || LDW=1
  if [ "${LDW}" = "1" ]; then
    sleep 1
  fi
done

echo "- generating initial blocks to reach maturity"

## generate assets
fred generate 100 >/dev/null

# FRB echo -n -e "- generating DEVELOPMENT asset"
DATA=$(fred issueasset 1000000 5000 | jq -r ".asset")
# FRB echo -n -e ": $DATA\n- generating MARKETING asset"
MODEL=$(fred issueasset 2000000 5000 | jq -r ".asset")
# FRB echo -n -e ": $MODEL\n- generating MONECRE asset"
# FRB MONECRE=$(fred issueasset 2000000 5000 | jq -r ".asset")
# FRB echo ": $MONECRE"

sleep 1

# FRB echo -n -e "final setup - starting daemons"

fred stop
sleep 1

## setup nodes phase 2
for i in alice bob charlie dave fred; do
    cat <<EOF >> ${DEMOD}/data/$i/elements.conf
assetdir=$DATA:DATA
assetdir=$MODEL:MODEL
# FRB assetdir=$MONECRE:MONECRE
EOF
    ${ELDAE} -datadir=${DEMOD}/data/$i &
    echo "${i}_dae=$!" >> ./demo.tmp
done

LDW=1
while [ "${LDW}" = "1" ]
do
  LDW=0
  alice getwalletinfo > /dev/null 2>&1 || LDW=1
  bob getwalletinfo > /dev/null 2>&1 || LDW=1
  charlie getwalletinfo > /dev/null 2>&1 || LDW=1
  dave getwalletinfo > /dev/null 2>&1 || LDW=1
  fred getwalletinfo > /dev/null 2>&1 || LDW=1
  if [ "${LDW}" = "1" ]; then
    echo -n -e "."
    sleep 1
  fi
done

echo " nodes started"

alice addnode 127.0.0.1:10011 onetry
bob addnode 127.0.0.1:10021 onetry
charlie addnode 127.0.0.1:10031 onetry
dave addnode 127.0.0.1:10041 onetry
fred addnode 127.0.0.1:10041 onetry

## generate assets
fred getwalletinfo

## preset asset
echo -n -e "DEVELOPMENT"
# fred sendtoaddress $(alice validateaddress $(alice getnewaddress) | jq -r ".unconfidential") 10000 "" "" false "DATA" >/dev/null
fred sendtoaddress $(alice getnewaddress) 10000 "" "" false "DATA" >/dev/null
sleep 1
echo -n -e "\nMARKETING"
# fred sendtoaddress $(alice validateaddress $(alice getnewaddress) | jq -r ".unconfidential") 5000 "" "" false "MODEL" >/dev/null
fred sendtoaddress $(alice getnewaddress) 5000 "" "" false "MODEL" >/dev/null
sleep 1
# FRB echo -n -e "\nMONECRE"
# FRB # fred sendtoaddress $(alice validateaddress $(alice getnewaddress) | jq -r ".unconfidential") 150 "" "" false "MONECRE" >/dev/null
# FRB fred sendtoaddress $(alice getnewaddress) 150 "" "" false "MONECRE" >/dev/null
echo -n -e "\n"
fred generate 1 >/dev/null
sleep 1 # wait for sync
# FRB echo "Alice wallet:"
alice getwalletinfo

# FRB echo -n -e "Sending to Charlie [               ]\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
for i in 100 200 300 400 500 1000 2000 5000 10000; do
# FRB  for j in DATA MODEL MONECRE; do
  for j in DATA MODEL; do
    # fred sendtoaddress $(charlie validateaddress $(charlie getnewaddress) | jq -r ".unconfidential") $i "" "" false "$j" >/dev/null
    fred sendtoaddress $(charlie getnewaddress) $i "" "" false "$j" >/dev/null
    echo -n -e "."
  done
done
echo ""
fred generate 1
sleep 1 # wait for sync
# FRB echo "Charlie wallet:"
charlie getwalletinfo

cd ${DEMOD}
for i in alice bob charlie dave fred; do
    ./$i &> out &
    echo "${i}_pid=$!" >> ../demo.tmp
done

cd "$(dirname "${BASH_SOURCE[0]}")"
sleep 2

echo " "
echo "Setup complete. Use these URLs to test it out:"
echo " "
echo " "
echo "http://127.0.0.1:8010/"
echo " "
echo "http://127.0.0.1:8030/order.html"
echo " "
echo "http://127.0.0.1:8030/list.html"
echo " "
echo " "
echo "When finished, run stop_demo.sh"
echo " "
echo " "
