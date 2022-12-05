// SPDX-License-Identifier: GPL-3.0 license

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Campaign.sol";


/**
 * @title AD3Hub contract
 * @dev Main point of interaction with an Ad3 protocol's campaign manage
 * - Advertisers can:
 *   # CreateCampaign
 *   # GetCampaignAddress
 * - Owner can:
 *   # PayfixFee
 *   # Pushpay 
 *   # Withdraw
 * - All admin functions are callable by the deployer
 *
 * @author Ad3
 **/
contract AD3Hub is Ownable {
    //make the transfer lower gas-used and more safety.
    using SafeTransferLib for IERC20;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event CreateCampaign(address indexed advertiser, uint256 indexed totalBudget);

    event PayFixFee(address indexed advertiser);

    event Pushpay(address indexed advertiser);

    event Withdraw(address indexed advertiser);


    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // Campaign budget token, used to prepare campaign funds and pay to kol and user.
    address public _paymentToken;

    // The ecdsa signer used to verify claim for user prizes
    address public _trustedSigner;

    // Logical implementation of campaign
    address private _campaignImpl;

    // Mapping from Advertiser address to campaign addresses
    mapping(address => mapping(uint64 => address)) private campaigns;

    // Mapping from campaign address to the lastest campaignId, 
    // campaignId should be incremented from 1.
    mapping(address => uint64) private campaignIds;


    /*//////////////////////////////////////////////////////////////
                        ADVERTISER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Create an campaign with Minimal Proxy.
     * @param kols The list of kol
     * @param totalBudget The amount of campaign
     * @param userFee amount to be awarded to each user
     **/
    function createCampaign(AD3lib.kol[] memory kols, uint256 totalBudget, uint256 userFee) external 
    returns(address instance){
        require(kols.length > 0, "kols is empty.");

        bytes20 impl = bytes20(_campaignImpl);

        /// @solidity memory-safe-assembly
        assembly{
            // Load free memory point.
            let proxy :=mload(0x40)
            // Copying runtime code into memory, get the calldata, prepare input and output parmeter.
            mstore(proxy, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            // Copying impl address into memory.
            mstore(add(proxy, 0x14), impl)
            // Delegating the call.
            mstore(add(proxy, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, proxy, 0x37)
        }
        require(instance != address(0), "ERC1167: campaign create failed.");

        // init campaign   
        Campaign(instance).init(kols, userFee, _paymentToken, _trustedSigner);
        // init amount
        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            instance,
            totalBudget
        );

        // save campaign to mapping
        uint64 lastest = campaignIds[msg.sender];
        lastest++;
        campaigns[msg.sender][lastest] = instance;
        campaignIds[msg.sender] = lastest;
        emit CreateCampaign(msg.sender, totalBudget);
    }

    /*//////////////////////////////////////////////////////////////
                           OWNER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Pay fixFee to kols.
     * @param kols The address list of kol
     * @param advertiser The campaign's creater or owner
     * @param campaignId index in advertiser's campaign list
     **/
    function payfixFee(address[] memory kols, address advertiser, uint64 campaignId) external onlyOwner{
        uint256 balance = IERC20(_paymentToken).balanceOf(campaigns[advertiser][campaignId]);
        require(balance > 0, "AD3: balance <= 0");

        bool payContentFeeSuccess = Campaign(campaigns[advertiser][campaignId]).payfixFee(kols);
        require(payContentFeeSuccess, "AD3: payContentFee failured.");

        emit PayFixFee(msg.sender);
    }

    /**
     * @dev Pay to users and kols.
     * @param advertiser The campaign's creater or owner
     * @param campaignId index in advertiser's campaign list
     * @param kols The address list of kolWithUsers
     **/
    function pushPay(address advertiser, uint64 campaignId, AD3lib.kolWithUsers[] calldata kols) external onlyOwner{
        uint256 balance = IERC20(_paymentToken).balanceOf(campaigns[advertiser][campaignId]);
        require(balance > 0,"AD3: pushPay insufficient funds.");

        bool pushPaySuccess = Campaign(campaigns[advertiser][campaignId]).pushPay(kols);
        require(pushPaySuccess, "AD3: pushPay failured.");
        emit Pushpay(advertiser);
    }

    /**
     * @dev Pay to kols.
     * @param kols The address list of kolWithUserQuantity.
     **/
    function pushPayKol(address advertiser, uint64 campaignId, AD3lib.kolWithUserQuantity[] memory kols) external onlyOwner {
        uint256 balance = IERC20(_paymentToken).balanceOf(campaigns[advertiser][campaignId]);
        require(balance > 0,"AD3: pushPay insufficient funds.");

        bool pushPaySuccess = Campaign(campaigns[advertiser][campaignId]).pushPayKol(kols);
        require(pushPaySuccess, "AD3: pushPay failured.");
        emit Pushpay(advertiser);
    }

    /**
     * @dev Withdraw the remaining funds to advertiser.
     * @param advertiser The campaign's creater or owner
     * @param campaignId index in advertiser's campaign list
     **/
    function withdraw(address advertiser, uint64 campaignId) external onlyOwner{
        require(advertiser != address(0), "AD3Hub: advertiser is zero address.");

        require(
            campaigns[advertiser][campaignId] != address(0),
            "AD3Hub: No such campaign"
        );

        bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId]).withdraw(advertiser);
        require(withdrawSuccess, "AD3: withdraw failured.");
        emit Withdraw(advertiser);
    }


    /**
     * @dev Set Payment Token of campaign.
     * @param token address of token
     **/
    function setPaymentToken(address token) external onlyOwner{
        require(token != address(0), "AD3Hub: paymentToken is zero address.");
        _paymentToken = token;
    }

    /**
     * @dev Get Payment Token of campaign.
     * @return token address of token
     **/
    function getPaymentToken() external view returns (address){
        return _paymentToken;
    }

    /**
     * @dev Set trustedSigner of campaign.
     * @param trustedSigner address of trustedSigner
     **/
    function setTrustedSigner(address trustedSigner) external onlyOwner{
        require(trustedSigner != address(0), "AD3Hub: trustedSigner is zero address.");
        _trustedSigner = trustedSigner;
    }

    /**
     * @dev Get trustedSigner of campaign.
     * @return trustedSigner address of trustedSigner
     **/
    function getTrustedSigner() external view returns (address){
        return _trustedSigner;
    }

    /**
     * @dev Set address of campaignImpl.
     * @param campaign address of campaignImpl
     **/
    function setCampaignImpl(address campaign) external onlyOwner{
        require(campaign != address(0), "AD3Hub: campaignImpl is zero address.");
        _campaignImpl = campaign;
    }


    /*//////////////////////////////////////////////////////////////
                        PUBLIC OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev get Address of Campaign
     * @param advertiser The address of the advertiser who create campaign
     **/
    function getCampaignAddress(address advertiser, uint64 campaignId) public view returns(address){
        require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
        return campaigns[advertiser][campaignId];
    }

    /**
     * @dev get Address list of Campaign
     * @param advertiser The address list of the advertiser who create campaign
     **/
    function getCampaignAddressList(address advertiser) public view returns(address[] memory){
        require(advertiser != address(0), "AD3Hub: advertiser is zero address.");
        uint64 lastest = campaignIds[advertiser];
        address[] memory campaignList;
        if(lastest == 0){
            return campaignList;
        }
        campaignList = new address[](lastest);
        for(uint64 i =0; i<lastest; i++){
            campaignList[i] = campaigns[advertiser][i+1];
        }
        return campaignList;
    }
}
