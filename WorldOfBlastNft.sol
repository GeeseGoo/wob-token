// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IWorldOfBlastCrafting {
    function getCraftableItem(uint256 id)
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl,
            uint256 weightProbability
        );

    function drawCraftableItem()
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl,
            uint256 weightProbability
        );
}

contract WorldOfBlastNft is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    struct Item {
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        bool isStaked;
    }

    IERC20 private WOB;
    IWorldOfBlastCrafting private craftingContract;

    address payable public _owner;
    uint256 public priceToCreateNftWOB;
    uint256 public tokenIdCounter;
    string public _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) public creators;

    event ItemCreated(uint256 indexed tokenId, address indexed owner);
    event ItemUpdated(uint256 indexed tokenId, uint256 durability);
    event InBattleSet(uint256 indexed tokenId, bool value);

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        _;
    }

    modifier onlyCreator() {
        require(creators[msg.sender], "Only owner or creator");
        _;
    }

    constructor(address _crafting, address _wob)
        ERC721("World Of Blast", "WOBNFTs")
        Ownable(msg.sender)
    {
        WOB = IERC20(_wob);
        craftingContract = IWorldOfBlastCrafting(_crafting);
        _owner = payable(msg.sender);
        _contractURI = "https://worldofblast.com/assets/contract.json";
        creators[msg.sender] = true;
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(IERC20(_contract).transfer(to, amount), "Failed to transfer");
    }

    function updateWOBAddress(address _newWobAddress) external onlyOwner {
        require(_newWobAddress != address(0), "Invalid address");
        WOB = IERC20(_newWobAddress);
    }

    function updateCraftingContractAddress(address _newCraftingAddress)
        external
        onlyOwner
    {
        require(_newCraftingAddress != address(0), "Invalid address");
        craftingContract = IWorldOfBlastCrafting(_newCraftingAddress);
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function updatePriceToCreateNftWOB(uint256 price) external onlyOwner {
        priceToCreateNftWOB = price;
    }

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
    }

    function mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyCreator
    {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;
            (
                string memory name,
                string memory description,
                uint256 damage,
                uint256 attackSpeed,
                uint256 durability,
                uint256 durabilityPerUse,
                string memory weaponType,
                string memory imageUrl,

            ) = craftingContract.getCraftableItem(craftableItemId);
            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                false
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function mintWithWOB(uint256 quantity) external returns (uint256[] memory) {
        uint256 priceWOB = priceToCreateNftWOB * quantity;
        require(
            WOB.balanceOf(msg.sender) >= priceWOB,
            "Insufficient WOB balance"
        );
        require(
            WOB.transferFrom(msg.sender, address(this), priceWOB),
            "Failed to transfer WOB"
        );

        uint256[] memory itemIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;
            (
                string memory name,
                string memory description,
                uint256 damage,
                uint256 attackSpeed,
                uint256 durability,
                uint256 durabilityPerUse,
                string memory weaponType,
                string memory imageUrl,

            ) = craftingContract.drawCraftableItem();
            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                false
            );
            itemIds[i] = tokenId;
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
        return itemIds;
    }

    function updateItemDurability(uint256 tokenId, uint256 durability)
        external
        onlyCreator
    {
        Item storage item = items[tokenId];
        require(item.isStaked, "Item is not in staked");
        item.durability = durability;
        emit ItemUpdated(tokenId, durability);
    }

    function setIsStakedTrue(uint256 tokenId) external onlyTokenOwner(tokenId) {
        Item storage item = items[tokenId];
        require(!item.isStaked, "Item is already in staked");
        item.isStaked = true;
        emit InBattleSet(tokenId, true);
    }

    function setIsStakedFalse(uint256 tokenId) external onlyCreator {
        Item storage item = items[tokenId];
        require(item.isStaked, "Item is not in staked");
        item.isStaked = false;
        emit InBattleSet(tokenId, false);
    }

    function transferItem(address to, uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
    {
        _transfer(msg.sender, to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");

        string memory baseURI = _baseURI();

        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                items[tokenId].name,
                '", ',
                '"description": "',
                items[tokenId].description,
                '", ',
                '"image": "',
                items[tokenId].imageUrl,
                '", ',
                '"attributes": {',
                '"damage": ',
                uint2str(items[tokenId].damage),
                ", ",
                '"attackSpeed": ',
                uint2str(items[tokenId].attackSpeed),
                ", ",
                '"durability": ',
                uint2str(items[tokenId].durability),
                ", ",
                '"durabilityPerUse": ',
                uint2str(items[tokenId].durabilityPerUse),
                ", ",
                '"weaponType": "',
                items[tokenId].weaponType,
                '"',
                "}, ",
                '"external_link": "https://worldofblast.com"'
                "}"
            )
        );
        return string(abi.encodePacked(baseURI, json));
    }

    function getItemDetails(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl
        )
    {
        Item storage item = items[tokenId];
        return (
            item.name,
            item.description,
            item.damage,
            item.attackSpeed,
            item.durability,
            item.durabilityPerUse,
            item.weaponType,
            item.imageUrl
        );
    }

    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory result = new uint256[](tokenCount);
        uint256 resultIndex = 0;
        for (uint256 tokenId = 0; tokenId < tokenIdCounter; tokenId++) {
            if (ownerOf(tokenId) == owner) {
                result[resultIndex] = tokenId;
                resultIndex++;
            }
        }
        return result;
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
