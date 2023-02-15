// SPDX-License-Identifier: GPL-3.0 license

pragma solidity ^0.8.0;

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
contract Campaign {
    //make the transfer lower gas-used and more safety.
    using SafeTransferLib for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimPrize(address indexed user, uint256 indexed amount);


    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // campaign only init once.
    bool private _initialized;

    // budget amount for per user.
    uint256 public _userFee;

    // address of ad3hub contract.
    address private _ad3hub;

    // campaign budget token.
    address public _paymentToken;

    // the ecdsa signer used to verify claim for user prizes.
    address private _trustedSigner;
    
    // the kol info saved in the storage.
    mapping(address => AD3lib.kol) private _kolStorages;

    // the account has claimed.
    mapping(address => bool) hasClaimed;


    /*//////////////////////////////////////////////////////////////
                           OWNER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     *@dev Throws if called by any account other than the Ad3Hub.
     */
    modifier onlyAd3Hub() {
        require(
            msg.sender == _ad3hub,
            "The caller must be ad3hub."
        );
        _;
    }

    /**
     * @dev Constructor.
     * @param kols The list of kol
     * @param userFee amount to be awarded to each user
     * @param paymentToken address of paymentToken
     **/
    function init(
        AD3lib.kol[] memory kols,
        uint256 userFee,
        address paymentToken,
        address trustedSigner
    ) public {
        require(_initialized == false, "AD3: campaign is already initialized.");
        _initialized = true;

        _ad3hub = msg.sender;
        _userFee = userFee;
        _paymentToken = paymentToken;
        _trustedSigner = trustedSigner;
        for (uint64 i = 0; i < kols.length; i++) {
            AD3lib.kol memory kol = kols[i];
            require(kol.kolAddress != address(0), "AD3: kol_address is zero address.");
            require(kol.fixedFee > 0, "AD3: kol fixedFee <= 0");
            require(kol.ratio >= 0, "AD3: kol ratio < 0");
            require(kol.ratio <= 100, "AD3: kol ratio > 100");

            _kolStorages[kol.kolAddress] = kol;
        }
    }


    /**
     * @dev Withdraw the remaining funds to advertiser.
     * @param advertiser The campaign's creater or owner
     **/
    function withdraw(address advertiser) public onlyAd3Hub returns (bool) {
        uint256 balance = IERC20(_paymentToken).balanceOf(address(this));

        IERC20(_paymentToken).safeTransfer(advertiser, balance);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                           USER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev claim user prize.
     * @param signature ECDSA signature of prize
     * @param amount The campaign's creater or owner
     **/
    function claimUserPrize(AD3lib.PrizeSignature calldata signature, uint256 amount) external {
        require(hasClaimed[msg.sender] == false, "Repeated claim.");
        require(amount <= _userFee, "Amount invalid.");
        
        address signer = ecrecover(_createMessageDigest(address(this), msg.sender, amount), signature.v, signature.r, signature.s);
        require(signer != address(0), "PrizeSigner is zero address.");
        require(_trustedSigner == signer, "PrizeSignature invalid.");

        hasClaimed[msg.sender] = true;
        IERC20(_paymentToken).safeTransfer(msg.sender, amount);

        emit ClaimPrize(msg.sender, amount);
    }

    /**
     * @dev _createMessageDigest.
     * @param _campaign campaign address
     * @param _user user address
     * @param _amount prize amount for claim
     **/
    function _createMessageDigest(address _campaign, address _user, uint256 _amount) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_campaign, _user, _amount))
            )
    );
}  

    /**
     * @dev Query campaign remain balance.
     **/
    function remainBalance() public view returns (uint256) {
        uint256 balance = IERC20(_paymentToken).balanceOf(address(this));
        return balance;
    }

}
