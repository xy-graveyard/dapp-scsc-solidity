pragma solidity >=0.5.0 <0.6.0;

import "./SafeMath.sol";
import "./XyParameterizer.sol";


/**
    @dev A simple challenge and vote smart contract on stakee based on staker's stake

 */
contract XyGovernance is XyParameterizer {
    using SafeMath for uint;

    address public resolverAddress;

    event NewActionAccepted(uint indexed stakee, uint8 actionType, string reason);
    event ActionResolved(uint indexed stakee, uint8 actionType, string reason);

    uint8 UnstakeAction = 1;
    struct GovernanceAction {
        bytes32 propId;                                // proposal id
        uint stakePenaltyPct;
        string reason;
        uint8 actionType;                          // penalty for being challenged from one's active stake
        bool accepted;
    }

    mapping (uint => GovernanceAction[]) public resolutions;
    mapping (uint => GovernanceAction) public actions;
    mapping (uint => bool) public stakeeDisabled;

    constructor(
        address _resolverAddress
    ) XyParameterizer() 
    public {
        resolverAddress = _resolverAddress;
    }

    /** 
        Any staker with over challenge cost can challenge a stakee.

     */
    function proposeNewAction(
        uint stakee, 
        uint penaltyPct, 
        uint8 action,
        string memory reason) public {
        require(actions[stakee].propId == 0, "Action in progress");
        bytes32 propId = proposeReparameterization("xyGovernanceAction", stakee);
        GovernanceAction memory a = GovernanceAction(
            propId,
            penaltyPct,
            reason,                         // optional reason for records
            action,                         // action type
            false
        );
        actions[stakee] = a;
    }

    function hasUnresolvedAction(uint stakee) public view returns (bool hasAction) {
        return actions[stakee].propId != 0;
    }

    function resolveAction(uint stakee) public {
        require (msg.sender == resolverAddress);
        GovernanceAction storage action = actions[stakee];
        require(action.accepted, "cannot resolve an unaccepted action");
        resolutions[stakee].push(action);
        delete actions[stakee];
        emit ActionResolved(stakee, action.actionType, action.reason);
    }

      /**
    @dev sets the param with provided name to the provided value, checks for governance action
    @param _name the name of the param to be set
    @param _value the value to set the param to be set
    */
    function set(string memory _name, uint _value) internal {
        if (keccak256(abi.encodePacked(_name)) == keccak256("xyGovernanceAction")) {
            actions[_value].accepted = true;
            emit NewActionAccepted(_value, actions[_value].actionType, actions[_value].reason);
        } else {
            params[keccak256(abi.encodePacked(_name))] = _value;
        }
    }

}  