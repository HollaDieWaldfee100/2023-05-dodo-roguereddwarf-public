/*

    Copyright 2022 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0*/

pragma solidity ^0.8.15;
/* @audit-ok what does this mean?; 
this is activated by default (https://docs.soliditylang.org/en/v0.8.0/080-breaking-changes.html#silent-changes-of-the-semantics) 
pragma has no effect
*/
pragma experimental ABIEncoderV2;

library Types {
    uint16 internal constant REFERRAL_CODE = uint16(0);
}
