import Foundation
import Testing
@testable import DSStore

@Suite("BuddyAllocator")
struct BuddyAllocatorTests {
	@Test("Decode block address")
	func decodeBlockAddress() {
		// Address with offset 0x1000 and size 2^12 = 4096
		let address: UInt32 = 0x100C // 0x1000 | 12
		let (offset, size) = BuddyAllocator.decodeAddress(address)

		#expect(offset == 0x1000)
		#expect(size == 4096)
	}

	@Test("Decode small block address")
	func decodeSmallBlockAddress() {
		// Address with offset 0x20 and size 2^5 = 32 (minimum)
		let address: UInt32 = 0x25 // 0x20 | 5
		let (offset, size) = BuddyAllocator.decodeAddress(address)

		#expect(offset == 0x20)
		#expect(size == 32)
	}

	@Test("Encode block address")
	func encodeBlockAddress() {
		let address = BuddyAllocator.encodeAddress(offset: 0x1000, sizePower: 12)
		#expect(address == 0x100C)
	}

	@Test("Encode and decode roundtrip")
	func encodeDecodeRoundtrip() {
		let originalOffset: UInt32 = 0x2000
		let originalSizePower: UInt32 = 10 // 2^10 = 1024

		let address = BuddyAllocator.encodeAddress(offset: originalOffset, sizePower: originalSizePower)
		let (decodedOffset, decodedSize) = BuddyAllocator.decodeAddress(address)

		#expect(decodedOffset == originalOffset)
		#expect(decodedSize == 1024)
	}

	@Test("Block offset calculation")
	func blockOffsetCalculation() throws {
		var allocator = BuddyAllocator()
		allocator.blockAddresses = [
			BuddyAllocator.encodeAddress(offset: 0x1000, sizePower: 12), // Block 0
			BuddyAllocator.encodeAddress(offset: 0x20, sizePower: 5), // Block 1
			BuddyAllocator.encodeAddress(offset: 0x100, sizePower: 8) // Block 2
		]

		let (offset0, size0) = try allocator.blockOffset(for: 0)
		#expect(offset0 == 0x1004) // +4 for file alignment prefix
		#expect(size0 == 4096)

		let (offset1, size1) = try allocator.blockOffset(for: 1)
		#expect(offset1 == 0x24)
		#expect(size1 == 32)

		let (offset2, size2) = try allocator.blockOffset(for: 2)
		#expect(offset2 == 0x104)
		#expect(size2 == 256)
	}

	@Test("Invalid block number throws")
	func invalidBlockNumberThrows() {
		var allocator = BuddyAllocator()
		allocator.blockAddresses = [0x1000]

		#expect(throws: BuddyAllocator.Error.self) {
			_ = try allocator.blockOffset(for: 5)
		}
	}

	@Test("Zero block address throws")
	func zeroBlockAddressThrows() {
		var allocator = BuddyAllocator()
		allocator.blockAddresses = [0]

		#expect(throws: BuddyAllocator.Error.self) {
			_ = try allocator.blockOffset(for: 0)
		}
	}

	@Test("Block address with invalid size bits throws")
	func invalidSizeBitsThrows() {
		var allocator = BuddyAllocator()
		allocator.blockAddresses = [0x24] // Size bits = 4 (invalid)

		#expect(throws: BuddyAllocator.Error.self) {
			_ = try allocator.blockOffset(for: 0)
		}
	}
}
