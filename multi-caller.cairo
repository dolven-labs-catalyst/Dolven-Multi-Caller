%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_number,
    get_block_timestamp,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_sub,
    uint256_le,
    uint256_lt,
    uint256_check,
    uint256_eq,
    uint256_mul,
    uint256_unsigned_div_rem,
)

from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le

struct UserInfo:
    member amount : felt
    member rewardDebt : felt
    member poolCount : felt
    member isRegistered : felt
end

struct UserPoolInfo:
    member timestamp : felt
    member penaltyEndTimestamp : felt
    member amount : felt
    member owner : felt
end

struct returnDataStruct:
    member userInfo : UserInfo
    member userPoolInfos_len : felt
    member userPoolInfos : UserPoolInfo*
end

@storage_var
func userInfo(user_address : felt) -> (info : UserInfo):
end

@storage_var
func userPoolInfo(user_address : felt, id : felt) -> (pool_info : UserPoolInfo):
end

@storage_var
func stakers(id : felt) -> (address : felt):
end

@storage_var
func stakerCount() -> (count : felt):
end
@external
func stake{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, caller : felt
) -> ():
    let user : UserInfo = userInfo.read(user_address=caller)
    if user.isRegistered == 0:
        let (staker_count) = stakerCount.read()
        stakers.write(id=staker_count, value=caller)
        stakerCount.write(value=staker_count + 1)
        _writeStake(caller, user, amount)
        return ()
    end
    _writeStake(caller, user, amount)
    return ()
end

func _writeStake{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    caller : felt, user : UserInfo, amount : felt
) -> ():
    let info_instance = UserInfo(amount, 10, user.poolCount + 1, 1)
    let pool_instance = UserPoolInfo(2, 3, amount, caller)
    userPoolInfo.write(caller, user.poolCount + 1, pool_instance)
    userInfo.write(caller, info_instance)
    return ()
end

@view
func get_staker_count{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let (count) = stakerCount.read()
    return (count)
end

@view
func check_value{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, count : felt
) -> (info : UserPoolInfo):
    let user : UserPoolInfo = userPoolInfo.read(user_address=address, id=count)
    return (user)
end

@view
func returnAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    userInfo_len : felt, userInfo : UserInfo*, userPoolInfo_len : felt, userPoolInfo : UserPoolInfo*
):
    alloc_locals
    let (__stakerCount) = get_staker_count()

    let (__userInfo_len, __userInfo, __userPoolInfo_len, __userPoolInfo) = recursiveEveryUser(
        index=0
    )
    let len_user = UserInfo.SIZE * __userInfo_len
    return (
        len_user, __userInfo - len_user, __userPoolInfo_len, __userPoolInfo - __userPoolInfo_len
    )
end

func recursiveEveryUser{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    index : felt
) -> (
    userInfo_len : felt, userInfo : UserInfo*, userPoolInfo_len : felt, userPoolInfo : UserPoolInfo*
):
    alloc_locals
    let (_stakerCount) = get_staker_count()
    let _useraddress : felt = stakers.read(index + 1)

    if _useraddress == 0:
        let (found_users : UserInfo*) = alloc()
        let (found_pools : UserPoolInfo*) = alloc()
        return (0, found_users, 0, found_pools)
    end

    let (
        userInfo_len, user_memory_location, userPoolInfo_len, pools_memory_location
    ) = recursiveEveryUser(index=index + 1)

    let (t_userInfo : UserInfo) = userInfo.read(_useraddress)

    let (userData, _userPools) = get_user_info(
        address=_useraddress, user_index=0, stakerCount_=_stakerCount
    )
    let __userInfo : UserInfo* = user_memory_location + UserInfo.SIZE * _stakerCount
    let __userPoolInfo : UserPoolInfo* = pools_memory_location + UserPoolInfo.SIZE * t_userInfo.poolCount * _stakerCount

    assert [user_memory_location] = [__userInfo]
    assert [pools_memory_location] = [__userPoolInfo]

    return (
        userInfo_len + UserInfo.SIZE * _stakerCount,
        __userInfo,
        userPoolInfo_len + UserPoolInfo.SIZE * t_userInfo.poolCount * _stakerCount,
        __userPoolInfo,
    )
end

func get_user_info{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, user_index : felt, stakerCount_ : felt
) -> (user : UserInfo, pools : UserPoolInfo*):
    alloc_locals
    let (user : UserInfo) = userInfo.read(user_address=address)

    let (pool_ids_memoryloc) = _get_user_pools(
        address=address, pool_index=0, userPoolCount=user.poolCount
    )

    let userPools : UserPoolInfo* = pool_ids_memoryloc + user.poolCount * UserPoolInfo.SIZE
    # let _returnData : returnDataStruct = returnDataStruct(user, user.poolCount, userPools)

    return (user, userPools)
end

func _get_user_pools{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, pool_index : felt, userPoolCount : felt
) -> (pool_ids_memoryloc : UserPoolInfo*):
    alloc_locals
    if pool_index == userPoolCount:
        let (found_pools : UserPoolInfo*) = alloc()
        return (found_pools)
    end
    let pool_id : UserPoolInfo = userPoolInfo.read(user_address=address, id=pool_index)

    let (pool_ids_memoryloc) = _get_user_pools(
        address=address, pool_index=pool_index + 1, userPoolCount=userPoolCount
    )
    assert [pool_ids_memoryloc] = pool_id
    return (pool_ids_memoryloc + UserPoolInfo.SIZE)
end
