pragma solidity >=0.5.0 <0.6.0;

import "../node_modules/zos-lib/contracts/Initializable.sol";
import "./utils/SafeMath.sol";
import "./XyParameterizer.sol";

/**
    @dev Governance contract provides a democratic voting mechanism that will control  
    parameters and actions that govern the XYO Network
 */
contract XyGovernance is Initializable, XyParameterizer {
    using SafeMath for uint;

    address public resolverAddress;

    event NewActionAccepted(bytes32 indexed propId, ActionType actionType);
    event ActionResolved(bytes32 indexed propId, uint indexed stakee, ActionType actionType);

    struct GovernanceAction {
        bytes32 propId;         // proposal id must be unique
        uint stakePenaltyPct;   // amount that is transferred from the active stake to the penalty balance
        ActionType actionType;       // type of action              
        bool accepted;
    }

    enum  ActionType { EOL, UNSTAKE, ADD_BP, REMOVE_BP }

    mapping (uint => GovernanceAction[]) public resolutions;
    mapping (uint => GovernanceAction) public actions;

    // help ease transition into decentralized entity, 
    // and once governance has been established renounce ownership role 
    
    bool ownershipRenounced;

    function initialize (
        address _resolverAddress,
        address _xyERC20,
        address _plcr,
        uint[] memory _parameters
    ) initializer public {
        resolverAddress = _resolverAddress;
        init(_xyERC20, _plcr, _parameters);
    }
    
    /** 
        Any staker with over challenge cost can challenge a stakee.
        @param stakee the stakee to propose action on
        @param penaltyPct the penalty to enforce on stakers
     */
    function proposeNewAction(
        uint stakee, 
        uint penaltyPct, 
        ActionType action) public returns (bytes32) {
        require(actions[stakee].propId == 0, "Action in progress");
        bytes32 propId = proposeReparameterization("xyGovernanceAction", stakee);
        GovernanceAction memory a = GovernanceAction(
            propId,
            penaltyPct,
            action,                         // action type
            false
        );
        actions[stakee] = a;
        return propId;
    }

    function hasUnresolvedAction(uint stakee) public view returns (bool hasAction) {
        return actions[stakee].propId != 0;
    }

    function numResolutions(uint stakee) public view returns (uint) {
        return resolutions[stakee].length;
    }

      /**
    @dev sets the param with provided name to the provided value, checks for governance action
    @param _name the name of the param to be set
    @param _value the value to set the param to be set
    */
    function set(string memory _name, uint _value) internal {
        if (keccak256(abi.encodePacked(_name)) == keccak256("xyGovernanceAction")) {
            require(actions[_value].propId != 0, "Governance action must be proposed");
            actions[_value].accepted = true;
            emit NewActionAccepted(actions[_value].propId, actions[_value].actionType);
        } else {
            params[keccak256(abi.encodePacked(_name))] = _value;
        }
    }

    /** 
        Can only be called by resolver after resolution is complete 
    */
    function resolveAction(uint stakee) public {
        require (msg.sender == resolverAddress);
        GovernanceAction storage action = actions[stakee];
        require(action.accepted, "cannot resolve an unaccepted action");
        resolutions[stakee].push(action);
        delete actions[stakee];
        emit ActionResolved(action.propId, stakee, action.actionType);
    }

    /** 
        Can only be called by owner and will remove centralization 
        once governance is established
    */
    function renounceOwnership() public {
        require (msg.sender == address(get("pOwner")));
        ownershipRenounced = true;
    }

    /**
    @dev While this contract is owned any param can be written by owner
    @param _name the name of the param to be set
    @param _value the value to set the param to be set
    */
    function ownerSet(string memory _name, uint _value) public {
        require (ownershipRenounced == false, "Ownership was renounced");
        require (msg.sender == address(get("pOwner")), "only owner can call");
        set(_name, _value);
    }
}  