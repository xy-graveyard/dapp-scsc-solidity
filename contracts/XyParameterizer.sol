pragma solidity ^0.5.0;

import "./PLCR/PLCRVoting.sol";
import "./token/ERC20/SafeERC20.sol";
import "./utils/SafeMath.sol";

interface IXyVotingData {
    function totalVotingStake() external view returns (uint);
}

contract XyParameterizer {

    // ------
    // EVENTS
    // ------

    event _ReparameterizationProposal(string name, uint value, bytes32 propID, uint deposit, uint appEndDate, address indexed proposer);
    event _NewChallenge(bytes32 indexed propID, uint challengeID, uint commitEndDate, uint revealEndDate, address indexed challenger);
    event _ProposalAccepted(bytes32 indexed propID, string name, uint value);
    event _ProposalExpired(bytes32 indexed propID);
    event _ChallengeSucceeded(bytes32 indexed propID, uint indexed challengeID, uint rewardPool, uint totalTokens);
    event _ChallengeFailed(bytes32 indexed propID, uint indexed challengeID, uint rewardPool, uint totalTokens);
    event _RewardClaimed(uint indexed challengeID, uint reward, address indexed voter);


    // ------
    // DATA STRUCTURES
    // ------

    using SafeMath for uint;

    struct ParamProposal {
        uint appExpiry;
        uint challengeID;
        uint deposit;
        string name;
        address owner;
        uint processBy;
        uint value;
    }

    struct Challenge {
        uint rewardPool;        // (remaining) pool of tokens distributed amongst winning voters
        address challenger;     // owner of Challenge
        bool resolved;          // indication of if challenge is resolved
        uint stake;             // number of tokens at risk for either party during challenge
        uint winningTokens;     // (remaining) amount of tokens used for voting by the winning side
        mapping(address => bool) tokenClaims;
    }

    // ------
    // STATE
    // ------

    mapping(bytes32 => uint) public params;

    // maps challengeIDs to associated challenge data
    mapping(uint => Challenge) public challenges;

    // maps pollIDs to intended data change if poll passes
    mapping(bytes32 => ParamProposal) public proposals;

    // Global Variables
    address public token;
    PLCRVoting public voting;
    uint public stageBlockLen; // 7 days
    address public governorAddress;

    /**
    @dev Initializer        Can only be called once
    @param _token           The address where the ERC20 token contract is deployed
    @param _plcr            address of a PLCR voting contract for the provided token
    @notice _parameters     array of canonical parameters
    */
    function init(
        address _token,
        address _plcr,
        uint[] memory _parameters
    ) internal {
        stageBlockLen = 40320;
        token = _token;
        voting = PLCRVoting(_plcr);

        // minimum deposit to propose a reparameterization
        set("pMinDeposit", _parameters[0]);
        // period over which reparmeterization proposals wait to be processed
        set("pApplyStageSec", _parameters[1]);
        // length of commit period for voting in parameterizer
        set("pCommitStageSec", _parameters[2]);
        // length of reveal period for voting in parameterizer
        set("pRevealStageSec", _parameters[3]);
        // percentage of losing party's deposit distributed to winning party in parameterizer
        set("pDispensationPct", _parameters[4]);
        // majority for proposal success in parameterizer
        set("pVoteSuccessRate", _parameters[5]);
        // percentage stake present for challenge success
        set("pVoteQuorum", _parameters[6]);
        // percentage active stake to produce a block
        set("xyStakeSuccessPct", _parameters[7]);
        // minimum mining cost for request
        set("xyWeiMiningMin", _parameters[8]);
        // minimum bounty cost for request
        set("xyXYORequestBountyMin", _parameters[9]);
        // blocks to pass before cooldown stake
        set("xyStakeCooldown", _parameters[10]);
        // blocks to pass before cooldown unstake
        set("xyUnstakeCooldown", _parameters[11]);
        // enable voting on reparameterization
        set("xyProposalsEnabled", _parameters[12]);
        // Block producers get percent of XYO bounty based on their stake
        set("xyBlockProducerRewardPct", _parameters[13]); 
        // Temporary owner of the governance contract
        set("pOwner", uint(msg.sender)); 
    }

    function initializeGovernor(address _governorAddress) public {
        require(governorAddress == address(0), "already initialized");
        governorAddress = _governorAddress;
    }

    function transferGovernor(address newGov) public {
        require(governorAddress == msg.sender, "only current gov can transfer");
        governorAddress = newGov;
    }

    function _constrainParam(string memory _name, string memory _check, uint _value, uint _lte, uint _gt) private pure {
        if (keccak256(abi.encodePacked(_name)) == keccak256(abi.encodePacked(_check))) {
            if (_lte > 0) {
                require(_value <= _lte); 
            if (_gt > 0)
                require(_value > _gt);
            }
        }
    }

    

    // -----------------------
    // TOKEN HOLDER INTERFACE
    // -----------------------

    /**
    @notice propose a reparamaterization of the key _name's value to _value.
    @param _name the name of the proposed param to be set
    @param _value the proposed value to set the param to be set
    */
    function proposeReparameterization(string memory _name, uint _value) public returns (bytes32) {
        require(get("xyProposalsEnabled") != 0, "Proposals not yet enabled");

        _constrainParam("pDispensationPct", _name, _value, 100, 0);
        _constrainParam("xyStakeSuccessPct", _name, _value, 90, 10);
        _constrainParam("xyBlockProducerRewardPct", _name, _value, 50, 10);

        // Min of two days max 2 weeks (blocks)
        _constrainParam("xyStakeCooldown", _name, _value, 80640, 11520);
        _constrainParam("xyUnstakeCooldown", _name, _value, 80640, 11520);

        // Min of two days max 2 weeks (seconds)
        _constrainParam("pApplyStageSec", _name, _value, 1209600, 172800);
        _constrainParam("pCommitStageSec", _name, _value, 1209600, 172800);
        _constrainParam("pRevealStageSec", _name, _value, 1209600, 172800);

        uint deposit = get("pMinDeposit");
        bytes32 propID = keccak256(abi.encodePacked(_name, _value));
        require(!propExists(propID)); // Forbid duplicate proposals
        require(get(_name) != _value); // Forbid NOOP reparameterizations

        // attach name and value to pollID
        proposals[propID] = ParamProposal({
            appExpiry: now.add(get("pApplyStageSec")),
            challengeID: 0,
            deposit: deposit,
            name: _name,
            owner: msg.sender,
            processBy: now.add(get("pApplyStageSec"))
                .add(get("pCommitStageSec"))
                .add(get("pRevealStageSec"))
                .add(stageBlockLen),
            value: _value
        });

        if (deposit > 0) {
            SafeERC20.transferFrom(token, msg.sender, address(this), deposit); // escrow tokens (deposit amt)
        }

        emit _ReparameterizationProposal(_name, _value, propID, deposit, proposals[propID].appExpiry, msg.sender);
        return propID;
    }

    /**
    @notice challenge the provided proposal ID, and put tokens at stake to do so.
    @param _propID the proposal ID to challenge
    */
    function challengeReparameterization(bytes32 _propID) public returns (uint challengeID) {
        ParamProposal memory prop = proposals[_propID];
        uint deposit = prop.deposit;

        require(propExists(_propID) && prop.challengeID == 0);

        // start poll
        uint pollID = voting.startPoll(
            get("pVoteSuccessRate"),
            get("pCommitStageSec"),
            get("pRevealStageSec")
        );

        challenges[pollID] = Challenge({
            challenger: msg.sender,
            rewardPool: SafeMath.sub(100, get("pDispensationPct")).mul(deposit).div(100),
            stake: deposit,
            resolved: false,
            winningTokens: 0
        });

        proposals[_propID].challengeID = pollID; // update listing to store most recent challenge

        //take tokens from challenger
        SafeERC20.transferFrom(token, msg.sender, address(this), deposit);

        (uint commitEndDate, uint revealEndDate,,,) = voting.pollMap(pollID);

        emit _NewChallenge(_propID, pollID, commitEndDate, revealEndDate, msg.sender);
        return pollID;
    }

    /**
    @notice             for the provided proposal ID, set it, resolve its challenge, or delete it depending on whether it can be set, has a challenge which can be resolved, or if its "process by" date has passed
    @param _propID      the proposal ID to make a determination and state transition for
    */
    function processProposal(bytes32 _propID) public {
        ParamProposal storage prop = proposals[_propID];
        address propOwner = prop.owner;
        uint propDeposit = prop.deposit;
        
        // Before any token transfers, deleting the proposal will ensure that if reentrancy occurs the
        // prop.owner and prop.deposit will be 0, thereby preventing theft
        if (canBeSet(_propID)) {
            // There is no challenge against the proposal. The processBy date for the proposal has not
            // passed, but the proposal's appExpirty date has passed.
            set(prop.name, prop.value);
            emit _ProposalAccepted(_propID, prop.name, prop.value);
            delete proposals[_propID];
            SafeERC20.transfer(token, propOwner, propDeposit);
        } else if (challengeCanBeResolved(_propID)) {
            // There is a challenge against the proposal.
            resolveChallenge(_propID);
        } else if (now > prop.processBy) {
            // There is no challenge against the proposal, but the processBy date has passed.
            emit _ProposalExpired(_propID);
            delete proposals[_propID];
            SafeERC20.transfer(token, propOwner, propDeposit);
        } else {
            // There is no challenge against the proposal, and neither the appExpiry date nor the
            // processBy date has passed.
            revert();
        }

        assert(get("pDispensationPct") <= 100);

        // verify that future proposal appExpiry and processBy times will not overflow
        now.add(get("pApplyStageSec"))
            .add(get("pCommitStageSec"))
            .add(get("pRevealStageSec"))
            .add(stageBlockLen);

        delete proposals[_propID];
    }

    /**
    @notice                 Claim the tokens owed for the msg.sender in the provided challenge
    @param _challengeID     the challenge ID to claim tokens for
    */
    function claimReward(uint _challengeID) public {
        Challenge storage challenge = challenges[_challengeID];
        // ensure voter has not already claimed tokens and challenge results have been processed
        require(challenge.tokenClaims[msg.sender] == false);
        require(challenge.resolved == true);

        uint voterTokens = voting.getNumPassingTokens(msg.sender, _challengeID);
        uint reward = voterReward(msg.sender, _challengeID);

        // subtract voter's information to preserve the participation ratios of other voters
        // compared to the remaining pool of rewards
        challenge.winningTokens -= voterTokens;
        challenge.rewardPool -= reward;

        // ensures a voter cannot claim tokens again
        challenge.tokenClaims[msg.sender] = true;

        emit _RewardClaimed(_challengeID, reward, msg.sender);
        SafeERC20.transfer(token, msg.sender, reward);
    }

    /**
    @dev                    Called by a voter to claim their rewards for each completed vote.
                            Someone must call updateStatus() before this can be called.
    @param _challengeIDs    The PLCR pollIDs of the challenges rewards are being claimed for
    */
    function claimRewards(uint[] memory _challengeIDs) public {
        // loop through arrays, claiming each individual vote reward
        for (uint i = 0; i < _challengeIDs.length; i++) {
            claimReward(_challengeIDs[i]);
        }
    }

    // --------
    // GETTERS
    // --------

    /**
    @dev                Calculates the provided voter's token reward for the given poll.
    @param _voter       The address of the voter whose reward balance is to be returned
    @param _challengeID The ID of the challenge the voter's reward is being calculated for
    @return             The uint indicating the voter's reward
    */
    function voterReward(address _voter, uint _challengeID)
    public view returns (uint) {
        uint winningTokens = challenges[_challengeID].winningTokens;
        uint rewardPool = challenges[_challengeID].rewardPool;
        uint voterTokens = voting.getNumPassingTokens(_voter, _challengeID);
        return (voterTokens * rewardPool) / winningTokens;
    }

    /**
    @notice Determines whether a proposal passed its application stage without a challenge
    @param _propID The proposal ID for which to determine whether its application stage passed without a challenge
    */
    function canBeSet(bytes32 _propID) view public returns (bool) {
        ParamProposal memory prop = proposals[_propID];

        return (now > prop.appExpiry && now < prop.processBy && prop.challengeID == 0);
    }

    /**
    @notice Determines whether a proposal exists for the provided proposal ID
    @param _propID The proposal ID whose existance is to be determined
    */
    function propExists(bytes32 _propID) view public returns (bool) {
        return proposals[_propID].processBy > 0;
    }

    /**
    @notice Determines whether the provided proposal ID has a challenge which can be resolved
    @param _propID The proposal ID whose challenge to inspect
    */
    function challengeCanBeResolved(bytes32 _propID) view public returns (bool) {
        ParamProposal memory prop = proposals[_propID];
        Challenge memory challenge = challenges[prop.challengeID];

        return (prop.challengeID > 0 && challenge.resolved == false && voting.pollEnded(prop.challengeID));
    }

    /**
    @notice Determines the number of tokens to awarded to the winning party in a challenge
    @param _challengeID The challengeID to determine a reward for
    */
    function challengeWinnerReward(uint _challengeID) public view returns (uint) {
        if(voting.getTotalNumberOfTokensForWinningOption(_challengeID) == 0) {
            // Edge case, nobody voted, give all tokens to the challenger.
            return 2 * challenges[_challengeID].stake;
        }

        return (2 * challenges[_challengeID].stake) - challenges[_challengeID].rewardPool;
    }

    /**
    @notice gets the parameter keyed by the provided name value from the params mapping
    @param _name the key whose value is to be determined
    */
    function get(string memory _name) public view returns (uint value) {
        return params[keccak256(abi.encodePacked(_name))];
    }

    /**
    @dev                Getter for Challenge tokenClaims mappings
    @param _challengeID The challengeID to query
    @param _voter       The voter whose claim status to query for the provided challengeID
    */
    function tokenClaims(uint _challengeID, address _voter) public view returns (bool) {
        return challenges[_challengeID].tokenClaims[_voter];
    }

    function isPassed(uint _pollId) public view returns (bool) {
        // success pct fullfilled
        bool voteSuccess = voting.isPassed(_pollId);
        bool quorumMet = (100 * voting.getTotalVotes(_pollId)) > (get("pVoteQuorum") * IXyVotingData(governorAddress).totalVotingStake());

        // check also if meets poll quorum (true def of quorum)
        return voteSuccess && quorumMet;
    }
    // ----------------
    // PRIVATE FUNCTIONS
    // ----------------

    /**
    @dev resolves a challenge for the provided _propID. It must be checked in advance whether the _propID has a challenge on it
    @param _propID the proposal ID whose challenge is to be resolved.
    */
    function resolveChallenge(bytes32 _propID) private {
        ParamProposal memory prop = proposals[_propID];
        Challenge storage challenge = challenges[prop.challengeID];

        // winner gets back their full staked deposit, and dispensationPct*loser's stake
        uint reward = challengeWinnerReward(prop.challengeID);

        challenge.winningTokens = voting.getTotalNumberOfTokensForWinningOption(prop.challengeID);
        challenge.resolved = true;

        if (isPassed(prop.challengeID)) { // The challenge failed
            if(prop.processBy > now) {
                set(prop.name, prop.value);
            }
            emit _ChallengeFailed(_propID, prop.challengeID, challenge.rewardPool, challenge.winningTokens);
            SafeERC20.transfer(token, prop.owner, reward);
        }
        else { // The challenge succeeded or nobody voted
            emit _ChallengeSucceeded(_propID, prop.challengeID, challenge.rewardPool, challenge.winningTokens);
            SafeERC20.transfer(token, challenges[prop.challengeID].challenger, reward);
        }
    }

    /**
    @dev sets the param keted by the provided name to the provided value
    @param _name the name of the param to be set
    @param _value the value to set the param to be set
    */
    function set(string memory _name, uint _value) internal {
        params[keccak256(abi.encodePacked(_name))] = _value;
    }


}

