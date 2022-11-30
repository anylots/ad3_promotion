// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title AD3lib contract
 * @dev The kol and user model of Ad3.
 *
 * @author Ad3
 **/
library AD3lib {

    ///kol model
    struct kol {
        //kol address
        address _address;
        //fixed production cost
        uint256 fixedFee;
        //percentage of get
        uint8 ratio;
        //Payment stage
        uint256 _paymentStage;
    }

    ///kol and users model
    struct kolWithUsers {
        // Kol address
        address _address;
        // user address
        address[] users;
    }

    ///ECDSA signature of prize
    struct PrizeSignature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }
}
