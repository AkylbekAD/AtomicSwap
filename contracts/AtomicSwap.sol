// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @author AkylbekAD

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AtomicSwap {
    /// @dev Structure of each created coin locks
    struct CoinLock {
        address token;
        uint256 amount;
        uint256 expiration;
        address buyer;
        address seller;
    }

    /// @dev Structure of each locked ETH
    struct ETHLock {
        uint256 amount;
        uint256 expiration;
        address buyer;
        address seller;
    }

    /// @notice You can chech your coin lock by coinSecretHash
    /// @param secretHash Hashed secret phrase with SHA256
    mapping(bytes32 => Order) public coinSecretHash;

    /// @notice You can chech your ETH lock by ehtSecretHash
    /// @param secretHash Hashed secret phrase with SHA256
    mapping(bytes32 => ETHLock) public ehtSecretHash;

    event CoinsLocked(bytes32 indexed secretHash, address indexed seller);
    event CoinsClaimed(address indexed seller, address indexed buyer, address indexed token, uint256 amount);
    event CoinsRefunded(bytes32 indexed secretHash, address indexed seller);

    event ETHLocked(bytes32 indexed secretHash, address indexed buyer);
    event ETHClaimed(address indexed buyer, address indexed seller, uint256 amount);
    event ETHRefunded(bytes32 indexed secretHash, address indexed buyer);

    /* Prevent a contract function from being reentrant-called. */
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
        _;
        // By storing the original value once again, a refund is triggered
        _status = _NOT_ENTERED;
    }

    constructor() {
        _status = _NOT_ENTERED;
    }

    /// @notice Locks your approved coins for buyer
    /// @param _secretHash Your hashed with SHA256 secret phrase
    /// @param _expiration Lock time for coins
    /// @param _amount Approved amount of coins to lock
    /// @param _buyer Address of buyer who claims coins
    /// @param _token Address of coin(token) to lock quantity
    function lockCoins(
        bytes32 _secretHash,
        uint256 _expiration,
        uint256 _amount,
        address _buyer,
        address _token
    ) external {
        require(_expiration >= 900, "15 minutes is required for swap");
        require(_buyer != address(0), "Buyer can not be Zero address")

        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        coinSecretHash[_secretHash].token = _token;
        coinSecretHash[_secretHash].amount = _amount;
        coinSecretHash[_secretHash].expiration = block.timestamp +_expiration;
        coinSecretHash[_secretHash].buyer = _buyer;
        coinSecretHash[_secretHash].seller = msg.sender;

        emit CoinsLocked(_secretHash, msg.sender);
    }

    /// @notice Locks your ETH for seller
    /// @param _secretHash Your hashed with SHA256 secret phrase
    /// @param _expiration Lock time for ETH
    /// @param _seller Address of coins seller
    function lockETH(
        bytes32 _secretHash,
        uint256 _expiration,
        address _seller
    ) external payable {
        require(_expiration >= 600, "10 minutes is required for swap");
        require(_seller != address(0), "Seller can not be Zero address")

        ethSecretHash[_secretHash].amount = msg.value;
        ethSecretHash[_secretHash].expiration = block.timestamp +_expiration;
        ethSecretHash[_secretHash].seller = _seller;
        ethSecretHash[_secretHash].buyer = msg.sender;

        emit ETHLocked(_secretHash, msg.sender);
    }

    /// @notice Claims coins to buyer by secret phrase
    /// @param _secret Secret phrase which was hashed with SHA256 to lock coins
    function claimCoins(bytes32 _secret) external {
        CoinLock memory lock = coinSecretHash[sha256(abi.encodePacked(_secret))]
        require(lock.seller != address(0), "Invalid _secret");
        

        IERC20(lock.token).transfer(lock.buyer, lock.amount);

        delete coinSecretHash[sha256(abi.encodePacked(_secret))];

        emit CoinsClaimed(lock.seller, lock.buyer, lock.token, lock.amount);
    }

    /// @notice Claims ETH to seller by secret phrase
    /// @param _secret Secret phrase which was hashed with SHA256 to lock ETH
    function claimETH(bytes32 _secret) external nonReentrant {
        ETHLock memory lock = ethSecretHash[sha256(abi.encodePacked(_secret))]
        require(lock.buyer != address(0), "Invalid _secret");

        (bool success, ) = lock.seller.call{value: lock.amount}("");
        require(success, "Cant send ETH to seller")

        delete ethSecretHash[sha256(abi.encodePacked(_secret))];

        emit ETHClaimed(lock.buyer, lock.seller, lock.amount);
    }

    /// @notice Returns coins to seller if buyer didnt claim their
    /// @param _secretHash Hashed secret phrase whith SHA256
    function refundCoins(bytes32 _secretHash) external {
        CoinLock memory lock = coinSecretHash[_secretHash];
        require(block.timestamp <= lock.expiration, "Too early to refund");

        IERC20(lock.token).transfer(lock.seller, lock.amount);

        delete coinSecretHash[_secretHash];

        emit CoinsRefunded(_secretHash, lock.seller);
    }

    /// @notice Returns ETH to buyer if seller didnt claim their
    /// @param _secretHash Hashed secret phrase whith SHA256
    function refundETH(bytes32 _secretHash) external {
        ETHLock memory lock = ethSecretHash[_secretHash];
        require(block.timestamp <= lock.expiration, "Too early to refund");

        (bool success, ) = lock.buyer.call{value: lock.amount}("");
        require(success, "Cant send ETH to buyer")

        delete ethSecretHash[_secretHash];

        emit CoinsRefunded(_secretHash, lock.buyer);
    }
}
