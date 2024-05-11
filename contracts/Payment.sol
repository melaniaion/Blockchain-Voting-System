// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/access/Ownable.sol";
contract Payment is Ownable {

    mapping(address => uint) public votesPaid;  // Tracks the number of paid votes per voter
    uint public votingFee;
    uint public maxPaidVotes;
    uint public maxFreeVotes;

    event MaxPaidVotesUpdated(uint _updatedNumber);
    event PaymentReceived(address indexed payer, uint amount);
    event FeeUpdated(uint _votingFee);
    event WinnerPaid(uint totalCollectedFees);

    constructor(address initialOwner, uint _initialFee, uint _maxFreeVotes) Ownable(initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        votingFee = _initialFee;   
        maxFreeVotes = _maxFreeVotes;
    }

    function payToVote(address voter) external payable {
        uint votes = votesPaid[voter];
        uint requiredFee = votes * votingFee;
        require(msg.value >= requiredFee, "Not enough ETH sent");

        votesPaid[voter]++;
        emit PaymentReceived(voter, msg.value);
    }

    // Allow the owner to update the fee 
    function updateFees(uint _updatedFee) external onlyOwner() {
        votingFee = _updatedFee;
        emit FeeUpdated(votingFee);
    }

    function updateMaxPaidVotes(uint _maxPaidVotes) external onlyOwner{
        maxPaidVotes = _maxPaidVotes;
        emit MaxPaidVotesUpdated(maxPaidVotes);

    }

    // Function to check the total votes paid by a voter
    function getTotalPaidVotes(address voter) external view returns (uint) {
        return votesPaid[voter];
    }

    // Pay the winner
    function releaseFunds(address winner) external {
        uint totalCollectedFees = address(this).balance;  
        require(totalCollectedFees > 0, "No funds to distribute");
        payable(winner).transfer(totalCollectedFees);
        emit WinnerPaid(totalCollectedFees);
    }
}