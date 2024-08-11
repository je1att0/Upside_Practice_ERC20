# 문제 3: ERC20 Pause / Permit 구현하기

## 3.1. 전역 변수 및 함수 개요

```solidity
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
```

### 전역 변수

- `initialSupply` : 최초 생성할 토큰 개수. 이 코드에서는 10000 이더로 설정되어 있다. `mint` 함수를 통해 토큰이 발행되며, 최초에는 이 값이 토큰의 총 공급량이 된다.
- `totalSupply` : 현재까지 공급된 전체 토큰 개수. `mint` 함수를 호출할 때마다 이 값이 증가한다.
- `name` : 토큰의 이름. 이 컨트랙트에서는 생성자에서 전달된 값을 사용하며,  테스트 코드에서는 'UPSIDE'이다.
- `symbol` : 토큰의 심볼. 이 컨트랙트에서는 생성자에서 전달된 값을 사용하며, 테스트 코드에서는 'UP'이다.
- `balances` : 각 계정이 보유한 토큰의 잔액을 나타내는 `mapping` 타입 변수이다. 주소를 키로 하고, 해당 주소의 토큰 잔액을 값으로 가진다.
- `allowance` : 특정 계정이 다른 계정에게 전송할 수 있도록 허락된 토큰 양을 나타내는 `mapping` 타입 변수이다. 두 번째 `mapping`을 사용하여 `owner`와 `spender` 사이의 허용된 금액을 관리한다.
- `owner` : 컨트랙트를 생성한 계정으로, 컨트랙트의 관리자인 역할을 한다. 이 계정만이 `pause` 기능을 통해 토큰 전송을 중단하거나 재개할 수 있다.
- `paused` : 토큰 전송이 가능한지 여부를 나타내는 `bool` 타입 변수이다. `true`일 경우 토큰 전송이 불가능하며, `false`일 경우 전송이 가능하다.
- `nonces` : 각 계정의 트랜잭션 카운터로, 이중 지불을 방지하기 위해 사용된다. 트랜잭션이 실행될 때마다 계정의 `nonce` 값이 1씩 증가한다.
- `TYPE_HASH` : EIP-712 표준에서 사용되는 서명 구조의 해시값이다.

### 함수 개요

- `constructor(string memory name_, string memory symbol_)` : 컨트랙트 생성자 함수로, 토큰 이름과 심볼을 설정하고, `initialSupply`만큼의 토큰을 생성자 호출자에게 발행한다. 또한, 토큰 이름의 해시값을 저장하고, 현재 체인 ID를 저장한다.
- `onlyOwner` : 함수가 오직 컨트랙트 소유자만 호출할 수 있도록 제한하는 `modifier`이다.
- `notPaused` : 함수가 컨트랙트가 일시 정지되지 않았을 때만 실행될 수 있도록 제한하는 `modifier`이다.
- `mint(address _account, uint256 _amount)` : 특정 계정에 `_amount`만큼의 토큰을 발행한다.
- `transfer(address _to, uint256 _amount)` : 메시지 전송자의 계정에서 `_to` 계정으로 `_amount`만큼의 토큰을 전송한다.
- `pause()` : 컨트랙트 소유자가 호출할 수 있는 함수로, 컨트랙트를 일시 정지하여 토큰 전송을 중단한다.
- `approve(address _spender, uint256 _amount)` : 특정 주소 `_spender`가 `_amount`만큼의 토큰을 소유자의 계정에서 전송할 수 있도록 허락한다.
- `transferFrom(address _from, address _to, uint256 _amount)` : 승인된 `_spender`가 `_from` 계정에서 `_to` 계정으로 `_amount`만큼의 토큰을 전송한다.
- `_buildDomainSeparator()` : EIP-712 표준에서 사용되는 domain separator 를 생성한다.
- `_toTypedDataHash(bytes32 _structHash)` : EIP-712에서 사용되는 데이터 해시를 생성한다. domain seperator 와 struct hash를 결합하여 최종 해시값을 반환한다.
- `permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)` : 서명 기반의 토큰 승인 메서드이다. `_owner`가 `_spender`에게 `_value`만큼의 토큰을 송금할 수 있도록 서명된 메시지를 사용하여 허락한다.

## 3.2. `mint(address _account, uint256 _amount)`

- 특정 계정(`_account`)에 `_amount`만큼의 토큰을 발행한다.
- `_account` 주소가 유효한지 (`0` 주소가 아닌지) 확인하기 위해 `require`를 사용한다.
- `_amount`만큼의 토큰을 총 공급량(`totalSupply`)에 더한다.
- `_account`의 잔액(`balances[_account]`)에 `_amount`를 추가한다.

## 3.3. `transfer(address _to, uint256 _amount)`

- 메시지 전송자(`msg.sender`)의 계정에서 `_to` 계정으로 `_amount`만큼의 토큰을 전송한다.
- `_to` 주소가 유효한지 (`0` 주소가 아닌지) 확인하기 위해 `require`를 사용한다.
- 메시지 전송자의 잔액이 `_amount` 이상인지 확인한다.
- 메시지 전송자의 잔액에서 `_amount`만큼을 차감한다.
- `_to`의 잔액에 `_amount`만큼을 추가한다.
- 전송이 성공하면 `true`를 반환한다.
- 컨트랙트가 일시 정지되지 않았을 때(`notPaused` modifier가 적용됨)만 실행 가능하다.

## 3.4. `pause()`

- 컨트랙트 소유자가 호출할 수 있으며, 컨트랙트를 일시 정지 상태로 전환하여 토큰 전송을 막는다.
- `paused` 변수를 `true`로 설정하여 컨트랙트를 일시 정지한다.
- 오직 컨트랙트 소유자(`onlyOwner` modifier가 적용됨)만 호출할 수 있다.

## 3.5 `approve(address _spender, uint256 _amount)`

- 특정 주소(`_spender`)가 메시지 전송자의 계정에서 `_amount`만큼의 토큰을 전송할 수 있도록 허락한다.
- `_spender` 주소가 유효한지 (`0` 주소가 아닌지) 확인하기 위해 `require`를 사용한다.
- `allowance` 매핑을 업데이트하여 `_spender`가 `_amount`만큼의 토큰을 전송할 수 있도록 설정한다.
- 설정이 완료되면 `true`를 반환한다.

## 3.6. `transferFrom(address _from, address _to, uint256 _amount)`

- `_from` 계정에서 `_to` 계정으로 `_amount`만큼의 토큰을 전송한다. 이 함수는 `approve`를 통해 사전 승인된 토큰만 전송할 수 있다.
- `_from` 주소와 `_to` 주소가 유효한지 확인하기 위해 `require`를 사용한다.
- `_from` 계정의 잔액이 `_amount` 이상인지 확인한다.
- 메시지 전송자(`msg.sender`)가 `_from`으로부터 `_amount`만큼의 토큰을 전송할 수 있는 허락을 받았는지(`allowance`) 확인한다.
- `_from`의 잔액에서 `_amount`만큼을 차감한다.
- `_to`의 잔액에 `_amount`만큼을 추가한다.
- `allowance`를 감소시켜 사용된 할당량을 반영한다.
- 전송이 성공하면 `true`를 반환한다.
- 컨트랙트가 일시 정지되지 않았을 때(`notPaused` modifier가 적용됨)만 실행 가능하다.

## 3.7. `_buildDomainSeparator()`

- EIP-712 표준에서 사용되는 도메인 구분자를 생성한다. 이 구분자는 서명 데이터의 도메인별 구분을 위해 사용된다.
- 도메인 구분자를 생성하기 위해 토큰 이름의 해시, 버전, 체인 ID 및 컨트랙트 주소를 해싱한 결과를 반환한다.
- 도메인 구분자 해시(`bytes32`)를 반환한다.

## 3.8. `_toTypedDataHash(bytes32 _structHash)`

- EIP-712 표준에서 사용되는 데이터 해시를 생성한다. 도메인 구분자와 구조체 해시를 결합하여 최종 해시값을 반환한다.
- 도메인 구분자와 함께 `_structHash`를 결합하여 최종 데이터 해시값을 생성한다.
- 최종 데이터 해시값(`bytes32`)을 반환한다.

## 3.9. `permit(address _owner, address _spender, uint256 _value, uint256 _deadline, uint8 _v, bytes32 _r, bytes32 _s)`

- EIP-2612 표준에 따른 서명 기반의 토큰 승인 메서드. `_owner`가 `_spender`에게 `_value`만큼의 토큰을 송금할 수 있도록 서명된 메시지를 사용하여 허락한다.
- `_spender` 주소가 유효한지 (`0` 주소가 아닌지) 확인하기 위해 `require`를 사용한다.
- 현재 시간(`block.timestamp`)이 `_deadline`보다 작거나 같은지 확인하여 서명의 유효성을 검증한다.
- `permit` 함수 호출 시 전달된 정보로 구조체 해시를 생성한다.
- `_toTypedDataHash` 함수를 호출하여 최종 데이터 해시값을 얻는다.
- `ecrecover` 함수를 사용하여 서명자를 복구하고, 복구된 서명자가 `_owner`와 일치하는지 확인한다. 이 값이 일치해야만 `allowance` 매핑을 업데이트할 수 있으며, 일치하지 않으면 `INAVLID_SIGNER` 에러를 발생시킨다.
- `allowance` 매핑을 업데이트하여 `_spender`가 `_value`만큼의 토큰을 전송할 수 있도록 설정한다.
- `_owner`의 `nonces` 값을 증가시켜 재사용을 방지한다.
