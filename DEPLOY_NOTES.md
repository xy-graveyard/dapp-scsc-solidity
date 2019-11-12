Kovan:
0x1a2C4a6Ffd72848E7bD63d2177c29a0aC80c6386 XyStakingConsensus
0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084 XyBlockProducer
0xbF68070E5E84cae28f10161088edA1747A5963Ee XyGovernance
0x210241f42bC94Eb9da7b4E0A841f3b340B569291 PLCRVoting
0xAB0245d3971E5E01C4E5273350B5cB9CBe46aA8B XyBond
0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f XyFaucet

Mainnet:
0x0242514106114DEaA99Fd81574142c36Edb03B6D XyStakingConsensus
0xd3034c290E19959Fdc18E5597F375CA51BFB0c41 XyBlockProducer
0x01925d0fFE4a6a6162B51ba611e3D4780Fc2dF42 XyGovernance
0x72bCDb36d1545FEA06905a1bb4998424580AAee6 PLCRVoting
0x1a024A698EEBdB86ccf3fCaF2F589839bdc066AD XyBond
0x55296f69f40Ea6d20E478533C15A6B08B654E758 XYO

V0.2.3 deploy

Deployer for kovan: 0x316D5E10f4E4ad94499149c0131a44FC17EF995B

Kovan:

npx zos session --network kovan --from 0x316D5E10f4E4ad94499149c0131a44FC17EF995B --expires 2500

npx zos bump 0.2.3
npx zos push
npx zos update XyStakingConsensus

Mainnet:

npx zos session --network mainnet --from 0x6792B02f88b32C4FE8e31cfA41ae5aF44865f930 --expires 2500

npx zos push
npx zos update XyStakingConsensus

V0.2.2 deploy

Deployer for kovan: 0x316D5E10f4E4ad94499149c0131a44FC17EF995B

Kovan:

npx zos session --network kovan --from 0x316D5E10f4E4ad94499149c0131a44FC17EF995B --expires 2500

npx zos bump 0.2.2
npx zos push
npx zos update XyStakingConsensus
npx zos publish

Mainnet:

npx zos session --network mainnet --from 0x6792B02f88b32C4FE8e31cfA41ae5aF44865f930 --expires 2500

npx zos push
npx zos update XyStakingConsensus
npx zos publish

Minimized ABI:
QmXM19CmChak3G3xq2e2XkahouVXNzBtkeGfrsTFBNgrXw v0.2.2/PLCRVoting.json
Qmc2kRGQQ5GumtFEvZ4EEdZU2nos45bERCbrwxKKYtokxY v0.2.2/XYO.json
QmbcfMGhtC1PCw6pkjHyv4zAqwvgvqE5xFgMUnj6cvqdEb v0.2.2/XyBlockProducer.json
QmTxexw2uM2snGsfB5a1n1c1Yv1xMdw9cWDBJEwAufeqR6 v0.2.2/XyBond.json
Qmck9Z9TiHpwN5tptpmaA13eHNutBHJw7q2TqKnvDJ1chY v0.2.2/XyFaucet.json
QmQdhZBYc43D3SdTbZFyboUCFjyHi1mX5w2mC5MiCRW4hd v0.2.2/XyGovernance.json
Qmaku9bF7But3y1n2FVa52ngMGWp3HmfNmbpiRCXR9AQjs v0.2.2/XyStakingConsensus.json
QmXTSSTYH4SYxGFQ7nQgxhmxrZS7a8BCm5qQJcKWQU12Ws v0.2.2

V0.2.1 deploy

Deployer for kovan: 0x316D5E10f4E4ad94499149c0131a44FC17EF995B

Kovan:

npx zos session --network kovan --from 0x316D5E10f4E4ad94499149c0131a44FC17EF995B --expires 2500

npx zos bump 0.2.1

// Initialize the contracts for session
npx zos push

npx zos update XyBond

npx zos update XyStakingConsensus

Mainnet:

npx zos session --network mainnet --from 0x6792B02f88b32C4FE8e31cfA41ae5aF44865f930 --expires 2500

npx zos push

npx zos update XyBond

npx zos update XyStakingConsensus

Minimized ABI:
QmXM19CmChak3G3xq2e2XkahouVXNzBtkeGfrsTFBNgrXw v0.2.1/PLCRVoting.json
Qmc2kRGQQ5GumtFEvZ4EEdZU2nos45bERCbrwxKKYtokxY v0.2.1/XYO.json
QmbcfMGhtC1PCw6pkjHyv4zAqwvgvqE5xFgMUnj6cvqdEb v0.2.1/XyBlockProducer.json
QmTxexw2uM2snGsfB5a1n1c1Yv1xMdw9cWDBJEwAufeqR6 v0.2.1/XyBond.json
Qmck9Z9TiHpwN5tptpmaA13eHNutBHJw7q2TqKnvDJ1chY v0.2.1/XyFaucet.json
QmQdhZBYc43D3SdTbZFyboUCFjyHi1mX5w2mC5MiCRW4hd v0.2.1/XyGovernance.json
Qmaku9bF7But3y1n2FVa52ngMGWp3HmfNmbpiRCXR9AQjs v0.2.1/XyStakingConsensus.json
QmXTSSTYH4SYxGFQ7nQgxhmxrZS7a8BCm5qQJcKWQU12Ws v0.2.1

V0.2.0 deploy

Deployer for kovan: 0x316D5E10f4E4ad94499149c0131a44FC17EF995B

Kovan:

npx zos session --network kovan --from 0x316D5E10f4E4ad94499149c0131a44FC17EF995B --expires 2500

npx zos add XyBond

npx zos bump 0.2.0

// Initialize the contracts for session
npx zos push

npx zos create XyBond --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f,0x1a2C4a6Ffd72848E7bD63d2177c29a0aC80c6386,14515200"

0xAB0245d3971E5E01C4E5273350B5cB9CBe46aA8B

npx zos update XyStakingConsensus

Update bond contract on stakingConsensusContract using XyBondContract governance param and dapper.layerone.co
ownerSet('XyBondContract', 0xAB0245d3971E5E01C4E5273350B5cB9CBe46aA8B)

npx zos publish
Using session with network kovan, sender address 0x316D5E10f4E4ad94499149c0131a44FC17EF995B, timeout 600 seconds
Publishing project to kovan...
Deploying new App...
Deployed App at 0x05bf20D3190cc42C3615797a6B50D19Cedb25814
Deploying new Package...
Deployed Package 0x7849439d0eeDa8931521263312348df97a095acc
Adding new version...
Deploying new ImplementationDirectory...
Deployed ImplementationDirectory at 0x22f8517215bFbDeaF8B76750541bE56ef57f6Ec3
Added version 0.2.1
Registering implementation of XyGovernance at 0x3a1637E066D5433747Aebd60355C5F8C6FFFec78 in directory...
Registering implementation of XyBlockProducer at 0x8D00E6c2dFa82Cd18c37A14964C88808d9E835e5 in directory...
Registering implementation of XyStakingConsensus at 0x142d25FBb26b0469725663eb0C3804a478Cc4e35 in directory...
Registering implementation of PLCRVoting at 0x879752521d969263Ed7e0F31287334BD1D605497 in directory...
Registering implementation of XyBond at 0x7C92e13d2A19Dd997F6E9E8A3926266D975e2a86 in directory...
Setting XyGovernance implementation 0x3a1637E066D5433747Aebd60355C5F8C6FFFec78...
Setting XyBlockProducer implementation 0x8D00E6c2dFa82Cd18c37A14964C88808d9E835e5...
Setting XyStakingConsensus implementation 0x142d25FBb26b0469725663eb0C3804a478Cc4e35...
Setting PLCRVoting implementation 0x879752521d969263Ed7e0F31287334BD1D605497...
Setting XyBond implementation 0x7C92e13d2A19Dd997F6E9E8A3926266D975e2a86...
Implementation set: 0x8D00E6c2dFa82Cd18c37A14964C88808d9E835e5
Implementation set: 0x7C92e13d2A19Dd997F6E9E8A3926266D975e2a86
Implementation set: 0x142d25FBb26b0469725663eb0C3804a478Cc4e35
Implementation set: 0x3a1637E066D5433747Aebd60355C5F8C6FFFec78
Implementation set: 0x879752521d969263Ed7e0F31287334BD1D605497
Publish to kovan successful
Updated zos.kovan.json

Mainnet:

npx zos session --network mainnet --from 0x6792B02f88b32C4FE8e31cfA41ae5aF44865f930 --expires 2500

npx zos push
Adding new version...
Deploying new ImplementationDirectory...
Deployed ImplementationDirectory at 0x2c392c68787291002b70222c7a829474EdC19536
Added version 0.2.1
0xa87838152519c7571A64893C65E3441347D31Bf2
Updated zos.mainnet.json

npx zos create XyBond --init initialize --args "0x55296f69f40Ea6d20E478533C15A6B08B654E758,0x0242514106114DEaA99Fd81574142c36Edb03B6D,14515200"

0x1a024A698EEBdB86ccf3fCaF2F589839bdc066AD

npx zos update XyStakingConsensus

npx zos publish

ownerSet('XyBondContract', 0x1a024A698EEBdB86ccf3fCaF2F589839bdc066AD)

Minimized ABI:
QmXM19CmChak3G3xq2e2XkahouVXNzBtkeGfrsTFBNgrXw v0.2.0/PLCRVoting.json
Qmc2kRGQQ5GumtFEvZ4EEdZU2nos45bERCbrwxKKYtokxY v0.2.0/XYO.json
QmbcfMGhtC1PCw6pkjHyv4zAqwvgvqE5xFgMUnj6cvqdEb v0.2.0/XyBlockProducer.json
QmWn3gFjcM5n5cRB2LFQx2QkndJ4EVkzJch5ickDqyGSdW v0.2.0/XyBond.json
Qmck9Z9TiHpwN5tptpmaA13eHNutBHJw7q2TqKnvDJ1chY v0.2.0/XyFaucet.json
QmQdhZBYc43D3SdTbZFyboUCFjyHi1mX5w2mC5MiCRW4hd v0.2.0/XyGovernance.json
QmWgsPNFSDcdeP3ngnkYFvaUCa28juksQBRKQixKTCgD61 v0.2.0/XyStakingConsensus.json
QmekPHL8DgJV5tiETVgzFhgwci2Q7GqHpRNWK768QQHVaY v0.2.0

Kovan:
0x1a2C4a6Ffd72848E7bD63d2177c29a0aC80c6386 XyStakingConsensus
0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084 XyBlockProducer
0xbF68070E5E84cae28f10161088edA1747A5963Ee XyGovernance
0x210241f42bC94Eb9da7b4E0A841f3b340B569291 PLCRVoting
0xAB0245d3971E5E01C4E5273350B5cB9CBe46aA8B XyBond
0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f XyFaucet

Mainnet:
0x0242514106114DEaA99Fd81574142c36Edb03B6D XyStakingConsensus
0xd3034c290E19959Fdc18E5597F375CA51BFB0c41 XyBlockProducer
0x01925d0fFE4a6a6162B51ba611e3D4780Fc2dF42 XyGovernance
0x72bCDb36d1545FEA06905a1bb4998424580AAee6 PLCRVoting
0x1a024A698EEBdB86ccf3fCaF2F589839bdc066AD XyBond
0x55296f69f40Ea6d20E478533C15A6B08B654E758 XYO

V1.1 deploy

Deployer for kovan: 0x316D5E10f4E4ad94499149c0131a44FC17EF995B

Kovan:

npx zos session --network kovan --from 0x316D5E10f4E4ad94499149c0131a44FC17EF995B --expires 5000

// Initialize the contracts for session
npx zos push

npx zos create XyBlockProducer --init initialize

0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084

npx zos create PLCRVoting --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f"

0x210241f42bC94Eb9da7b4E0A841f3b340B569291

npx zos create XyGovernance --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f,0x210241f42bC94Eb9da7b4E0A841f3b340B569291,[400000000000000000000000,172800,172800,172800,50,50,50,66,1000000000000000,1,11520,11520,0,20]"

0xbF68070E5E84cae28f10161088edA1747A5963Ee

npx zos create XyStakingConsensus --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f,0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084,0xbF68070E5E84cae28f10161088edA1747A5963Ee"

0x1a2C4a6Ffd72848E7bD63d2177c29a0aC80c6386

IPFS:
QmNPKPDj8UjNyy3ewLpyCUAcrAPEZoRtpAFwWtrZP3uEXX XyBlockProducer.json
QmZrbFNd21fY1Q6tJb1hLthaUyfHTEvVc5eJJdSdHQSTXi XyFaucet.json
QmcQhGekFrFGDPSy8epReXyBiYqLLgNd9rCcjMz341pF8L XyGovernance.json
QmTbUrie2GyVm6yJjQ3RHxinQtaqmLdtor1FpsYJD5kiA3 XyStakingConsensus.json
QmTGsMMiy2doKXWyEYci11btTpSQFnFJEowbFhzuVnjTcy kovanABI

Kovan:
0x1a2C4a6Ffd72848E7bD63d2177c29a0aC80c6386 XyStakingConsensus
0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084 XyBlockProducer.json
0xbF68070E5E84cae28f10161088edA1747A5963Ee XyGovernance.json
0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f XyFaucet.json

Minimized Kovan:
QmPSNLi99b91AR93AhS7P8TzgETp299R4KurSaFzqn2Dsa XyBlockProducer.json
QmZrbFNd21fY1Q6tJb1hLthaUyfHTEvVc5eJJdSdHQSTXi XyFaucet.json
QmYJhLPmq5GNTQDkWonHV4693YdoEJ1Bt9yz5yz15r6s2Z XyGovernance.json
Qmf6MHXSe4mKYTXbB5nEyUdKagpFo8ZWMSU96rNWqx293D XyStakingConsensus.json
QmYBBNitDFPJVkQkXpZbS16rqJhRU2Eg2teCzaT6jGGY7o minimizedABI

Mainnet:

npx zos session --network mainnet --from 0x6792B02f88b32C4FE8e31cfA41ae5aF44865f930 --expires 5000

npx zos push

npx zos create XyBlockProducer --init initialize

0xd3034c290E19959Fdc18E5597F375CA51BFB0c41

npx zos create PLCRVoting --init initialize --args "0x55296f69f40Ea6d20E478533C15A6B08B654E758"

0x72bCDb36d1545FEA06905a1bb4998424580AAee6

npx zos create XyGovernance --init initialize --args "0x55296f69f40Ea6d20E478533C15A6B08B654E758,0x72bCDb36d1545FEA06905a1bb4998424580AAee6,[400000000000000000000000,172800,172800,172800,50,50,50,66,1000000000000000,1,11520,11520,0,20]"

0x01925d0fFE4a6a6162B51ba611e3D4780Fc2dF42

npx zos create XyStakingConsensus --init initialize --args "0x55296f69f40Ea6d20E478533C15A6B08B654E758,0xd3034c290E19959Fdc18E5597F375CA51BFB0c41,0x01925d0fFE4a6a6162B51ba611e3D4780Fc2dF42"

0x0242514106114DEaA99Fd81574142c36Edb03B6D

Mainnet Minimized ABI:
QmWCMjwu78qSDPzdrHrBL4BzFLLWTgnRgV5HCbf5aQpmhC PLCRVoting.json
Qmc2kRGQQ5GumtFEvZ4EEdZU2nos45bERCbrwxKKYtokxY XYO.json
QmbZBv5LT1CxBG79inzcerG5DEtNwAYyLNUFQaULi5kYiH XyBlockProducer.json
QmcszeMWmdq2ZNLq6vsMtsFvcgVdTCjRSgcXaVgq37aphu XyGovernance.json
QmWkzxNb5yK82y9bDbkr8ucjKYe2QRdpDrP5DN3gTU3gKP XyStakingConsensus.json
QmfXE9DyRAf43fwtYig2RstHbJxxYJjvjAuGqwmEMZmCdj minimized

0x0242514106114DEaA99Fd81574142c36Edb03B6D XyStakingConsensus
0xd3034c290E19959Fdc18E5597F375CA51BFB0c41 XyBlockProducer.json
0x01925d0fFE4a6a6162B51ba611e3D4780Fc2dF42 XyGovernance.json
0x72bCDb36d1545FEA06905a1bb4998424580AAee6 PLCRVoting.json
0x55296f69f40Ea6d20E478533C15A6B08B654E758 XYO
