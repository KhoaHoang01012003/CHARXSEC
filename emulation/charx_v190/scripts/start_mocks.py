#!/usr/bin/env python3
import argparse
import asyncio
import base64
import hashlib
import json
import os
import socket
import struct
from datetime import datetime, timezone


PROVENANCE = {
    "source_type": "manual_test_stub",
    "evidence_tier": "Tier 4",
    "confidence": "low",
    "behavior_claim_allowed": False,
}


def ts():
    return datetime.now(timezone.utc).isoformat()


class JsonlLogger:
    def __init__(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        self.path = path

    def write(self, event, **kwargs):
        row = {"ts": ts(), "event": event, **PROVENANCE, **kwargs}
        with open(self.path, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, sort_keys=True) + "\n")


async def ocpp_ws_server(host, port, logger):
    async def handle(reader, writer):
        peer = writer.get_extra_info("peername")
        try:
            request = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), timeout=10)
            headers = request.decode("iso-8859-1", "replace").split("\r\n")
            key = ""
            for line in headers:
                if line.lower().startswith("sec-websocket-key:"):
                    key = line.split(":", 1)[1].strip()
            logger.write("ocpp_websocket_handshake", peer=str(peer), request_head=headers[:20])
            if not key:
                writer.write(b"HTTP/1.1 400 Bad Request\r\n\r\n")
                await writer.drain()
                return
            accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
            response = (
                "HTTP/1.1 101 Switching Protocols\r\n"
                "Upgrade: websocket\r\n"
                "Connection: Upgrade\r\n"
                f"Sec-WebSocket-Accept: {accept}\r\n"
                "Sec-WebSocket-Protocol: ocpp1.6\r\n"
                "\r\n"
            )
            writer.write(response.encode())
            await writer.drain()
            while True:
                header = await reader.read(2)
                if not header:
                    break
                b1, b2 = header
                opcode = b1 & 0x0F
                masked = bool(b2 & 0x80)
                length = b2 & 0x7F
                if length == 126:
                    length = struct.unpack("!H", await reader.readexactly(2))[0]
                elif length == 127:
                    length = struct.unpack("!Q", await reader.readexactly(8))[0]
                mask = await reader.readexactly(4) if masked else b""
                payload = await reader.readexactly(length)
                if masked:
                    payload = bytes(byte ^ mask[i % 4] for i, byte in enumerate(payload))
                logger.write("ocpp_websocket_frame", peer=str(peer), opcode=opcode, payload=payload.decode("utf-8", "replace")[:4000])
                if opcode == 8:
                    break
        except Exception as exc:
            logger.write("ocpp_websocket_error", peer=str(peer), error=repr(exc))
        finally:
            writer.close()
            await writer.wait_closed()

    return await asyncio.start_server(handle, host, port)


async def tcp_logger(name, host, port, logger):
    async def handle(reader, writer):
        peer = writer.get_extra_info("peername")
        data = await reader.read(4096)
        logger.write(f"{name}_tcp_connection", peer=str(peer), bytes=len(data), hex=data.hex()[:4096])
        writer.close()
        await writer.wait_closed()
    return await asyncio.start_server(handle, host, port)


async def modbus_server(host, port, logger):
    async def handle(reader, writer):
        peer = writer.get_extra_info("peername")
        try:
            while True:
                mbap = await reader.readexactly(7)
                tid, pid, length, unit = struct.unpack("!HHHB", mbap)
                pdu = await reader.readexactly(length - 1)
                fn = pdu[0] if pdu else 0
                logger.write("modbus_request", peer=str(peer), transaction_id=tid, protocol_id=pid, unit=unit, function=fn, pdu=pdu.hex())
                if fn in (3, 4) and len(pdu) >= 5:
                    _, start, count = struct.unpack("!BHH", pdu[:5])
                    count = min(count, 16)
                    payload = bytes([fn, count * 2]) + (b"\x00\x00" * count)
                    response = struct.pack("!HHHB", tid, 0, len(payload) + 1, unit) + payload
                    writer.write(response)
                    await writer.drain()
                    logger.write("modbus_response", peer=str(peer), transaction_id=tid, start=start, count=count, note="synthetic zero registers")
                else:
                    payload = bytes([fn | 0x80, 1])
                    writer.write(struct.pack("!HHHB", tid, 0, len(payload) + 1, unit) + payload)
                    await writer.drain()
        except asyncio.IncompleteReadError:
            return
        except Exception as exc:
            logger.write("modbus_error", peer=str(peer), error=repr(exc))
        finally:
            writer.close()
            await writer.wait_closed()
    return await asyncio.start_server(handle, host, port)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--ocpp-port", type=int, default=9000)
    parser.add_argument("--modbus-port", type=int, default=1502)
    parser.add_argument("--mqtt-remote-port", type=int, default=1884)
    parser.add_argument("--openvpn-port", type=int, default=1194)
    args = parser.parse_args()

    transcript_dir = os.path.join(args.evidence_dir, "mock_transcripts")
    logger = JsonlLogger(os.path.join(transcript_dir, "mocks.jsonl"))
    servers = [
        await ocpp_ws_server(args.host, args.ocpp_port, logger),
        await modbus_server(args.host, args.modbus_port, logger),
        await tcp_logger("mqtt_remote", args.host, args.mqtt_remote_port, logger),
        await tcp_logger("openvpn_test_peer", args.host, args.openvpn_port, logger),
    ]
    logger.write("mocks_started", host=args.host, ports={
        "ocpp_ws": args.ocpp_port,
        "modbus": args.modbus_port,
        "mqtt_remote": args.mqtt_remote_port,
        "openvpn_test_peer": args.openvpn_port,
    })
    await asyncio.gather(*(server.serve_forever() for server in servers))


if __name__ == "__main__":
    asyncio.run(main())

