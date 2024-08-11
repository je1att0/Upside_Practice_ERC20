// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20 {
    uint256 public initialSupply = 10000 ether;
    uint256 public totalSupply;
    string public name;
    string public symbol;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowance;
    address public owner;
    bool public paused;
    mapping(address => uint256) public nonces;
    bytes32 private constant TYPE_HASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 private  _hashedName;
    bytes32 private  _hashedVersion = keccak256("1");
    uint256 private chainID;


    constructor(string memory name_, string memory symbol_) {
        mint(msg.sender, initialSupply);
        name = name_;
        symbol = symbol_;
        owner = msg.sender;
        _hashedName = keccak256(bytes(name_));
        chainID = block.chainid;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "onlyOwner: Caller is not the owner");
        _;
    }

    modifier notPaused() {
        require(!paused, "notPaused: Contract is paused");
        _;
    }

    function mint(address _account, uint256 _amount) public {
        require(_account != address(0), "mint: Invalid recipient address");
        totalSupply += _amount;
        balances[_account] += _amount;
    }

    function transfer(address _to, uint256 _amount) notPaused public payable returns (bool) {
        require(_to != address(0), "transfer: Invalid sender address");
        require(balances[msg.sender] >= _amount, "transfer: Insufficient balance");
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
        return true;
    }

    function pause() onlyOwner public {
        paused = true;
    }

    function approve(address _spender, uint256 _amount) public returns (bool) {
        require(_spender != address(0), "approve: Invalid sender address");
        allowance[msg.sender][_spender] = _amount;
        return true;

    }

    function transferFrom(address _from, address _to, uint256 _amount) notPaused public returns (bool) {
        require(_from != address(0), "transferFrom: Invalid sender address");
        require(_to != address(0), "transferFrom: Invalid recipient address");
        require(balances[_from] >= _amount, "transferFrom: Insufficient balance");
        require(allowance[msg.sender][_from] >= _amount, "transferFrom: Insufficient allowance");
        balances[_from] -= _amount;
        balances[_to] += _amount;
        allowance[msg.sender][_from] -= _amount;
        return true;
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, chainID, address(this)));
    }

    function _toTypedDataHash(bytes32 _structHash) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _buildDomainSeparator(), _structHash));
    }

    function permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s) public {
        require(_spender != address(0), "permit: Invalid spender address");
        require(block.timestamp <= _deadline, "permit: Signature expired");

        bytes32 structHash = keccak256(abi.encode(TYPE_HASH, _owner, _spender, _value, nonces[_owner], _deadline));
        bytes32 hash = _toTypedDataHash(structHash);
        address signer = ecrecover(hash, _v, _r, _s);
        require(signer == _owner, "INVALID_SIGNER");

        allowance[_owner][_spender] = _value;
        nonces[_owner]++;
    }




}