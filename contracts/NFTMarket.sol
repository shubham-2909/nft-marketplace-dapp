//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds; //total number of items ever created
    Counters.Counter private _itemsSold; //total number of items sold
    uint256 listingPrice = 0.001 ether; //people have to pay to list their nft
    address payable owner; //owner of the smart contract

    constructor() ERC721("Phoenix Tokens", "PHOE") {
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }
    mapping(uint256 => MarketItem) private idtoMarketItem;
    event MarketItemCreated(
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );

    //function to get the listing price
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    // function to update the listing price
    function updateListingPrice(uint _listingPrice) public payable {
        require(
            msg.sender == owner,
            "Only owner of the marketplace can update the listing price"
        );
        listingPrice = _listingPrice;
    }

    function createMarketItem(uint256 tokenId, uint256 price) private {
        require(price > 0, "Price must be greater than 0");
        require(
            msg.value == listingPrice,
            "Price must be equal to the listing price"
        );
        idtoMarketItem[tokenId] = MarketItem(
            tokenId,
            payable(msg.sender),
            payable(address(this)),
            price,
            false
        );
        _transfer(msg.sender, address(this), tokenId);
        emit MarketItemCreated(
            tokenId,
            payable(msg.sender),
            address(this),
            price,
            false
        );
    }

    // mint a new marketItem
    function createToken(
        string memory tokenURI,
        uint256 price
    ) public payable returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _mint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createMarketItem(newTokenId, price);
        return newTokenId;
    }

    // create a market sale
    // also involves transfer of funds between the parties
    function createMarketSale(uint256 tokenId) public payable {
        uint price = idtoMarketItem[tokenId].price;
        address seller = idtoMarketItem[tokenId].seller;
        require(
            msg.value == price,
            "Please submit the asking price in order to complete the purchase"
        );
        idtoMarketItem[tokenId].owner = payable(msg.sender);
        idtoMarketItem[tokenId].sold = true;
        idtoMarketItem[tokenId].seller = payable(address(0));
        _itemsSold.increment();
        _transfer(address(this), msg.sender, tokenId);
        payable(owner).transfer(listingPrice);
        payable(seller).transfer(price);
    }

    // function to get unsold market items
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _tokenIds.current();
        uint unsoldItemCount = _tokenIds.current() - _itemsSold.current();
        uint currentIndex = 0;
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint i = 0; i < itemCount; i++) {
            if (idtoMarketItem[i + 1].owner == address(this)) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idtoMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }
        return items;
    }

    // function to get the NFT's owned by a particular user
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idtoMarketItem[i + 1].owner == msg.sender) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idtoMarketItem[i + 1].owner == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idtoMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }

        return items;
    }

    // function to fetch NFTs listed by a particular user

    function fetchItemsListed() public view returns (MarketItem[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idtoMarketItem[i + 1].seller == msg.sender) {
                itemCount++;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (idtoMarketItem[i + 1].seller == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idtoMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex++;
            }
        }

        return items;
    }

    // Allows a user to resell the token they have purchased
    function resellToken(uint256 tokenId, uint256 price) public payable {
        require(
            idtoMarketItem[tokenId].owner == msg.sender,
            "Only the owner can resell the NFT"
        );
        require(
            msg.value == listingPrice,
            "Listing price must be paid to list NFT again"
        );
        idtoMarketItem[tokenId].sold = false;
        idtoMarketItem[tokenId].price = price;
        idtoMarketItem[tokenId].seller = payable(msg.sender);
        idtoMarketItem[tokenId].owner = payable(address(this));
        _itemsSold.decrement();
        _transfer(msg.sender, address(this), tokenId);
    }

    // Allows a user to Cancel their market listing
    function cancelItemListing(uint256 tokenId) public {
        require(
            idtoMarketItem[tokenId].seller == msg.sender,
            "Only the item seller can perform this operation"
        );
        require(
            idtoMarketItem[tokenId].sold == false,
            "Only items which are not sold are allowd to cancel"
        );
        idtoMarketItem[tokenId].owner = payable(msg.sender);
        idtoMarketItem[tokenId].seller = payable(address(0));
        idtoMarketItem[tokenId].sold = true;
        _itemsSold.increment();
        payable(owner).transfer(listingPrice);
        _transfer(address(this), msg.sender, tokenId);
    }
}
