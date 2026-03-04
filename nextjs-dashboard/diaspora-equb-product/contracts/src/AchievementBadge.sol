// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AchievementBadge {
    string public name = "Equb Achievement Badge";
    string public symbol = "EQBADGE";

    address public minter;
    address public owner;

    uint256 public totalSupply;

    struct Badge {
        uint256 badgeType;
        address recipient;
        string metadataURI;
        uint256 mintedAt;
    }

    mapping(uint256 => Badge) public badges;
    mapping(address => uint256[]) public badgesByOwner;
    mapping(address => mapping(uint256 => bool)) public hasBadgeType;

    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event BadgeMinted(address indexed to, uint256 indexed tokenId, uint256 badgeType, string metadataURI);
    event MinterUpdated(address indexed newMinter);

    // Badge types
    // 0 = FirstEqubJoined, 1 = FirstEqubCompleted, 2 = Tier2Unlocked, 3 = Tier3Unlocked
    // 4 = ZeroDefaultsX10, 5 = TrustedDanna5, 6 = PerfectConsistency, 7 = DiasporaPioneer
    // 8 = HundredContributions, 9 = TopReferrer

    constructor() {
        owner = msg.sender;
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "only minter");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
        emit MinterUpdated(_minter);
    }

    function mint(address to, uint256 badgeType, string calldata metadataURI) external onlyMinter returns (uint256) {
        require(!hasBadgeType[to][badgeType], "already has badge type");

        totalSupply++;
        uint256 tokenId = totalSupply;

        _owners[tokenId] = to;
        _balances[to]++;

        badges[tokenId] = Badge(badgeType, to, metadataURI, block.timestamp);
        badgesByOwner[to].push(tokenId);
        hasBadgeType[to][badgeType] = true;

        emit Transfer(address(0), to, tokenId);
        emit BadgeMinted(to, tokenId, badgeType, metadataURI);

        return tokenId;
    }

    function transferFrom(address, address, uint256) external pure {
        revert("soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256) external pure {
        revert("soulbound: non-transferable");
    }

    function safeTransferFrom(address, address, uint256, bytes calldata) external pure {
        revert("soulbound: non-transferable");
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function balanceOf(address _owner) external view returns (uint256) {
        return _balances[_owner];
    }

    function getBadge(uint256 tokenId) external view returns (Badge memory) {
        return badges[tokenId];
    }

    function getBadgesOf(address _owner) external view returns (uint256[] memory) {
        return badgesByOwner[_owner];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return badges[tokenId].metadataURI;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x80ac58cd || interfaceId == 0x01ffc9a7;
    }
}
