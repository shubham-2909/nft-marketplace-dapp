const { expect } = require('chai')
describe('NFT MarketPlace', function () {
  let NFTMarket
  let nftMarket
  let listingPrice
  let contractOwner
  let buyerAddress
  let nftMarketAddress

  const auctionPrice = ethers.parseUnits('100', 'ether')
  beforeEach(async () => {
    NFTMarket = await ethers.getContractFactory('NFTMarketplace')
    nftMarket = await NFTMarket.deploy()
    nftMarketAddress = await nftMarket.getAddress()
    const signers = await ethers.getSigners()
    contractOwner = signers[0]
    buyerAddress = signers[1]
    listingPrice = await nftMarket.getListingPrice()
    listingPrice = listingPrice.toString()
  })

  const mintAndListNFT = async (tokenURI, auctionPrice) => {
    const transaction = await nftMarket.createToken(tokenURI, auctionPrice, {
      value: listingPrice,
    })
    const receipt = await transaction.wait()
    const tokenId = receipt.logs[0].args.tokenId
    return tokenId.toString()
  }
  describe('Mint and List a new NFT token', async () => {
    const tokenURI = 'https://some-token.uri/'
    it('Should revert if the auction price is 0', async () => {
      await expect(mintAndListNFT(tokenURI, 0)).to.be.revertedWith(
        'Price must be greater than 0'
      )
    })
    it('Should revert if listing price is not correct', async () => {
      await expect(
        nftMarket.createToken(tokenURI, auctionPrice, { value: 0 })
      ).to.be.revertedWith('Price must be equal to the listing price')
    })

    it('Should create an NFT with the correct owner and tokenURI', async () => {
      const tokenID = await mintAndListNFT(tokenURI, auctionPrice)
      const mintedTokenURI = await nftMarket.tokenURI(tokenID)
      const ownerAddress = await nftMarket.ownerOf(tokenID)
      expect(ownerAddress).to.equal(nftMarketAddress)
      expect(mintedTokenURI).to.equal(tokenURI)
    })
    it('Should emit MarketItemCreated after creating the token successfully', async () => {
      const transaction = await nftMarket.createToken(tokenURI, auctionPrice, {
        value: listingPrice,
      })
      const receipt = await transaction.wait()
      const tokenId = receipt.logs[0].args.tokenId
      await expect(transaction)
        .to.emit(nftMarket, 'MarketItemCreated')
        .withArgs(
          tokenId,
          contractOwner.address,
          nftMarketAddress,
          auctionPrice,
          false
        )
    })
  })

  describe('Execute sale of a MarketPlace item', function () {
    const tokenURI = 'https://some-token.uri/'
    it('Should revert if the amount sent is not equal to the price of the NFT', async () => {
      const newNftToken = await mintAndListNFT(tokenURI, auctionPrice)
      await expect(
        nftMarket
          .connect(buyerAddress)
          .createMarketSale(newNftToken, { value: 30 })
      ).to.be.revertedWith(
        'Please submit the asking price in order to complete the purchase'
      )
    })
    it('Buy a new Token check the owner address of the token', async () => {
      const newNftToken = await mintAndListNFT(tokenURI, auctionPrice)

      const oldAddress = await nftMarket.ownerOf(newNftToken)
      expect(oldAddress).to.equal(nftMarketAddress)
      await nftMarket
        .connect(buyerAddress)
        .createMarketSale(newNftToken, { value: auctionPrice })
      const newOwner = await nftMarket.ownerOf(newNftToken)
      expect(newOwner).to.equal(buyerAddress.address)
    })
  })

  describe('Resell market item', function () {
    const tokenURI = 'https://some-token.uri/'
    it('Should be reverted if owner of price are not correct', async () => {
      const newNftToken = await mintAndListNFT(tokenURI, auctionPrice)
      await nftMarket
        .connect(buyerAddress)
        .createMarketSale(newNftToken, { value: auctionPrice })
      await expect(
        nftMarket.resellToken(newNftToken, auctionPrice, {
          value: listingPrice,
        })
      ).to.be.revertedWith('Only the owner can resell the NFT')

      await expect(
        nftMarket
          .connect(buyerAddress)
          .resellToken(newNftToken, auctionPrice, { value: 0 })
      ).to.be.revertedWith('Listing price must be paid to list NFT again')
    })

    it('Buy a new Token and resell it', async () => {
      const newNftToken = await mintAndListNFT(tokenURI, auctionPrice)

      await nftMarket
        .connect(buyerAddress)
        .createMarketSale(newNftToken, { value: auctionPrice })
      const tokenOwnerAddress = await nftMarket.ownerOf(newNftToken)
      expect(tokenOwnerAddress).to.be.equal(buyerAddress.address)

      await nftMarket
        .connect(buyerAddress)
        .resellToken(newNftToken, auctionPrice, { value: listingPrice })
      const newTokenOwner = await nftMarket.ownerOf(newNftToken)
      expect(newTokenOwner).to.be.equal(nftMarketAddress)
    })
  })

  describe('fetch market items correctly', function () {
    const tokenURI = 'https://some-token.uri/'
    it('Should be able to fetch correct number of unsold items', async () => {
      await mintAndListNFT(tokenURI, auctionPrice)
      await mintAndListNFT(tokenURI, auctionPrice)
      await mintAndListNFT(tokenURI, auctionPrice)

      const unsoldItems = await nftMarket.fetchMarketItems()
      expect(unsoldItems.length).is.equal(3)
    })

    it('Should be able to fetch correct number of NFTs owned by a particular address', async () => {
      const nftToken = await mintAndListNFT(tokenURI, auctionPrice)
      await mintAndListNFT(tokenURI, auctionPrice)
      await nftMarket
        .connect(buyerAddress)
        .createMarketSale(nftToken, { value: auctionPrice })
      const ownerListings = await nftMarket.connect(buyerAddress).fetchMyNFTs()
      expect(ownerListings.length).is.equal(1)
    })

    it('Should be able to fetch correct number of NFTs listed by a particular address', async () => {
      await mintAndListNFT(tokenURI, auctionPrice)
      await mintAndListNFT(tokenURI, auctionPrice)
      await mintAndListNFT(tokenURI, auctionPrice)

      const itemsListed = await nftMarket.fetchItemsListed()
      expect(itemsListed.length).is.equal(3)
    })
  })
})
