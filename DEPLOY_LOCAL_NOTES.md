npx zos session --network development --from 0x3D01dDdB4eBD0b521f0E4022DCbeF3cb9bc20FF2 --expires 2500

npx zos add XyStakingConsensus XyBlockProducer XyGovernance XyFaucet XyBond PLCRVoting

npx zos push --verbose

npx zos create XyBlockProducer --init initialize

npx zos create PLCRVoting --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f"

npx zos create XyGovernance --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f,0x210241f42bC94Eb9da7b4E0A841f3b340B569291,[400000000000000000000000,172800,172800,172800,50,50,50,66,1000000000000000,1,11520,11520,0,20]"

npx zos create XyStakingConsensus --init initialize --args "0x9071a6fc3c23eb6f4a8f7a2bc2309a7b368f272f,0xb9452ee24cf08eaedf64F3B81f8727f5bd0Ea084,0xbF68070E5E84cae28f10161088edA1747A5963Ee"