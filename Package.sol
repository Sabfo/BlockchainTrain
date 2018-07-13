pragma solidity
^0.4.24;

contract OtherContract {
    function onERC721Received(address, address, uint256) public;
}

contract Package {

    struct Parameters {
        uint256 length;
        uint256 width;
        uint256 height;
        uint256 weight;
        address to;
    }

    struct Metadata {
        uint256 tokenId;
        string name;
        string status;
    }

    struct Element {
        Parameters params;
        Metadata meta;
    }

    event Status(string);
    event GetTokenId(uint256);
    event transfer(address, address, uint256);

    Element[] public elements;
    mapping (uint256 => address) public ownerOf;
    uint256 idGenerator = 0;
    address postOfficeAddress;
    address devoloper;

    function Package() public {
        devoloper = msg.sender;
        postOfficeAddress = devoloper;
    }

    function Transfer(address _to, uint256 _tokenId) public{
        require(ownerOf[_tokenId] == msg.sender);
        ownerOf[_tokenId] = _to;
        emit transfer(msg.sender, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) public {
        require(ownerOf[_tokenId] == msg.sender);
        require(ownerOf[_tokenId] != _to);
        require(idGenerator >= _tokenId);
        require(isContract(_to));
        OtherContract other = OtherContract(_to);
        other.onERC721Received(_from, _to, _tokenId);
        ownerOf[_tokenId] = _to;

        emit transfer(msg.sender, _to, _tokenId);
    }

    function setPostOfficeAddress (address _PostOfficeAddress) public {
        require(msg.sender == devoloper);
        postOfficeAddress = _PostOfficeAddress;
    }

    function createPackage(uint256 _length,
    uint256 _width, uint256 _height, uint256 _weight,
    string _name, address _to) public {
        ownerOf[idGenerator] = msg.sender;
        Element memory element;
        element.meta = Metadata(idGenerator, _name, "starting");
        element.params = Parameters(_length, _width, _height, _weight, _to);
        elements.push(element);
        emit GetTokenId(idGenerator);
        idGenerator++;
    }

    function getStatus(uint256 _tokenId) public {
        emit Status(elements[_tokenId].meta.status);
    }

    function changeStatus(string _status, uint256 _tokenId) public {
        require(postOfficeAddress == msg.sender);
        elements[_tokenId].meta.status = _status;
    }

    function isContract(address addr) internal returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}
