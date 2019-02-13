pragma solidity >=0.5.0 <0.6.0;

import "./token/ERC721/ERC721Enumerable.sol";

/* 
    Contract used to track ownership of stakable addresses in XYO network 
    These token ids are the payment ids that are passed up the XYO origin chains
    Stakers on these tokens may make reward withdrawels,
*/
contract XyStakableToken is ERC721Enumerable {
    address public governor;

    uint[] public blockProducers;
    mapping(uint => uint) public blockProducerIndexes;

    constructor () 
        public
    {
        governor = msg.sender;
    }

    function transferGovernor
    (
        address newGovenor
    )
    public 
    {
        require(msg.sender == governor, "Only current govenor can set");
        governor = newGovenor;
    }

    function enableBlockProducer
    (
        uint stakee, 
        bool enable
    ) 
    public 
    {
        require(msg.sender == governor, "Only current govenor can enable");
        if (enable) {
            require (blockProducerIndexes[stakee] == 0, "Producer already enabled");
            blockProducerIndexes[stakee] = blockProducers.length;
            blockProducers.push(stakee);
        } else {
            _removeBlockProducer(stakee);
        }
    }

    function _removeBlockProducer(uint stakee) private {
        if (isBlockProducer(stakee)) {
            uint index = blockProducerIndexes[stakee];
            uint lastBPIndex = blockProducers.length - 1;
            uint lastBP = blockProducers[lastBPIndex];

            blockProducers[lastBPIndex] = 0;
            blockProducers.length--;
            delete blockProducerIndexes[stakee];
            
            blockProducers[index] = lastBP;
            blockProducerIndexes[lastBP] = index;
        }
    }

    /** 
        Mints a stakable address with the account hash as the token id
        Emits transfer event to sender
        msg.sender - new account creator
    */
    function mint() 
        public 
    {
        uint tokenId = uint(keccak256(abi.encodePacked(msg.sender)));
        _mint(msg.sender, tokenId);
    }

    /**
        Only govenor (the scsc) can burn a token
        if blockProducer, delete from blockProducer listing
        @param stakee the stakee to burn 
    */
    function burn(uint stakee) public {
        require(msg.sender == governor || msg.sender == ownerOf(stakee), "Only owner or govenor can burn account");
        _removeBlockProducer(stakee);
        _burn(ownerOf(stakee), stakee);
    }

    function isBlockProducer(uint stakee) public view returns (bool) {
        return stakee == blockProducers[blockProducerIndexes[stakee]];
    }

    function numBlockProducers() public view returns (uint) {
        return blockProducers.length;
    }
}