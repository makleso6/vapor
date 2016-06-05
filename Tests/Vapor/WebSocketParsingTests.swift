//
//  WebSocketParsingTests.swift
//  Vapor
//
//  Created by Logan Wright on 6/4/16.
//
//

import Foundation
import XCTest
@testable import Vapor

/*
 Examples from: https://tools.ietf.org/html/rfc6455#section-5.7

 o  A single-frame unmasked text message

 *  0x81 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains "Hello")

 o  A single-frame masked text message

 *  0x81 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
 (contains "Hello")

 o  A fragmented unmasked text message

 *  0x01 0x03 0x48 0x65 0x6c (contains "Hel")

 *  0x80 0x02 0x6c 0x6f (contains "lo")


 Fette & Melnikov             Standards Track                   [Page 38]

 RFC 6455                 The WebSocket Protocol            December 2011


 o  Unmasked Ping request and masked Ping response

 *  0x89 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains a body of "Hello",
 but the contents of the body are arbitrary)

 *  0x8a 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
 (contains a body of "Hello", matching the body of the ping)

 o  256 bytes binary message in a single unmasked frame

 *  0x82 0x7E 0x0100 [256 bytes of binary data]

 o  64KiB binary message in a single unmasked frame

 *  0x82 0x7F 0x0000000000010000 [65536 bytes of binary data]
 */
class WebSocketParsingTests: XCTestCase {
    func testSingleFrameUnmaskedTextMessage() throws {
        let input: [Byte] = [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let msg = try MessageParser.parseInput(input)
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 5)
    }

    func testSingleFrameMaskedTextMessage() throws {
        let input: [Byte] = [0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]
        let msg = try MessageParser.parseInput(input)
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == true)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 5)
    }

    /*
     o  A fragmented unmasked text message

     *  0x01 0x03 0x48 0x65 0x6c (contains "Hel")

     *  0x80 0x02 0x6c 0x6f (contains "lo")
     */
    func testFragmentedUnmaskedTextMessageOne() throws {
        let input: [Byte] = [0x01, 0x03, 0x48, 0x65, 0x6c]
        let msg = try MessageParser.parseInput(input)
        XCTAssert(msg.isFragment)
        XCTAssert(msg.isFragmentHeader)
        XCTAssertFalse(msg.isControlFrame)

        let str = try msg.payload.toString()
        XCTAssert(str == "Hel")

        let header = msg.header
        XCTAssert(header.fin == false)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 3)
    }

    func testFragmentedUnmaskedTextMessageTwo() throws {
        let input: [Byte] = [0x80, 0x02, 0x6c, 0x6f]
        let msg = try MessageParser.parseInput(input)
        XCTAssert(msg.isFragment)
        XCTAssert(msg.isFragmentFooter)
        XCTAssertFalse(msg.isControlFrame)

        let str = try msg.payload.toString()
        XCTAssert(str == "lo")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .continuation)
        XCTAssert(header.payloadLength == 2)
    }

    /*

     Unmasked Ping request and masked Ping response
     *  0x89 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains a body of "Hello",
     but the contents of the body are arbitrary)

     *  0x8a 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
     (contains a body of "Hello", matching the body of the ping)
     */
    func testUnmaskedPingRequest() throws {
        let input: [Byte] = [0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let msg = try MessageParser.parseInput(input)
        XCTAssert(msg.isControlFrame)

        // is Hello, but message doesn't matter
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .ping)
        XCTAssert(header.payloadLength == 5)
    }

    func testMaskedPongResponse() throws {
        /*
         Client to Server MUST be masked
         */
        let input: [Byte] = [0x8a, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]
        let msg = try MessageParser.parseInput(input)
        XCTAssert(msg.isControlFrame)

        // is Hello, but message doesn't matter. Must match `ping` payload
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == true)
        XCTAssert(header.opCode == .pong)
        XCTAssert(header.payloadLength == 5)
    }

    /*
     o  256 bytes binary message in a single unmasked frame

     *  0x82 0x7E 0x0100 [256 bytes of binary data]
     */
    func test256BytesBinarySingleUnmaskedFrame() throws {
        // ensure 16 bit lengths
        var randomBinary: [Byte] = []
        (1...256).forEach { _ in
            let random = UInt8.random()
            randomBinary.append(random)
        }

        // 256 as two UInt8
        let twoFiftySix: [Byte] = [0x01, 0x00]
        let headerBytes: [Byte] = [0x82, 0x7E] + twoFiftySix

        let input = headerBytes + randomBinary
        let msg = try MessageParser.parseInput(input)
        XCTAssertFalse(msg.isControlFrame)

        let payload = msg.payload.bytes
        XCTAssert(payload == randomBinary)

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .binary)
        XCTAssert(header.payloadLength == 256)
    }

    /*
     If payload length is > can fit in 2 bytes, will become 8 byte length

     o  64KiB binary message in a single unmasked frame

     *  0x82 0x7F 0x0000000000010000 [65536 bytes of binary data]
     */
    func testSixtyFourKiBSingleUnmaskedFrame() throws {
        // ensure 64 bit lengths
        var randomBinary: [Byte] = []
        (1...65536).forEach { _ in
            let random = UInt8.random()
            randomBinary.append(random)
        }

        // 65536 as 8 UInt8
        let sixFiveFiveThreeSix: [Byte] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]
        let headerBytes: [Byte] = [0x82, 0x7F] + sixFiveFiveThreeSix

        let input = headerBytes + randomBinary
        let msg = try MessageParser.parseInput(input)
        XCTAssertFalse(msg.isControlFrame)

        let payload = msg.payload.bytes
        XCTAssert(payload == randomBinary)

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .binary)
        XCTAssert(header.payloadLength == 65536)
    }

    func testByteArrayToUInt() throws {
        func expect<U: UnsignedInteger>(_ bytes: Byte..., equalTo expected: U) throws {
            let received = try U.init(bytes)
            XCTAssert(expected == received)
        }

        try expect(0x01, 0x00, equalTo: UInt16(0x01_00))
        try expect(0x01, 0x00, equalTo: UInt32(0x01_00))
        try expect(0x01, 0x00, equalTo: UInt64(0x01_00))

        try expect(0x11, 0x10, 0xA0, 0x01, equalTo: UInt32(0x11_10_A0_01))
        try expect(0x11, 0x10, 0xA0, 0x01, equalTo: UInt64(0x11_10_A0_01))

        try expect(0x0A, 0xFF, 0x00, 0x54, 0xAA, 0xAB, 0xDE, 0xCC,
                   equalTo: UInt64(0x0A_FF_00_54_AA_AB_DE_CC))
    }
}

extension UInt8 {
    static func random() -> UInt8 {
        let max = UInt32(UInt8.max)
        let val = arc4random_uniform(max)
        return UInt8(val)
    }
}