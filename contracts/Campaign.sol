// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SafeTransferLib} from "./libs/SafeTransferLib.sol";
import "./libs/AD3lib.sol";


/**
 * @title Campaign contract
 * @dev Fund and crowd management logic of Ad3 protocol.
 * - All admin functions are callable by the ad3Hub
 * - Users can:
 *   # Query campaign remain balance
 *
 * @author Ad3
 **/
contract Campaign is Ownable {
    using SafeTransferLib for IERC20;

    mapping(address => AD3lib.kol) private _kolStorages;
    address private _ad3hub;
    uint256 public _serviceCharge = 5;
    uint public _userFee;
    address public _paymentToken;

    modifier onlyAd3Hub() {
        require(
            msg.sender == _ad3hub,
            "The caller of this function must be a ad3hub"
        );
        _;
    }

    /**
     * @dev Constructor.
     * @param kols The list of kol
     * @param userFee amount to be awarded to each user
     * @param paymentToken address of paymentToken
     **/
    constructor(
        AD3lib.kol[] memory kols,
        uint256 userFee,
        address paymentToken
    ) payable {
        _ad3hub = msg.sender;
        _userFee = userFee;
        _paymentToken = paymentToken;
        for (uint64 i = 0; i < kols.length; i++) {
            AD3lib.kol memory kol = kols[i];
            require(kol._address != address(0), "AD3: kol_address is zero address");
            require(kol.fixedFee > 0, "AD3: kol fixedFee <= 0");
            require(kol.ratio >= 0, "AD3: kol ratio < 0");
            require(kol.ratio < 100, "AD3: kol ratio >= 100");

            _kolStorages[kol._address] = kol;
        }
    }

    /**
     * @dev Pay fixFee to kols.
     * @param kols The address list of kol
     **/
    function payfixFee(address[] memory kols) public onlyOwner returns (bool) {

        for (uint64 i = 0; i < kols.length; i++) {
            address kolAddress = kols[i];
            AD3lib.kol memory kol = _kolStorages[kolAddress];
            require(kol._paymentStage < 2, "AD3: prepay already done");
            
            kol._paymentStage++;
            //pay for kol
            IERC20(_paymentToken).safeTransfer(kol._address, kol.fixedFee / 2);
        }
        return true;
    }

    /**
     * @dev Pay to users and kols.
     * @param kols The address list of kolWithUsers
     **/
    function pushPay(AD3lib.kolWithUsers[] memory kols) public onlyOwner returns (bool) {
        require(kols.length > 0,"AD3: kols of pay is empty");

        uint256 balance = IERC20(_paymentToken).balanceOf(address(this));
        require(balance > 0,"AD3: comletePay insufficient funds");

        for (uint64 i = 0; i < kols.length; i++) {
            AD3lib.kolWithUsers memory kolWithUsers = kols[i];

            address[] memory users = kolWithUsers.users;
            require(users.length > 0, "AD3: users list is empty");
            AD3lib.kol memory kol = _kolStorages[kolWithUsers._address];

            // pay for kol
            IERC20(_paymentToken).safeTransfer(kol._address, (users.length * _userFee * kol.ratio) /100 );
            uint256 user_amount = _userFee * (100 - kol.ratio) / 100;
            for (uint64 index = 0; index < users.length; index++) {
                address userAddress = users[index];
                require(userAddress != address(0), "user_address is zero address");

                // pay for user
                IERC20(_paymentToken).safeTransfer(userAddress, user_amount);
            }
        }
        return true;
    }

    /**
     * @dev Withdraw the remaining funds to advertiser.
     * @param advertiser The campaign's creater or owner
     **/
    function withdraw(address advertiser) public onlyOwner returns (bool) {
        uint256 balance = IERC20(_paymentToken).balanceOf(address(this));

        require(IERC20(_paymentToken).transfer(advertiser, balance));

        return true;
    }

    /**
     * @dev Query campaign remain balance.
     **/
    function remainBalance() public view returns (uint256) {
        uint256 balance = IERC20(_paymentToken).balanceOf(address(this));
        return balance;
    }

    /**
     * @dev setServiceCharge.
     * @param value The percentage ServiceCharge
     **/
    function setServiceCharge(uint8 value) public onlyOwner {
        require(value > 0,"AD3: serviceCharge <= 0");
        require(value <= 10,"AD3: serviceCharge > 10");
        _serviceCharge = value;
    }
}
