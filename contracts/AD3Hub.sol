// SPDX-License-Identifier: MIT

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

    address public _paymentToken;

    address public _trustedSigner;

    // Mapping from Advertiser address to campaign address
    mapping(address => mapping(uint64 => address)) private campaigns;

    // Mapping from campaign address to the lastest campaignId
    mapping(address => uint64) private campaignIds;


    /*//////////////////////////////////////////////////////////////
                        ADVERTISER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Create an Campaign.
     * @param kols The list of kol
     * @param totalBudget The amount of campaign
     * @param userFee amount to be awarded to each user
     **/
    function createCampaign(
        AD3lib.kol[] memory kols,
        uint256 totalBudget,
        uint256 userFee
    ) external returns (address) {
        require(kols.length > 0, "AD3: kols is empty");
        require(totalBudget > 0, "AD3: totalBudget > 0");
        require(userFee > 0, "AD3: userFee <= 0");

        //create campaign
        Campaign xcampaign = new Campaign(kols, userFee, _paymentToken, _trustedSigner);

        //init amount
        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            address(xcampaign),
            totalBudget
        );

        //register to mapping
        uint64 length = campaignIds[msg.sender];
        length++;
        campaigns[msg.sender][length] = address(xcampaign);
        campaignIds[msg.sender] = length;
        emit CreateCampaign(msg.sender, totalBudget);
        return address(xcampaign);
    }

    /**
     * @dev Create an campaign with Minimal Proxy.
     * @param kols The list of kol
     * @param totalBudget The amount of campaign
     * @param userFee amount to be awarded to each user
     **/
    function createWithMinimalProxy(address[] memory kols, uint256 totalBudget, uint256 userFee) external returns (address instance) {
        require(kols.length > 0,"kols is empty");

        /// @solidity memory-safe-assembly

        //create campaign
        assembly{
            let proxy :=mload(0x40)
            mstore(proxy, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(proxy, 0x14), 0xdAC17F958D2ee523a2206206994597C13D831ec7)
            mstore(add(proxy, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, proxy, 0x37)
        }
        
        //init kols
        (bool success, ) = instance.call(abi.encodeWithSignature("init(address,address,string,string)", address(this), userFee, _trustedSigner));
        require(success == true,"createCampaign init fail");

        //init amount
        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            address(instance),
            totalBudget
        );

        //register to mapping
        uint64 length = campaignIds[msg.sender];
        campaignIds[msg.sender] = length++;
        campaigns[msg.sender][length] = address(instance);
        emit CreateCampaign(msg.sender, totalBudget);
        return address(instance);
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
        require(balance > 0, 'AD3: balance <= 0');

        bool payContentFeeSuccess = Campaign(campaigns[advertiser][campaignId]).payfixFee(kols);
        require(payContentFeeSuccess, "AD3: payContentFee failured");

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
        require(balance > 0, 'AD3: balance <= 0');

        bool pushPaySuccess = Campaign(campaigns[advertiser][campaignId]).pushPay(kols);
        require(pushPaySuccess, "AD3: pushPay failured");
        emit Pushpay(advertiser);
    }

    /**
     * @dev Withdraw the remaining funds to advertiser.
     * @param advertiser The campaign's creater or owner
     * @param campaignId index in advertiser's campaign list
     **/
    function withdraw(address advertiser, uint64 campaignId) external onlyOwner{
        require(advertiser != address(0), "AD3Hub: advertiser is zero address");

        require(
            campaigns[advertiser][campaignId] != address(0),
            "AD3Hub: advertiser not create campaign"
        );

        bool withdrawSuccess = Campaign(campaigns[advertiser][campaignId]).withdraw(advertiser);
        require(withdrawSuccess, "AD3: withdraw failured");
        emit Withdraw(advertiser);
    }


    /**
     * @dev Set Payment Token of campaign.
     * @param token address of token
     **/
    function setPaymentToken(address token) external onlyOwner{
        require(token != address(0), "AD3Hub: paymentToken is zero address");
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
        require(trustedSigner != address(0), "AD3Hub: trustedSigner is zero address");
        _trustedSigner = trustedSigner;
    }

    /**
     * @dev Get trustedSigner of campaign.
     * @return trustedSigner address of trustedSigner
     **/
    function getTrustedSigner() external view returns (address){
        return _trustedSigner;
    }


    /*//////////////////////////////////////////////////////////////
                        PUBLIC OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev get Address of Campaign
     * @param advertiser The address of the advertiser who create campaign
     **/
    function getCampaignAddress(address advertiser, uint64 campaignId) public view returns(address){
        require(advertiser != address(0), "AD3Hub: advertiser is zero address");
        return campaigns[advertiser][campaignId];
    }

    /**
     * @dev get Address list of Campaign
     * @param advertiser The address list of the advertiser who create campaign
     **/
    function getCampaignAddressList(address advertiser) public view returns(address[] memory){
        require(advertiser != address(0), "AD3Hub: advertiser is zero address");
        uint64 length = campaignIds[advertiser];
        if(length == 0){
            revert();
        }
        address[] memory campaignList = new address[](length);
        for(uint64 i =0; i<length; i++){
            campaignList[i] = campaigns[advertiser][i+1];
        }
        return campaignList;
    }
}
