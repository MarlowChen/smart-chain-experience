//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "https://github.com/chiru-labs/ERC721A/blob/v3.1.0/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MetadataMarket is Ownable, ERC721A, ERC2981, ReentrancyGuard {

    
    string public baseURI;

    mapping(address => bool) public whitelist;

    struct MetadataInfo {
        string id;
        string path;
        uint256 size;
        uint256 price;
        bool sell;
        uint256[] metadataInfoTokens;
    }

    struct PrivateMetadataInfo{
        uint256 privateSalePrice;
        mapping(address => uint256) allowlist;
        bool deductedAmount;
        bool pausePrivateSale;
    }

    mapping(string => PrivateMetadataInfo) public privateMetadataInfoList;
    mapping(string => MetadataInfo) public metadataInfoList;
    mapping(uint256 => string) public tokenMetadataInfoPath;


    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI,
        address payable royaltyReceiver
    ) ERC721A(_name, _symbol) {
        setBaseURI(_initBaseURI);
        _setDefaultRoyalty(royaltyReceiver, 1000);
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function publicMint(address _to, string memory _id, uint256 _mintAmount) external payable callerIsUser{
        MetadataInfo storage m = metadataInfoList[_id];
        require(bytes(m.id).length > 0, "MetadataInfo not exist" );
        require(m.size - _mintAmount >= 0, "Not enough quantity" );
        require(msg.value >= m.price * _mintAmount, "Not enough ETH sent");
        require(m.sell, "Not sell" );
        uint256 total = totalSupply();
        for(uint256 i= 0; i< _mintAmount; i++){
            tokenMetadataInfoPath[total+i] = m.path;  
            m.metadataInfoTokens.push(total+i);
            m.size--;
        }
        _safeMint(_to, _mintAmount);
        
    }

    function privateMint(address _to, string memory _id, uint256 _mintAmount) external payable callerIsUser {
        MetadataInfo storage m = metadataInfoList[_id];
        PrivateMetadataInfo storage pm = privateMetadataInfoList[_id];
        require(bytes(m.id).length > 0, "MetadataInfo not exist" );
        require(!pm.pausePrivateSale, "Pause privateSale" );
        if(msg.sender != owner() && !whitelist[msg.sender]){
            require(pm.allowlist[_to] > 0, "Not enough quantity");  
            require(msg.value >= pm.privateSalePrice * _mintAmount, "Not enough ETH sent");
            pm.allowlist[_to]-=_mintAmount;
        }
        if(pm.deductedAmount){
            require(m.size - pm.allowlist[_to] + _mintAmount >= 0, "not eligible for allowlist mint");  
            m.size-=_mintAmount;
        }
        uint256 total = totalSupply();
        for(uint256 i= 0; i< _mintAmount; i++){
            tokenMetadataInfoPath[total+i] = m.path;  
            m.metadataInfoTokens.push(total+i);
        }
         _safeMint(_to, _mintAmount);
        
    }

    function chainMetadataInfo(string memory _id, string memory _path, uint256 _size, uint256 _price, bool _sell) external onlyOwner {
        require(bytes(_id).length > 0);
        MetadataInfo storage m = metadataInfoList[_id];
        m.id = _id;
        m.path = _path;
        m.size = _size;
        m.price = _price;
        m.sell = _sell;
    }

    function chainPrivateMetadataInfo(string memory _id, uint256 _privateSalePrice, bool _deductedAmount, bool _pausePrivateSale) external onlyOwner {
        require(bytes(_id).length > 0);
        PrivateMetadataInfo storage pm = privateMetadataInfoList[_id];
        pm.privateSalePrice = _privateSalePrice;
        pm.deductedAmount = _deductedAmount;
        pm.pausePrivateSale = _pausePrivateSale;
    }
  
    function seedAllowlist(string memory _id, address[] memory _allowlist, uint256[] memory numSlots)
        external
        onlyOwner
    {
        require(
        _allowlist.length == numSlots.length,
        "addresses does not match numSlots length"
        );
        PrivateMetadataInfo storage pm = privateMetadataInfoList[_id];
        for (uint256 i = 0; i < _allowlist.length; i++) {
         pm.allowlist[_allowlist[i]] = numSlots[i];
        }
    }

    function seedWitelist(address[] memory _whitelist, bool[] memory boolSlots)
        external
        onlyOwner
    {
        require(
        _whitelist.length == boolSlots.length,
        "addresses does not match boolSlots length"
        );
        for (uint256 i = 0; i < _whitelist.length; i++) {
         whitelist[_whitelist[i]] = boolSlots[i];
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        require(bytes(tokenMetadataInfoPath[tokenId]).length > 0, "MetadataInfoToken not exist" );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenMetadataInfoPath[tokenId]
                    )
                )
                : "";
    }


    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setTokenMetadataInfoPath(string memory _id, string memory _path) external onlyOwner {
        MetadataInfo storage m = metadataInfoList[_id];
        require(bytes(m.id).length > 0, "MetadataInfo not exist" );
        m.path = _path;
        for(uint256 i= 0; i< m.metadataInfoTokens.length; i++){
            tokenMetadataInfoPath[m.metadataInfoTokens[i]] =_path;  
        }
    }

    function getAllowlist(string memory _id, address _address) external view returns(uint256){
       return privateMetadataInfoList[_id].allowlist[_address];
    }

    function getMetadataInfoTokens(string memory _id) external view returns(uint256[] memory) {
        MetadataInfo storage m = metadataInfoList[_id];
        require(bytes(m.id).length > 0, "MetadataInfo not exist" );
        return m.metadataInfoTokens;
    }
    
    function withdraw() public payable onlyOwner nonReentrant {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success);
    }

    /**
    @notice Sets the contract-wide royalty info.
     */
    function setRoyaltyInfo(address receiver, uint96 feeBasisPoints)
        external
        onlyOwner
    {
        _setDefaultRoyalty(receiver, feeBasisPoints);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}
