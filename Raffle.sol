//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./Ownable.sol";
import "./IERC20.sol";
import "./TransferHelper.sol";

contract RidiRaff is Ownable {

    struct Raffle {
        address token; // token
        uint256 buyIn; // buy in in `token`
        uint256 totalNumberOfTickets; // total number of tickets available
        uint256 pot;
        address[] players; // list of players
        uint256 endTime; // time raffle expires
        bool isFinished;
    }

    mapping (uint256 => Raffle) public raffles;

    // Number of tickets a user owns per raffle
    mapping ( address => mapping ( uint256 => uint256 ) ) public userTicketsPerRaffle;

    // Raffle Nonce
    uint256 public raffleNonce;

    // Time Limit For Raffle
    uint256 public raffleTimeLimit = 30 days;

    // Amount Retained By Platform
    uint256 public platformFee = 100;

    // Amount That Is Burned
    uint256 public burnFee = 100;

    // Fee Denominator
    uint256 private constant FEE_DENOM = 1_000;

    modifier isValidRaffle(uint256 raffleId) {
        require(
            raffleId < raffleNonce,
            'Invalid ID'
        );
        require(
            raffles[raffleId].isFinished == false,
            'Raffle Is Finished'
        );
        _;
    }


    function createRaffle(
        address token, 
        uint256 buyIn,
        uint256 totalNumberOfTickets
    ) external {
        
        // create raffle
        raffles[raffleNonce].token = token;
        raffles[raffleNonce].buyIn = buyIn;
        raffles[raffleNonce].totalNumberOfTickets = totalNumberOfTickets;
        raffles[raffleNonce].endTime = block.timestamp + raffleTimeLimit;

        // increment raffle nonce
        unchecked {
            ++raffleNonce;
        }
    }



    function joinRaffle(
        uint256 raffleId,
        uint256 numTickets
    ) external payable isValidRaffle(raffleId) {
        require(
            raffleId < raffleNonce,
            'Invalid ID'
        );
        if (raffles[raffleId].token == address(0)) {
            require(
                msg.value >= raffles[raffleId].buyIn * numTickets,
                'Invalid Buy'
            );
            raffles[raffleId].pot += msg.value;
        } else {
            require(msg.value == 0, 'ERR: VALUE SENT');
            uint256 received = _transferIn(raffles[raffleId].token, raffles[raffleId].buyIn * numTickets);
            raffles[raffleId].pot += received;
        }

        for (uint i = 0; i < numTickets;) {
            raffles[raffleId].players.push(msg.sender);
            unchecked { ++i; }
        }

        unchecked {
            userTicketsPerRaffle[user][raffleId] += numTickets;
        }
    }

    function _resolveRaffle(uint256 raffleId, uint256 randomNumber) internal {

        address winner = raffles[raffleId].players[
            randomNumber % raffles[raffleId].players.length
        ];
        // ...
    }


    function _transferIn(address token, uint256 amount) internal returns (uint256) {
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            'Insufficient Allowance'
        );
        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'Insufficient Balance'
        );
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        TransferHelper.safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(
            balanceAfter > balanceBefore,
            'Zero Received'
        );
        return balanceAfter - balanceBefore;
    }

}