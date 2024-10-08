// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin-upgrades/contracts/utils/math/MathUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/utils/math/SafeCastUpgradeable.sol";

import "./SlashingLib.sol";

/**
 * @title Library for handling snapshots as part of allocating and slashing.
 * @notice This library is using OpenZeppelin's CheckpointsUpgradeable library (v4.9.0)
 * and removes structs and functions that are unessential.
 * Interfaces and structs are renamed for clarity and usage (timestamps, etc).
 * Some additional functions have also been added for convenience.
 * @dev This library defines the `DefaultWadHistory` struct, for snapshotting values as they change at different points in
 * time, and later looking up past values by block number. See {Votes} as an example.
 *
 * To create a history of snapshots define a variable type `Snapshots.DefaultWadHistory` in your contract, and store a new
 * snapshot for the current transaction block using the {push} function. If there is no history yet, the value is WAD.
 *
 * _Available since v4.5._
 */
library Snapshots {
    struct DefaultWadHistory {
        Snapshot[] _snapshots;
    }

    struct Snapshot {
        uint32 _key;
        uint64 _value;
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into a DefaultWadHistory so that it is stored as the snapshot.
     *
     * Returns previous value and new value.
     */
    function push(DefaultWadHistory storage self, uint32 key, uint64 value) internal returns (uint64, uint64) {
        return _insert(self._snapshots, key, value);
    }

    /**
     * @dev Returns the value in the first (oldest) snapshot with key greater or equal than the search key, or zero if there is none.
     */
    function lowerLookup(DefaultWadHistory storage self, uint32 key) internal view returns (uint64) {
        uint256 len = self._snapshots.length;
        uint256 pos = _lowerBinaryLookup(self._snapshots, key, 0, len);
        return pos == len ? 0 : _unsafeAccess(self._snapshots, pos)._value;
    }

    /**
     * @dev Returns the value in the last (most recent) snapshot with key lower or equal than the search key, or zero if there is none.
     */
    function upperLookup(DefaultWadHistory storage self, uint32 key) internal view returns (uint64) {
        uint256 len = self._snapshots.length;
        uint256 pos = _upperBinaryLookup(self._snapshots, key, 0, len);
        return pos == 0 ? WAD : _unsafeAccess(self._snapshots, pos - 1)._value;
    }

    /**
     * @dev Returns the value in the last (most recent) snapshot with key lower or equal than the search key, or zero if there is none.
     *
     * NOTE: This is a variant of {upperLookup} that is optimised to find "recent" snapshot (snapshots with high keys).
     */
    function upperLookupRecent(DefaultWadHistory storage self, uint32 key) internal view returns (uint64) {
        uint256 len = self._snapshots.length;

        uint256 low = 0;
        uint256 high = len;

        if (len > 5) {
            uint256 mid = len - MathUpgradeable.sqrt(len);
            if (key < _unsafeAccess(self._snapshots, mid)._key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        uint256 pos = _upperBinaryLookup(self._snapshots, key, low, high);

        return pos == 0 ? WAD : _unsafeAccess(self._snapshots, pos - 1)._value;
    }

    /**
     * @dev Returns the value in the most recent snapshot, or zero if there are no snapshots.
     */
    function latest(
        DefaultWadHistory storage self
    ) internal view returns (uint64) {
        uint256 pos = self._snapshots.length;
        return pos == 0 ? WAD : _unsafeAccess(self._snapshots, pos - 1)._value;
    }

    /**
     * @dev Returns whether there is a snapshot in the structure (i.e. it is not empty), and if so the key and value
     * in the most recent snapshot.
     */
    function latestSnapshot(
        DefaultWadHistory storage self
    ) internal view returns (bool exists, uint32 _key, uint64 _value) {
        uint256 pos = self._snapshots.length;
        if (pos == 0) {
            return (false, 0, WAD);
        } else {
            Snapshot memory ckpt = _unsafeAccess(self._snapshots, pos - 1);
            return (true, ckpt._key, ckpt._value);
        }
    }

    /**
     * @dev Returns the number of snapshot.
     */
    function length(
        DefaultWadHistory storage self
    ) internal view returns (uint256) {
        return self._snapshots.length;
    }

    /**
     * @dev Pushes a (`key`, `value`) pair into an ordered list of snapshots, either by inserting a new snapshot,
     * or by updating the last one.
     */
    function _insert(Snapshot[] storage self, uint32 key, uint64 value) private returns (uint64, uint64) {
        uint256 pos = self.length;

        if (pos > 0) {
            // Copying to memory is important here.
            Snapshot memory last = _unsafeAccess(self, pos - 1);

            // Snapshot keys must be non-decreasing.
            require(last._key <= key, "Snapshot: decreasing keys");

            // Update or push new snapshot
            if (last._key == key) {
                _unsafeAccess(self, pos - 1)._value = value;
            } else {
                self.push(Snapshot({_key: key, _value: value}));
            }
            return (last._value, value);
        } else {
            self.push(Snapshot({_key: key, _value: value}));
            return (0, value);
        }
    }

    /**
     * @dev Return the index of the last (most recent) snapshot with key lower or equal than the search key, or `high` if there is none.
     * `low` and `high` define a section where to do the search, with inclusive `low` and exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _upperBinaryLookup(
        Snapshot[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (_unsafeAccess(self, mid)._key > key) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        return high;
    }

    /**
     * @dev Return the index of the first (oldest) snapshot with key is greater or equal than the search key, or `high` if there is none.
     * `low` and `high` define a section where to do the search, with inclusive `low` and exclusive `high`.
     *
     * WARNING: `high` should not be greater than the array's length.
     */
    function _lowerBinaryLookup(
        Snapshot[] storage self,
        uint32 key,
        uint256 low,
        uint256 high
    ) private view returns (uint256) {
        while (low < high) {
            uint256 mid = MathUpgradeable.average(low, high);
            if (_unsafeAccess(self, mid)._key < key) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @dev Access an element of the array without performing bounds check. The position is assumed to be within bounds.
     */
    function _unsafeAccess(Snapshot[] storage self, uint256 pos) private pure returns (Snapshot storage result) {
        assembly {
            mstore(0, self.slot)
            result.slot := add(keccak256(0, 0x20), pos)
        }
    }

    /**
     *
     *                         ADDITIONAL FUNCTIONS FROM EIGEN-LABS
     *
     */

    /**
     * @dev Returns the value in the last (most recent) snapshot with key lower or equal than the search key, or zero if there is none.
     * This function is a linear search for keys that are close to the end of the array.
     */
    function upperLookupLinear(DefaultWadHistory storage self, uint32 key) internal view returns (uint64) {
        uint256 len = self._snapshots.length;
        for (uint256 i = len; i > 0; --i) {
            Snapshot storage current = _unsafeAccess(self._snapshots, i - 1);
            if (current._key <= key) {
                return current._value;
            }
        }
        return 0;
    }
}
