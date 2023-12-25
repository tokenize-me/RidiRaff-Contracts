//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";
import "./Ownable.sol";
import "./TransferHelper.sol";

contract FeeReceiver is Ownable {

    // list of all recipients
    address[] public recipients;

    // maps address to allocation of points
    mapping ( address => uint256 ) public allocation;

    // total points allocated
    uint256 public totalAllocation;

    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        TransferHelper.safeTransfer(token, to, amount);
    }

    function withdrawETH(address to, uint256 amount) external onlyOwner {
        _sendETH(to, amount);
    }

    function addRecipient(address newRecipient, uint256 newAllocation) external onlyOwner {
        require(
            allocation[newRecipient] == 0,
            'Already Added'
        );

        // add to list
        recipients.push(newRecipient);

        // set allocation and increase total allocation
        allocation[newRecipient] = newAllocation;
        unchecked {
            totalAllocation += newAllocation;
        }
    }

    function removeRecipient(address recipient) external onlyOwner {

        // ensure recipient is in the system
        uint256 allocation_ = allocation[recipient];
        require(
            allocation_ > 0,
            'User Not Present'
        );

        // delete allocation, subtract from total allocation
        delete allocation[recipient];
        unchecked {
            totalAllocation -= allocation_;
        }

        // remove address from array
        uint index = recipients.length;
        for (uint i = 0; i < recipients.length;) {
            if (recipients[i] == recipient) {
                index = i;
                break;
            }
            unchecked { ++i; }
        }
        require(
            index < recipients.length,
            'Recipient Not Found'
        );

        // swap positions with last element then pop last element off
        recipients[index] = recipients[recipients.length - 1];
        recipients.pop();
    }

    function setAllocation(address recipient, uint256 newAllocation) external onlyOwner {

        // ensure recipient is in the system
        uint256 allocation_ = allocation[recipient];
        require(
            allocation_ > 0,
            'User Not Present'
        );

        // adjust their allocation and the total allocation
        allocation[recipient] = ( allocation[recipient] + newAllocation ) - allocation_;
        totalAllocation = ( totalAllocation + newAllocation ) - allocation_;
    }


    function triggerToken(address token) external onlyOwner {

        // get balance of token
        uint256 amount = IERC20(token).balanceOf(address(this));
        require(
            amount > 0,
            'Zero Amount'
        );

        // split balance into distributions
        uint256[] memory distributions = splitAmount(amount);

        // transfer distributions to each recipient
        uint len = distributions.length;
        for (uint i = 0; i < len;) {
            _send(token, recipients[i], distributions[i]);
            unchecked { ++i; }
        }
    }

    function triggerETH() external onlyOwner {

        // Ensure an ETH balance
        require(
            address(this).balance > 0,
            'Zero Amount'
        );

        // split balance into distributions
        uint256[] memory distributions = splitAmount(address(this).balance);

        // transfer distributions to each recipient
        uint len = distributions.length;
        for (uint i = 0; i < len;) {
            _sendETH(recipients[i], distributions[i]);
            unchecked { ++i; }
        }
    }

    function _sendETH(address to, uint amount) internal {
        TransferHelper.safeTransferETH(to, amount);
    }

    function _send(address token, address to, uint256 amount) internal {
        if (to == address(0) || amount == 0) {
            return;
        }
        if (token == address(0)) {
            _sendETH(to, amount);
        } else {
            TransferHelper.safeTransfer(token, to, amount);
        }
    }

    function getRecipients() external view returns (address[] memory) {
        return recipients;
    }

    function splitAmount(uint256 amount) public view returns (uint256[] memory distributions) {

        // length of recipient list
        uint256 len = recipients.length;
        distributions = new uint256[](len);

        // loop through recipients, setting their allocations
        for (uint i = 0; i < len;) {
            distributions[i] = ( ( amount * allocation[recipients[i]] ) / totalAllocation );
            unchecked { ++i; }
        }
    }

    receive() external payable {}
}