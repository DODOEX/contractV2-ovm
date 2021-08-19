#!/bin/bash
# truffle compile --all

if [ "$1"x = "proxy-dpp"x ]
then
	truffle test ./test/V2Proxy/proxy.dpp.test.ts
fi
 
if [ "$1"x = "proxy-dvm"x ]
then
	truffle test ./test/V2Proxy/proxy.dvm.test.ts
fi

if [ "$1"x = "proxy-mix"x ]
then
	truffle test ./test/V2Proxy/proxy.mix.test.ts
fi


if [ "$1"x = "proxy-cp"x ]
then
	truffle test ./test/V2Proxy/proxy.cp.test.ts
fi


if [ "$1"x = "erc20-mine"x ]
then
	truffle test ./test/DODOMineV2/erc20Mine.test.ts
fi

if [ "$1"x = "nft"x ]
then
	truffle test ./test/DODONFT/nftMainFlow.test.ts
fi