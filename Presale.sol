//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

contract Presale is Ownable {

    // Raise Token
    IERC20 public immutable raiseToken;

    // Receiver Of Donation
    address public presaleReceiver;

    // Address => User
    mapping ( address => uint256 ) public donors;
    mapping ( address => uint256 ) public donorsETH;

    // List Of All Donors
    address[] private _allDonors;

    // Total Amount Donated
    uint256 private _totalDonated;
    uint256 public totalDonatedETH;
    
    // maximum contribution
    uint256 public min_contribution;
    uint256 public min_contribution_eth = 5 ether;

    // sale has ended
    bool public hasStarted;

    // AffiliateID To Affiliate Receiver Address
    mapping ( uint8 => address ) public affiliateReceiver;

    // Address0 and Address1
    address private immutable addr0;
    address private immutable addr1;
    uint256 private constant addr0Cut = 20;
    uint256 private constant addr1Cut = 35;

    // Donation Event, Trackers Donor And Amount Donated
    event Donated(address donor, uint256 amountDonated, uint256 totalInSale);
    event DonatedETH(address donor, uint256 amountDonated, uint256 totalInSale);

    constructor(
        address presaleReceiver_,
        address raiseToken_,
        uint256 min_contribution_,
        address addr0_,
        address addr1_
    ) {
        presaleReceiver = presaleReceiver_;
        raiseToken = IERC20(raiseToken_);
        min_contribution = min_contribution_;
        hasStarted = true;
        addr0 = addr0_;
        addr1 = addr1_;
    }

    function startSale() external onlyOwner {
        hasStarted = true;
    }

    function endSale() external onlyOwner {
        hasStarted = false;
    }

    function withdraw(IERC20 token_) external onlyOwner {
        token_.transfer(presaleReceiver, token_.balanceOf(address(this)));
    }

    function setPresaleReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), 'Address 0');
        presaleReceiver = newReceiver;
    }

    function setMinContributions(uint min) external onlyOwner {
        min_contribution = min;
    }

    function setMinContributionETH(uint min) external onlyOwner {
        min_contribution_eth = min;
    }

    function setAffiliateReceiver(uint8 affiliateID, address destination) external onlyOwner {
        affiliateReceiver[affiliateID] = destination;
    }

    function donate(uint8 affiliateID, uint256 amount) external {
        _transferIn(amount, affiliateID);
        _process(msg.sender, amount);
    }

    function donateETH() external payable {
        require(
            msg.value >= min_contribution_eth,
            'Min Contribution'
        );
        _handleETH();
        _processETH(msg.sender, msg.value);
    }

    function donated(address user) external view returns(uint256) {
        return donors[user];
    }

    function allDonors() external view returns (address[] memory) {
        return _allDonors;
    }

    function allDonorsAndDonationAmounts() external view returns (address[] memory, uint256[] memory, uint256[] memory) {
        uint len = _allDonors.length;
        uint256[] memory amounts = new uint256[](len);
        uint256[] memory ethAmounts = new uint256[](len);
        for (uint i = 0; i < len;) {
            amounts[i] = donors[_allDonors[i]];
            ethAmounts[i] = donorsETH[_allDonors[i]];
            unchecked { ++i; }
        }
        return (_allDonors, amounts, ethAmounts);
    }

    function donorAtIndex(uint256 index) external view returns (address) {
        return _allDonors[index];
    }

    function numberOfDonors() external view returns (uint256) {
        return _allDonors.length;
    }

    function totalDonated() public view returns (uint256) {
        return _totalDonated;
    }

    function totalDonatedBoth() external view returns (uint256, uint256) {
        return ( _totalDonated, totalDonatedETH );
    }

    function _process(address user, uint amount) internal {
        require(
            amount > 0,
            'Zero Amount'
        );
        require(
            hasStarted,
            'Sale Has Not Started'
        );

        // add to donor list if first donation
        if (donors[user] == 0) {
            _allDonors.push(user);
        }

        // increment amounts donated
        unchecked {
            donors[user] += amount;
            _totalDonated += amount;
        }

        require(
            donors[user] >= min_contribution,
            'Contribution too low'
        );
        emit Donated(user, amount, _totalDonated);
    }

    function _processETH(address user, uint amount) internal {
        require(
            hasStarted,
            'Sale Has Not Started'
        );

        // add to donor list if first donation
        if (donors[user] == 0 || donorsETH[user] == 0) {
            _allDonors.push(user);
        }

        // increment amounts donated
        unchecked {
            donorsETH[user] += amount;
            totalDonatedETH += amount;
        }
        emit DonatedETH(user, amount, totalDonatedETH);
    }

    function _handleETH() internal {

        // split amounts
        uint256 addr0Split = ( address(this).balance * addr0Cut ) / 100;
        uint256 addr1Split = ( address(this).balance * addr1Cut ) / 100;
        uint256 remaining  = address(this).balance - ( addr0Split + addr1Split );

        // send amounts
        TransferHelper.safeTransferETH(addr0, addr0Split);
        TransferHelper.safeTransferETH(addr1, addr1Split);
        TransferHelper.safeTransferETH(presaleReceiver, remaining);
    }

    function _transferIn(uint amount, uint8 affiliateID) internal {
        require(
            raiseToken.allowance(msg.sender, address(this)) >= amount,
            'Insufficient Allowance'
        );
        require(
            raiseToken.balanceOf(msg.sender) >= amount,
            'Insufficient Balance'
        );

        // section off addr0 and addr1 cut
        uint256 addr0Split = ( amount * addr0Cut ) / 100;
        uint256 addr1Split = ( amount * addr1Cut ) / 100;

        // send to addr0 and addr1
        TransferHelper.safeTransferFrom(address(raiseToken), msg.sender, addr0, addr0Split);
        TransferHelper.safeTransferFrom(address(raiseToken), msg.sender, addr1, addr1Split);

        // to affiliates
        uint affiliateAmount = 0;
        if (affiliateReceiver[affiliateID] != address(0)) {
            affiliateAmount = amount / 20;
            TransferHelper.safeTransferFrom(address(raiseToken), msg.sender, affiliateReceiver[affiliateID], affiliateAmount);
        }

        // left over amount for receiver
        uint256 remainder = amount - ( affiliateAmount + addr0Split + addr1Split );

        // transfer to presale receiver
        require(
            raiseToken.transferFrom(msg.sender, presaleReceiver, remainder),
            'Failure TransferFrom2'
        );
    }
}