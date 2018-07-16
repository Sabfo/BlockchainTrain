pragma solidity ^0.4.24;
pragma experimental ABIEncoderV2;

contract HomePackage {

    struct Element {
        uint16 length;
        uint16 width;
        uint16 height;
        uint16 weight;
        //address to;
        uint32 tokenId;
        address owner;
        string name;
        string status;
    }

    event Status(string);
    event GetTokenId(uint32);
    event Transfer(address, address, uint256);
    event SerialData(bytes32[8]);

    mapping(uint32 => Element) public elements;
    //mapping (uint256 => address) public ownerOf;
    uint32 idGenerator = 0;
    bool abilityCreate = true;
    address PermissionsToRecovery;
    address postOfficeAddress;
    address devoloper;

    constructor(bool _flag) public {
        abilityCreate = _flag;
        devoloper = msg.sender;
        postOfficeAddress = devoloper;
    }

    function setPermissionsToRecovery(address perm ) public{
        require(msg.sender == devoloper);
        PermissionsToRecovery = perm;
    }

    function getSerializedData(uint32 _tokenId) public returns (bytes32[8]) {
        bytes32[8] memory data;
        data[0] = bytes32(elements[_tokenId].length);
        data[1] = bytes32(elements[_tokenId].width);
        data[2] = bytes32(elements[_tokenId].height);
        data[3] = bytes32(elements[_tokenId].weight);
        data[4] = bytes32(elements[_tokenId].tokenId);
        data[5] = bytes32(elements[_tokenId].owner);
        data[6] = stringToBytes32(elements[_tokenId].name);
        data[7] = stringToBytes32(elements[_tokenId].status);
        emit SerialData(data);
        //recoveryToken(_tokenId, data);
        return data;
    }

    function recoveryToken(uint32 _tokenId, bytes32[8] _data) public{
        Element memory el;
        el = Element(uint16(_data[0]), uint16(_data[1]), uint16(_data[2]),
        uint16(_data[3]), uint32(_data[4]), address(_data[5]),
        bytes32ToString(_data[6]), bytes32ToString(_data[7]));
        elements[_tokenId] = el;
    }

    function transfer(address _to, uint32 _tokenId) public{
        require(elements[_tokenId].owner == msg.sender);
        elements[_tokenId].owner = _to;
        emit Transfer(msg.sender, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint32 _tokenId) public {
        require(elements[_tokenId].owner == msg.sender);
        require(elements[_tokenId].owner != _to);
        require(idGenerator >= _tokenId);
        if(isContract(_to)){
            HomeBridge bridge = HomeBridge(_to);
            require(bridge.onERC721Received(_from, _to, _tokenId) == bytes4(keccak256("onERC721Received(address,address,uint256,bytes)")));
        }
        elements[_tokenId].owner = _to;

        emit Transfer(msg.sender, _to, _tokenId);
    }

    function setPostOfficeAddress (address _PostOfficeAddress) public {
        require(msg.sender == devoloper);
        postOfficeAddress = _PostOfficeAddress;
    }

    function createPackage(uint16 _length,
    uint16 _width, uint16 _height, uint16 _weight,
    string _name) public {
        //ownerOf[idGenerator] = msg.sender;
        Element memory element;
        element = Element( _length, _width, _height, _weight, idGenerator, msg.sender, _name, "starting");
        elements[idGenerator] = element;
        emit GetTokenId(idGenerator);
        idGenerator++;
    }

    function getStatus(uint32 _tokenId) public returns (string){
        emit Status(elements[_tokenId].status);
        //emit Post(elements[_tokenId]);
        return elements[_tokenId].status;
    }

    function changeStatus(string _status, uint32 _tokenId) public {
        require(postOfficeAddress == msg.sender);
        elements[_tokenId].status = _status;
    }

    function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function bytes32ToString(bytes32 x) public pure returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }
}

contract HomeBridge {
    HomePackage package;
    uint requiredSignatures;
    mapping(address => bool) isValidator;
    mapping(bytes32 => bool) isTokenRecovered;
    mapping(bytes32 => bool) isValidatorAlreadyHandled;
    mapping(bytes32 => uint) amountRecovery;
    event UserRequestForSignature(address, uint32, bytes32[8]);
    event transferCompleted(uint _tokenId);

    constructor(address _tokenAddress, address[] _validators, uint8 _requiredSignatures) public {
        package = HomePackage(_tokenAddress);
        for(uint i = 0; i < _validators.length; i++) {
            isValidator[_validators[i]] = true;
        }
        requiredSignatures = _requiredSignatures;
    }

    function onERC721Received(address _from, address _to, uint32 _tokenId) external returns(bytes4) {
        emit UserRequestForSignature(_to, _tokenId, package.getSerializedData(_tokenId));
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function transferApproved(address _reciever, uint32 _tokenId, bytes32[8] _data, bytes32 _txHash) public {
        require(isValidator[msg.sender]);
        require(!isTokenRecovered[_txHash]);
        bytes32 hash = keccak256(abi.encodePacked(_txHash, msg.sender));
        require(!isValidatorAlreadyHandled[hash]);
        isValidatorAlreadyHandled[hash] = true;
        bytes memory hashData;
        for(uint i=0; i<8; i++){
            hashData = abi.encodePacked(hashData, _data[i]);
        }
        hash = keccak256(abi.encodePacked(_txHash, msg.sender, _tokenId, hashData));
        amountRecovery[hash]++;
        if(amountRecovery[hash] >= requiredSignatures){
            isTokenRecovered[_txHash] = true;
            package.recoveryToken(_tokenId, _data);
            package.transfer(_reciever, _tokenId);
            emit transferCompleted(_tokenId);
        }
    }
}

contract ForeignBridge {
    HomePackage package = new HomePackage(false);
    uint requiredSignatures;
    mapping(address => bool) isValidator;
    mapping(bytes32 => bool) isTokenRecovered;
    mapping(bytes32 => bool) isValidatorAlreadyHandled;
    mapping(bytes32 => uint) amountRecovery;
    event UserRequestForSignature(address, uint32, bytes32[8]);
    event transferCompleted(uint _tokenId);

    constructor(address _tokenAddress, address[] _validators, uint8 _requiredSignatures) public {
        package = HomePackage(_tokenAddress);
        for(uint i = 0; i < _validators.length; i++) {
            isValidator[_validators[i]] = true;
        }
        requiredSignatures = _requiredSignatures;
    }

    function onERC721Received(address _from, address _to, uint32 _tokenId) external returns(bytes4) {
        emit UserRequestForSignature(_to, _tokenId, package.getSerializedData(_tokenId));
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

    function transferApproved(address _reciever, uint32 _tokenId, bytes32[8] _data, bytes32 _txHash) public {
        require(isValidator[msg.sender]);
        require(!isTokenRecovered[_txHash]);
        bytes32 hash = keccak256(abi.encodePacked(_txHash, msg.sender));
        require(!isValidatorAlreadyHandled[hash]);
        isValidatorAlreadyHandled[hash] = true;
        bytes memory hashData;
        for(uint i=0; i<8; i++){
            hashData = abi.encodePacked(hashData, _data[i]);
        }
        hash = keccak256(abi.encodePacked(_txHash, msg.sender, _tokenId, hashData));
        amountRecovery[hash]++;
        if(amountRecovery[hash] >= requiredSignatures){
            isTokenRecovered[_txHash] = true;
            package.recoveryToken(_tokenId, _data);
            package.transfer(_reciever, _tokenId);
            emit transferCompleted(_tokenId);
        }
    }
}
