// SPDX-License-Identifier: GPL-3.0
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.8.20;

interface IAdmin {
    function verifyCandidateEligibility (uint _candidateId) external view returns (bool);
    function increaseCandidateVotes(uint _id) external returns (uint);
    function votingEnd() external view returns (uint);
    function votingStart() external view returns (uint);
    function findBestCandidate() external view returns (string memory name, address candidateAddress, uint finalVotes);
}

interface IPayment {
    function payToVote(address voter) external payable;
    function getTotalPaidVotes(address voter) external view returns (uint);
    function releaseFunds(address winner) external;
    function maxPaidVotes() external view returns (uint);
    function maxFreeVotes() external view returns (uint);
    function votingFee() external view returns (uint);
}

contract Voting is Ownable {
    IAdmin admin;
    IPayment payment;

    mapping(address => Voter) public voters;

    struct Voter {
        bool isRegistered;
        uint votes;
        uint[] candidatesId;
    }

    constructor(address initialOwner, address _admin, address _payment) Ownable(initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        admin = IAdmin(_admin);
        payment = IPayment(_payment);
    }

    event VoterRegistered(address voter);
    event VotedSuccessfully(address voter, uint candidateId);
    event WinnerDeclared(string winnerName, address winnerAddress, uint winnerVotes);

    error InvalidVote();

    modifier onlyDuringVotingPeriod() {
        require(block.timestamp >= admin.votingStart() && block.timestamp <= admin.votingEnd(), "Outside voting period!");
        _;
    }

    modifier validVoter(address voterAddress){
        require(voters[voterAddress].isRegistered, "Voter not registered!");
        _;
    }

    function registerVoter() public onlyDuringVotingPeriod() {
        require(!voters[msg.sender].isRegistered, "Voter already registered");
        voters[msg.sender].isRegistered = true;
        voters[msg.sender].votes = 0;
        emit VoterRegistered(msg.sender);
    }

    function vote(uint _candidateId) external onlyDuringVotingPeriod validVoter(msg.sender) payable {
        require(admin.verifyCandidateEligibility(_candidateId), "Candidate not eligible");
        if (findPaidVotesLeft() == 0){
            revert InvalidVote();
        }

        if(voters[msg.sender].votes < payment.maxFreeVotes()){
            addVotes(_candidateId, msg.sender);
        }
        else{
            payment.payToVote{value: msg.value}(msg.sender);
            addVotes(_candidateId, msg.sender);
        }
    }

    function addVotes(uint _candidateId, address _voterAddress) private {
        admin.increaseCandidateVotes(_candidateId);
        voters[_voterAddress].votes += 1;
        voters[_voterAddress].candidatesId.push(_candidateId);
        emit VotedSuccessfully(_voterAddress, _candidateId);
    }

    function findPaidVotesLeft() public view validVoter(msg.sender) returns (uint rest){
        uint totalPaidVotes = payment.getTotalPaidVotes(msg.sender);
        uint votesLeft = payment.maxPaidVotes() - totalPaidVotes;
        return votesLeft;
    }

    function findWinner() external onlyOwner returns (string memory name, address candidateAddress, uint totalVotes) {
        require(admin.votingEnd() < block.timestamp, "Winner is declared after voting period ended!");
        (string memory winnerName, address winnerAddress, uint winnerVotes) = admin.findBestCandidate();
        emit WinnerDeclared(winnerName, winnerAddress, winnerVotes);
        return(winnerName, winnerAddress, winnerVotes);
    }

    function checkFeeForPaidVotes() external view returns (uint fee){
        return payment.votingFee();
    }
    function checkVotesPerVoter() public view returns (uint votedTimes){
        return (voters[msg.sender].votes);
    }
}