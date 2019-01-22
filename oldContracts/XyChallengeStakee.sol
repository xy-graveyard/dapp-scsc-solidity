import "./token/ERC721/ERC721.sol";
import "./ownership/Ownable.sol";
import "./SafeMath.sol";


/**
    @dev A simple challenge and vote smart contract on stakee based on staker's stake

 */
contract XyChallengeStakee is Ownable {
    using SafeMath for uint;

    // ERC20 contract for stake denomination
    XyERC20Token xyoToken;

    // 721 contract that we reference for all things staked
    ERC721 stakableToken;

    XyParameterizer params;

    // Owner can edit the following params (until ownership renounced)
    uint8[] challengerRewardPercentArray = [50, 100];
    uint8[] challengeSuccessPercentArray = [51, 100];
    uint8[] challengePenaltyPercentArray = [1, 10];
    uint challengePeriodLength = 17280; // 3*24*60*4 aka 3 days
    uint public challengeCost = 100000 ether; // 100k XYO stake required to challenge
    uint public maxVoterReimbursement = 1000 ether; // 1000 XYO covers max mining fee from remaining penalty
    uint public challengeFailurePool = 0;

    // Total/Active amounts staked by stakee and staker 
    struct StakeAmounts {
        uint totalStake;
        uint activeStake;
        uint totalUnstake;
    }
    mapping (uint => StakeAmounts) public stakeeStake;
    mapping (address => StakeAmounts) public stakerStake;

    enum ChallengeState {open, active, success, fail}
    enum VoterState {absent, voted, withdrew}
    struct Challenge {
        uint created;                               // block created on
        uint totalVotes;                            // total votes so far
        uint penalty;                               // penalty for being challenged from one's active stake
        uint stake;                                 // number of tokens at risk by challenger
        address challenger;                         // owner of Challenge
        ChallengeState state;                       // state of the challenge
        mapping(address => VoterState) voterState;  // track states of voters
    }
    mapping (uint => Challenge) public stakeeChallenges;

    constructor(
        ERC721 _stakableToken,
        XyERC20Token _token,
        XyParameterizer parameterizer
        
    ) public {
        stakableToken = _stakableToken;
        xyoToken = _token;
        params = Parameterizer(parameterizer);
    }

    function updateCacheOnChallenge(uint stakee, uint penalty) internal returns (uint penalty) {
        totalActiveStake = totalActiveStake.sub(penalty);
        if (stakeeStake[stakee].activeStake > penalty) {
            stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.sub(penalty);
        } else {
            uint activeStake = stakeeStake[stakee].activeStake;
            stakeeStake[stakee].activeStake = 0;
            stakeeStake[stakee].totalUnstake = stakeeStake[stakee].totalUnstake.sub(activeStake);
        }
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.sub(penalty);
    }

    /**
        On Failure to adopt challenge, challenger is penalized the stake of the challenge
        The stake is divided 3/4 to the mining pool and 1/4 to the stakee for the inconvenience
        The stakee also is refunded the penalty.
    */
    function updateCacheOnFailure(uint stakee, uint penalty, uint stake) internal {
        uint poolRake = stake.mul(3).div(4);
        challengeFailurePool.add(poolRake);
        uint stakeeRefund = stake.sub(poolRake);
        totalActiveStake = totalActiveStake.add(penalty).add(stakeeRefund);
        stakeeStake[stakee].activeStake = stakeeStake[stakee].activeStake.add(penalty).add(stakeeRefund);
        stakerStake[msg.sender].activeStake = stakerStake[msg.sender].activeStake.add(penalty).add(stakeeRefund);
    }

    /** 
        Any staker with over challenge cost can challenge a stakee.

     */
    function initiateChallenge(uint stakee) {
        require(stakeeChallenges[stakee].state != active, "Stakee already has active challenge");
        require(stakerStake[msg.sender].activeStake + stakerStake[msg.sender].totalUnstake > challengeCost, "challenger must have min stake");
        uint penalty = stakeeStake[stakee].activeStake.mul(penaltyPercentArray[0]).div(penaltyPercentArray[1]);
        // require the stakee has enough stake to make challenge worthwhile
        updateCacheOnChallenge(stakee, penalty);
        require(penalty > challengeCost, "penalty must be greater than possible challenge");

        Challenge newChallenge = Challenge(
            block.number,
            stakerStake[msg.sender].activeStake,        // votes
            penalty,                                    // penalty on stakee
            challengeCost,                              // staked
            msg.sender,                                 // challenger
            1                                           // state is set to 'active'
        );
        stakeeChallenges[stakee] == newChallenge;
        xyoToken.transferFrom(msg.sender, address(this), challengeCost);
    }

    /**
        Anyone with stake may vote on a challenge if they agree.  
        If a vote wins you can redeem a small percentage of the penalty to 
        

    */
    function vote(uint stakee) {
        Challenge storage c = stakeeChallenges[stakee];
        require(c.state == active, "Challenge not active");
        require(c.voterState[msg.sender] == absent, "Vote already cast by staker");

        c.totalVotes = c.totalVotes.add(stakerStake[msg.sender].activeStake);
        c.voterState[msg.sender] = voted;

        uint votesNeeded = totalActiveStake.mul(challengeSuccessPercentArray[0]).div(challengeSuccessPercentArray[1]);
        if (c.totalVotes >= votesNeeded) {
            c.state = success;
        }
    }

    function challengeFailed(uint stakee) {
        Challenge storage c = stakeeChallenges[stakee];
        require(msg.sender == c.challenger 
        || msg.sender == address(stakee) 
        || msg.sender == owner, "can be marked as failure by challenger, stakee, or owner");
        require(c.state == active, "Must be active to be failed");
        require(c.created + challengePeriod < block.number, "Challenge Period must be expired with not enough votes");
        c.state = fail;
        // refund penalty plus some of the stake to stakee, the rest goes to mining pool
        updateCacheOnFailure(stakee, c.penalty, c.stake);
    }

    /**
        @dev Participants of a challenge may redeem a reward for successful challenges
        
    */
    function withdrawWinnings(uint stakee) {
        Challenge storage c = stakeeChallenges[stakee];
        require(c.state == success, "Challenge state not success");
        require(c.voterState[msg.sender] == voted, "Voter state not voted");
        c.voterState[msg.sender] = withdrew;

        if (msg.sender == c.challenger) {
            uint challengerReward = c.penalty.mul(challengerRewardPercentArray[0]).div(challengerRewardPercentArray[1]);
            xyoToken.transferFrom(address(this), msg.sender, challengerReward);
        } else {
            xyoToken.transferFrom(address(this), msg.sender, participantMiningReimbursement);
        }
    }
}  
