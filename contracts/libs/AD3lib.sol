// SPDX-License-Identifier: GPL-3.0 license

pragma solidity ^0.8.0;

/**
 * @title AD3lib contract
 * @dev The kol and user model、prize singnature of campaign.
 *
 * @author Ad3
 **/
library AD3lib {

    /// kol model
    struct kol {
        // kol address
        address kolAddress;
        // fixed production cost
        uint256 fixedFee;
        // percentage of get
        uint8 ratio;
        // payment stage
        uint256 paymentStage;
    }

    /// kol and users model
    struct kolWithUsers {
        // Kol address
        address kolAddress;
        // user address
        address[] users;
    }

    /// kol and users quantity
    struct kolWithUserQuantity {
        // Kol address
        address kolAddress;
        // users quantity
        uint256 quantity;
    }

    /// ECDSA signature of prize
    // We sign the compact information of campaignId, user address
    // and prize amount off chain, and users use the signature information 
    // corresponding to their address to call the contract to calim rewards.
    struct PrizeSignature {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }
}
