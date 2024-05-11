// SPDX-License-Identifier: GPL-3.0
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
}

contract Voting {
    IAdmin admin;
    IPayment payment;

    mapping(address => Voter) public voters;

    struct Voter {
        bool isRegistered;
        uint votes;
        uint[] candidatesId;
    }

    constructor(address _admin, address _payment) {
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

    function vote(uint _candidateId) external onlyDuringVotingPeriod validVoter(msg.sender) {
        Voter memory voter = voters[msg.sender];
        require(admin.verifyCandidateEligibility(_candidateId), "Candidate not eligible");
        if(voter.votes < payment.maxFreeVotes() && payment.getTotalPaidVotes(msg.sender) < payment.maxPaidVotes()){
            payment.payToVote(msg.sender);
        }

        admin.increaseCandidateVotes(_candidateId);
        voters[msg.sender].votes++;
        emit VotedSuccessfully(msg.sender, _candidateId);
    }

    function findPaidVotesLeft(address voterAddress) external view validVoter(msg.sender) returns (uint rest){
        uint totalPaidVotes = payment.getTotalPaidVotes(voterAddress);
        uint votesLeft = payment.maxPaidVotes() - totalPaidVotes;
        return votesLeft;

    }
    function findWinner() external onlyDuringVotingPeriod(){
        (string memory winnerName, address winnerAddress, uint winnerVotes) = admin.findBestCandidate();
        emit WinnerDeclared(winnerName, winnerAddress, winnerVotes);
        payment.releaseFunds(winnerAddress);
    }
}