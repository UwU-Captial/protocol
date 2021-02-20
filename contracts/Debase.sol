// SPDX-License-Identifier: MIT
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./lib/SafeMathInt.sol";

contract Debase is ERC20, Initializable {
    using SafeMath for uint256;
    using SafeMathInt for int256;

    event LogRebase(uint256 indexed epoch_, uint256 totalSupply_);

    // Used for authentication
    address public debasePolicy;

    modifier onlyDebasePolicy() {
        require(msg.sender == debasePolicy);
        _;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0));
        require(to != address(this));
        _;
    }

    uint256 private constant DECIMALS = 18;
    uint256 constant MAX_UINT256 = ~uint256(0);
    uint256 constant INITIAL_FRAGMENTS_SUPPLY = 1000000 * 10**DECIMALS;

    // TOTAL_GONS is a multiple of INITIAL_FRAGMENTS_SUPPLY so that gonsPerFragment is an integer.
    // Use the highest value that fits in a uint256 for max granularity.
    uint256 constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    // MAX_SUPPLY = maximum integer < (sqrt(4*TOTAL_GONS + 1) - 1) / 2
    uint256 constant MAX_SUPPLY = ~uint128(0); // (2^128) - 1

    uint256 private _totalSupply;
    uint256 gonsPerFragment;
    mapping(address => uint256) gonsBalance;

    // This is denominated in Fragments, because the gons-fragments conversion might change before
    // it's fully paid.
    mapping(address => mapping(address => uint256)) allowedFragments;

    constructor() public ERC20("Debase", "DEBASE") {}

    struct DropVariables {
        uint256 debaseDaiPoolVal;
        uint256 debaseDaiPoolGons;
        uint256 debaseDaiLpPoolVal;
        uint256 debaseDaiLpPoolGons;
        uint256 airDropperVal;
        uint256 airDropperGons;
        uint256 debasePolicyPoolVal;
        uint256 debasePolicyGons;
    }

    /**
     * @notice Initializes with the policy,Dai,DaiLp pool as parameters. 
               The function then sets the total supply to the initial supply and calculates the gon per fragment. 
               It also sets the value and the gons for both the Dai and DaiLp reward pools.
     * @param debaseDaiPool Address of the Debase Dai pool contract
     * @param debaseDaiTotalRatio_ Ratio of total supply given to Debase Dai Pool
     * @param debaseDaiLpPool Address of the Debase Dai Lp pool contract
     * @param debaseDaiLpTotalRatio_ Ratio of total supply given to Debase Dai Lp Pool
     * @param airDropper Address of the air dropper
     * @param airDropperTotalRatio_ Ratio of total supply given to air dropper
     * @param debasePolicy_ Address of the debase policy
     * @param debasePolicyTotalRatio_ Ratio of total supply given to debase policy
     */
    function initialize(
        address debaseDaiPool,
        uint256 debaseDaiTotalRatio_,
        address debaseDaiLpPool,
        uint256 debaseDaiLpTotalRatio_,
        address airDropper,
        uint256 airDropperTotalRatio_,
        address debasePolicy_,
        uint256 debasePolicyTotalRatio_
    ) external initializer {
        require(
            debaseDaiTotalRatio_
                .add(debaseDaiLpTotalRatio_)
                .add(airDropperTotalRatio_)
                .add(debasePolicyTotalRatio_) == 100
        );
        DropVariables memory instance;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        debasePolicy = debasePolicy_;

        instance.debaseDaiPoolVal = _totalSupply.mul(debaseDaiTotalRatio_).div(
            100
        );
        instance.debaseDaiPoolGons = instance.debaseDaiPoolVal.mul(
            gonsPerFragment
        );

        instance.debaseDaiLpPoolVal = _totalSupply
            .mul(debaseDaiLpTotalRatio_)
            .div(100);
        instance.debaseDaiLpPoolGons = instance.debaseDaiLpPoolVal.mul(
            gonsPerFragment
        );

        instance.airDropperVal = _totalSupply.mul(airDropperTotalRatio_).div(
            100
        );

        instance.airDropperGons = instance.airDropperVal.mul(gonsPerFragment);

        instance.debasePolicyPoolVal = _totalSupply
            .mul(debasePolicyTotalRatio_)
            .div(100);
        instance.debasePolicyGons = instance.debasePolicyPoolVal.mul(
            gonsPerFragment
        );

        gonsBalance[debaseDaiPool] = instance.debaseDaiPoolGons;
        gonsBalance[debaseDaiLpPool] = instance.debaseDaiLpPoolGons;
        gonsBalance[airDropper] = instance.airDropperGons;
        gonsBalance[debasePolicy] = instance.debasePolicyGons;

        emit Transfer(address(0x0), debaseDaiPool, instance.debaseDaiPoolVal);
        emit Transfer(
            address(0x0),
            debaseDaiLpPool,
            instance.debaseDaiLpPoolVal
        );
        emit Transfer(address(0x0), airDropper, instance.airDropperVal);
        emit Transfer(address(0x0), debasePolicy, instance.debasePolicyPoolVal);
    }

    /**
     * @dev Notifies Fragments contract about a new rebase cycle.
     * @param supplyDelta The number of new fragment tokens to add into circulation via expansion.
     * @return The total number of fragments after the supply adjustment.
     */
    function rebase(uint256 epoch, int256 supplyDelta)
        external
        onlyDebasePolicy
        returns (uint256)
    {
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }

        if (supplyDelta < 0) {
            _totalSupply = _totalSupply.sub(uint256(supplyDelta.abs()));
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
        }

        if (_totalSupply > MAX_SUPPLY) {
            _totalSupply = MAX_SUPPLY;
        }

        gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    /**
     * @return The total number of fragments.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @param who The address to query.
     * @return The balance of the specified address.
     */
    function balanceOf(address who) public view override returns (uint256) {
        return gonsBalance[who].div(gonsPerFragment);
    }

    /**
     * @param amount The amount of gons to convert.
     * @return The balance of the specified address.
     */
    function gonsToAmount(uint256 amount) public view returns (uint256) {
        return amount.div(gonsPerFragment);
    }

    /**
     * @dev Transfer tokens to a specified address.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     * @return True on success, false otherwise.
     */
    function transfer(address to, uint256 value)
        public
        override
        validRecipient(to)
        returns (bool)
    {
        uint256 gonValue = value.mul(gonsPerFragment);
        gonsBalance[msg.sender] = gonsBalance[msg.sender].sub(gonValue);
        gonsBalance[to] = gonsBalance[to].add(gonValue);
        emit Transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Function to check the amount of tokens that an owner has allowed to a spender.
     * @param owner_ The address which owns the funds.
     * @param spender The address which will spend the funds.
     * @return The number of tokens still available for the spender.
     */
    function allowance(address owner_, address spender)
        public
        view
        override
        returns (uint256)
    {
        return allowedFragments[owner_][spender];
    }

    /**
     * @dev Transfer tokens from one address to another.
     * @param from The address you want to send tokens from.
     * @param to The address you want to transfer to.
     * @param value The amount of tokens to be transferred.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override validRecipient(to) returns (bool) {
        allowedFragments[from][msg.sender] = allowedFragments[from][msg.sender]
            .sub(value);

        uint256 gonValue = value.mul(gonsPerFragment);
        gonsBalance[from] = gonsBalance[from].sub(gonValue);
        gonsBalance[to] = gonsBalance[to].add(gonValue);
        emit Transfer(from, to, value);

        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of
     * msg.sender. This method is included for ERC20 compatibility.
     * increaseAllowance and decreaseAllowance should be used instead.
     * Changing an allowance with this method brings the risk that someone may transfer both
     * the old and the new allowance - if they are both greater than zero - if a transfer
     * transaction is mined before the later approve() call is mined.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner has allowed to a spender.
     * This method should be used instead of approve() to avoid the double approval vulnerability
     * described above.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        allowedFragments[msg.sender][spender] = allowedFragments[msg.sender][
            spender
        ]
            .add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            allowedFragments[msg.sender][spender]
        );
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner has allowed to a spender.
     *
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            allowedFragments[msg.sender][spender] = 0;
        } else {
            allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            allowedFragments[msg.sender][spender]
        );
        return true;
    }
}
