// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'erc721a/contracts/ERC721A.sol'; //ERC721A
import '@openzeppelin/contracts/access/Ownable.sol'; //gives Ownable Functionality. authorization control.
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol'; //MerkleProof
import '@openzeppelin/contracts/security/ReentrancyGuard.sol'; // Security module to prevent reentrancy attacks. 
import "@openzeppelin/contracts/utils/Strings.sol"; //imports strings library

contract NFT6 is ERC721A, Ownable, ReentrancyGuard {

//allows you to use the toString function from the Strings library on uint256 variables. 
    using Strings for uint256;
//bytes32 uses less gas because it fits in a single word of EVM. since merkleRoot is 32 bytes.
    bytes32 public merkleRoot;
//maps address to whitelist claimed or not.
    mapping(address => bool) public whitelistClaimed;

    string public uriPrefix = '';
    string public uriSuffix = '.json';
    //URI for hidden metadata before metadata is revealed. used in tokenURI funct.    
    string public hiddenMetadataUri;

  
    uint256 public cost; //cost for minting single token. in wei.
    uint256 public maxSupply; //total no of tokens that can exist in a contract/collection.
    uint256 public maxMintAmountPerTx; //max no. of tokens that can be minted in a single transaction.
 
    bool public paused = true; //pauses minting new tokens for nonwhitelist addresses.
    bool public whitelistMintEnabled = false; //allows participants on a pre-approved whitelist to mint tokens.
    bool public revealed = false; //variable is a flag that indicates whether the metadata has been revealed.
    
    // Mapping to store ownership details for each token ID
    mapping(uint256 => TokenOwnership) public tokenOwnerships;

//_tokenName and _tokenSymbol are used by parent contract ERC721A.
    constructor(
    string memory _tokenName, //memory keyword is necessary for each string parameter.
    string memory _tokenSymbol,
    uint256 _cost,
    uint256 _maxSupply,
    uint256 _maxMintAmountPerTx,
    string memory _hiddenMetadataUri,
    address initialOwner
  ) ERC721A(_tokenName, _tokenSymbol) Ownable(initialOwner) {
    cost = _cost; 
    maxSupply = _maxSupply;
    maxMintAmountPerTx = _maxMintAmountPerTx;
    setHiddenMetadataUri(_hiddenMetadataUri);
  }
    modifier mintCompliance(uint256 _mintAmount) {  //_mintAmount is no. of nft to be minted.
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount!');
    require(totalSupply() + _mintAmount <= maxSupply, 'Max supply exceeded!');
    _; //placeholder for the rest of the function.
  }
 
    modifier mintPriceCompliance(uint256 _mintAmount) {
    require(msg.value >= cost * _mintAmount, 'Insufficient funds!'); //msg.value is value sent with the transaction.
    _;
  }

  // Function to set ownership details for a specific token ID
  function setOwnership(uint256 tokenId, address ownerAddress, bool isBurned) external onlyOwner {
    tokenOwnerships[tokenId] = TokenOwnership({
      addr: ownerAddress,
      startTimestamp: uint64(block.timestamp),
      burned: isBurned, 
      extraData: 0
    });
  }

  //calldata data cannot be modified by the function.
  function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    // Verify whitelist requirements
    require(whitelistMintEnabled, 'The whitelist sale is not enabled!');
    require(!whitelistClaimed[_msgSender()], 'Address already claimed!'); //Whitelist addresses not allowed to use the function more than once.
    bytes32 leaf = keccak256(abi.encodePacked(_msgSender())); //sha-3
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof!'); 

    whitelistClaimed[_msgSender()] = true;
    _safeMint(_msgSender(), _mintAmount);
  }
  //ordinary mint function.
  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    require(!paused, 'The contract is paused!');
 
    _safeMint(_msgSender(), _mintAmount);
  }
  //function to mint nft for a given address.
  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _safeMint(_receiver, _mintAmount);
  }
  
  function walletOfOwner(address _owner) public view returns (uint256[] memory) {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount); //intialized array.
    uint256 currentTokenId = _startTokenId(); //initial address.
    uint256 ownedTokenIndex = 0;
    address latestOwnerAddress;
 
    while (ownedTokenIndex < ownerTokenCount && currentTokenId <= maxSupply) {
      TokenOwnership memory ownership = tokenOwnerships[currentTokenId];
 
      if (!ownership.burned && ownership.addr != address(0)) {
        latestOwnerAddress = ownership.addr;
      }
 
      if (latestOwnerAddress == _owner) {
        ownedTokenIds[ownedTokenIndex] = currentTokenId;
        ownedTokenIndex++;
      }
 
      currentTokenId++;
    }
 
    return ownedTokenIds;
  }
  //to start the tokenids from 1.
  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }
  //return tokenuri associated with the tokenid
  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');
 
    if (revealed == false) {
      return hiddenMetadataUri;
    }
    string memory currentBaseURI = _baseURI();
    //ternary expression--- varaible = Condition ? true_expression : false_expression
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix)) 
        : '';
        //Concatenates the provided values into a byte array without padding.
  }
  //to toggle revealed state.
  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }
  //to update cost to mint a single token
  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }
  //to update maxmintamountpertx.
  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setWhitelistMintEnabled(bool _state) public onlyOwner {
    whitelistMintEnabled = _state;
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }

}
