pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/zos-lib/contracts/Initializable.sol";
import "./access/GovernorRole.sol";

/* 
    Contract used to track stakable addresses in XYO network 
    These token ids are the payment ids that are passed up the XYO origin chains
    Stakers on these tokens may make reward withdrawels,
*/
contract XyBlockProducer is Initializable, GovernorRole {

    address public governor;

    // Keep a list of block producers to publicly show who the BPs are in the system
    address[] public blockProducers;

    // Add mapping of indexes so that we can find a BP by their blockProducers[index[id]]
    mapping(address => uint) public blockProducerIndexes;

    function initialize () 
        initializer public
    {
    }

    /** 
        Mints a stakable address with the account hash as the token id
        Emits transfer event to sender
        msg.sender - new account creator
    */
    function create(address blockProducer) 
        onlyGovernor 
        public
    {
        require(exists(blockProducer) == false, "This BP exists");
        blockProducerIndexes[blockProducer] = blockProducers.length;
        blockProducers.push(blockProducer);
    }

    /**
        Only govenor (the scsc) can burn a BP (because stake needs to be removed)
        @param bp the stakee to burn 
    */
    function remove(address bp)
        onlyGovernor 
        public 
    {
        uint index = blockProducerIndexes[bp];
        uint lastBPIndex = blockProducers.length - 1;
        address lastBP = blockProducers[lastBPIndex];

        blockProducers[lastBPIndex] = address(0);
        blockProducers.length--;
        delete blockProducerIndexes[bp];
        
        blockProducers[index] = lastBP;
        blockProducerIndexes[lastBP] = index;
    }

    /**
        Expose internal exists function to be used
    */
    function exists(address bp) public view returns (bool) {
        uint index = blockProducerIndexes[bp];
        if (index < numBlockProducers() && bp != (address(0))) {
            return (bp == blockProducers[index]);
        }
        return false;
    }

    function numBlockProducers() public view returns (uint) {
        return blockProducers.length;
    }
}