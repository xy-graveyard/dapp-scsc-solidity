pragma solidity >=0.5.0 <0.6.0;

import "../utils/Initializable.sol";
import "../access/GovernorRole.sol";

/* 
    Contract used to track stakable addresses in XYO network 
    These token ids are the payment ids that are passed up the XYO origin chains
    Stakers on these tokens may make reward withdrawels,
*/
contract XyBlockProducer is Initializable, GovernorRole {
    using SafeMath for uint;

    event BlockProducerCreated(
        address bp,
        address creator
    );

    event BlockProducerRemoved(
        address bp,
        address creator
    );

    // Keep a list of block producers to publicly show who the BPs are in the system
    address[] public blockProducers;

    // Add mapping of indexes so that we can find a BP by their blockProducers[index[id]]
    mapping(address => uint) public blockProducerIndexes;

    function initialize () 
        initializer public
    {
        super.init();
    }

    /** 
        Mints a stakable address with the account hash as the token id
        Emits transfer event to sender
        msg.sender - new account creator
    */
    function create(address bp) 
        onlyGovernor 
        public
    {
        require(exists(bp) == false, "This BP exists");
        blockProducerIndexes[bp] = blockProducers.length;
        blockProducers.push(bp);
        emit BlockProducerCreated(bp, msg.sender);
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
        emit BlockProducerRemoved(bp, msg.sender);
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