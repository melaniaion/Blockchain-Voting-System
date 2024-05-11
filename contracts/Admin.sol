// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";

contract Admin is Ownable {

    enum State {Eligible, Ineligible}
    struct Candidate {
        uint id;
        address candidateAddress;
        string name;
        uint totalVotes;
        State state;
    }
    
    uint public votingStart;
    uint public votingEnd;
    mapping(uint => Candidate) public idToCandidate;
    uint public nextCandidateId;
    Candidate[] public candidateList;

    modifier validRange(uint _startTime, uint _endTime){
        require(_startTime < _endTime, "Start time must be before end time.");
        _;
    }

    modifier validCandidateId(uint _id){
        require(_id > 0 && _id < nextCandidateId, "Candidate ID out of range");
        _;
    }

    event VotingPeriodUpdated(uint start, uint end);
    event CandidateAdded(uint candidateId, string name);
    event CandidateDeactivated(uint candidateId);

    constructor(address initialOwner) Ownable(initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        nextCandidateId = 1;
    }

    function updateVotingPeriod(uint _start, uint _end) external onlyOwner {
        votingStart = _start;
        votingEnd = _end;
        emit VotingPeriodUpdated(_start, _end);
    }
    
    function addCandidate(string memory _name, address _candidateAddress) external onlyOwner {
        uint candidateId = nextCandidateId++;
        Candidate memory newCandidate = Candidate(candidateId, _candidateAddress, _name, 0, State.Eligible);
        idToCandidate[candidateId] = newCandidate;
        candidateList.push(newCandidate);
        emit CandidateAdded(newCandidate.id, newCandidate.name);
    }

    function deactivateCandidate(uint _candidateId) external onlyOwner validCandidateId(_candidateId) {
        Candidate memory candidate = idToCandidate[_candidateId];
        candidate.state = State.Ineligible;
        candidateList[_candidateId - 1].state = State.Ineligible;
        emit CandidateDeactivated(_candidateId);
    }

    function increaseCandidateVotes(uint _id) external returns (uint){
        require(_id > 0 && _id < nextCandidateId, "Candidate ID out of range");
        idToCandidate[_id].totalVotes += 1;
        candidateList[_id - 1].totalVotes += 1;
        return idToCandidate[_id].totalVotes;
    }

    function getCandidateDetails(uint _candidateId) public view returns (
        uint id,
        address candidateAddress,
        string memory name,
        uint votesCount,
        State state
    ) {
        Candidate memory candidate = getCandidateById(_candidateId);
        return(candidate.id, candidate.candidateAddress, candidate.name, candidate.totalVotes, candidate.state);
    }

    function verifyCandidateEligibility (uint _candidateId) external view returns (bool){
        (,,,,State state) = getCandidateDetails(_candidateId);
        if(state == State.Eligible){
            return true;
        } 
        return false;
        
    }

    function getCandidateById(uint _id) private view validCandidateId(_id) returns (Candidate memory){
        return idToCandidate[_id];
    }

    function sortCandidates(Candidate[] memory candidates) internal pure returns (Candidate[] memory) {
        uint n = candidates.length;
        for (uint i = 0; i < n; i++) {
            for (uint j = i + 1; j < n; j++) {
                if (candidates[i].totalVotes < candidates[j].totalVotes) {
                    (candidates[i], candidates[j]) = (candidates[j], candidates[i]); // Swap elements
                }
            }
        }
        return candidates;
    }

    function findBestCandidate() external view returns (string memory name, address candidateAddress, uint finalVotes) {
        Candidate[] memory sortedCandidates = new Candidate[](candidateList.length);
        for (uint i = 0; i < candidateList.length; i++) {
            sortedCandidates[i] = candidateList[i];
        }

        sortedCandidates = sortCandidates(sortedCandidates);

        // Find the first eligible candidate
        for (uint i = 0; i < sortedCandidates.length; i++) {
            if (sortedCandidates[i].state == State.Eligible) {
                return (sortedCandidates[i].name, sortedCandidates[i].candidateAddress, sortedCandidates[i].totalVotes);
            }
        }

        revert("No eligible winner found.");
    }
}