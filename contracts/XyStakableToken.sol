pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/zos-lib/contracts/Initializable.sol";
import "./token/ERC721/ERC721Enumerable.sol";
import "./access/GovernorRole.sol";
/* 
    Contract used to track ownership of stakable addresses in XYO network 
    These token ids are the payment ids that are passed up the XYO origin chains
    Stakers on these tokens may make reward withdrawels,
*/

contract XyStakableToken is ERC721Enumerable, Initializable, GovernorRole {
    address public governor;

    // Keep a list of block producers to publicly show who the BPs are in the system
    uint[] public blockProducers;
    // Add mapping of indexes so that we can find a BP by their blockProducers[index[id]]
    mapping(uint => uint) public blockProducerIndexes;

    function initialize () 
        initializer public
    {
    }

    /**
        Allow a contract governor to add and remove block producer
        @param stakee which stakable token
        @param enable enable == add 
    */
    function enableBlockProducer
    (
        uint stakee, 
        bool enable
    ) 
    onlyGovernor
    public 
    {
        require (_exists(stakee) == true, "token must exist");

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
    function mint(address beneficiary) 
        public 
    {
        require(msg.sender == beneficiary || isGovernor(msg.sender), "Only beneficiary or governor can create token");
        uint tokenId = uint(keccak256(abi.encodePacked(beneficiary)));
        require(_exists(tokenId) == false, "This user already created a stakable Token");
        _mint(beneficiary, tokenId);
    }

    /**
        Only govenor (the scsc) can burn a BP (because stake needs to be removed)
        @param stakee the stakee to burn 
    */
    function burn(uint stakee) public {
        bool isGovenor = isGovernor(msg.sender);
        bool isNonBPOwner = !isBlockProducer(stakee) && ownerOf(stakee) == msg.sender;
        require(isGovenor || isNonBPOwner, "Only owner or govenor can burn account");
        _removeBlockProducer(stakee);
        _burn(ownerOf(stakee), stakee);
    }

    /**
        Expose internal exists function to be used
    */
    function exists(uint stakee) public view returns (bool) {
        return _exists(stakee);
    }

    function isBlockProducer(uint stakee) public view returns (bool) {
        uint index = blockProducerIndexes[stakee];
        if (index < numBlockProducers()) {
            return (stakee == blockProducers[index]);
        }
        return false;
    }

    function numBlockProducers() public view returns (uint) {
        return blockProducers.length;
    }
}