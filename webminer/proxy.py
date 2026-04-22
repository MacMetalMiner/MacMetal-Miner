#!/usr/bin/env python3
"""
WebSocket-to-Stratum TCP bridge for browser mining.
Bridges ws://localhost:8765 ↔ tcp://98.80.98.17:3333

Also serves the miner web UI on http://localhost:8080.

Usage: python3 proxy.py
"""
import asyncio
import websockets
import json
import http.server
import threading

POOL_HOST = '98.80.98.17'
POOL_PORT = 3333
WS_PORT = 8765
HTTP_PORT = 8080


async def bridge(websocket):
    """Bridge a single WebSocket client to the stratum pool over TCP."""
    peer = websocket.remote_address
    print(f'[WS] Client connected: {peer}')

    try:
        reader, writer = await asyncio.open_connection(POOL_HOST, POOL_PORT)
        print(f'[TCP] Connected to pool {POOL_HOST}:{POOL_PORT} for {peer}')
    except Exception as e:
        print(f'[TCP] Failed to connect to pool: {e}')
        await websocket.close(1011, f'Pool unreachable: {e}')
        return

    async def ws_to_tcp():
        """Forward WebSocket messages → TCP pool."""
        try:
            async for msg in websocket:
                line = msg.strip() + '\n'
                writer.write(line.encode())
                await writer.drain()
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            writer.close()

    async def tcp_to_ws():
        """Forward TCP pool messages → WebSocket."""
        try:
            while True:
                data = await reader.readline()
                if not data:
                    break
                line = data.decode().strip()
                if line:
                    await websocket.send(line)
        except (ConnectionError, websockets.exceptions.ConnectionClosed):
            pass

    try:
        await asyncio.gather(ws_to_tcp(), tcp_to_ws())
    except Exception as e:
        print(f'[Bridge] Error: {e}')
    finally:
        writer.close()
        print(f'[WS] Client disconnected: {peer}')


def start_http_server():
    """Serve the webminer UI files."""
    import os
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    handler = http.server.SimpleHTTPRequestHandler
    handler.extensions_map.update({'.js': 'application/javascript'})
    httpd = http.server.HTTPServer(('0.0.0.0', HTTP_PORT), handler)
    print(f'[HTTP] Serving miner UI on http://localhost:{HTTP_PORT}')
    httpd.serve_forever()


async def main():
    # Start HTTP server in a thread
    threading.Thread(target=start_http_server, daemon=True).start()

    # Start WebSocket server
    print(f'[WS] Stratum bridge on ws://localhost:{WS_PORT}')
    print(f'[WS] Bridging to pool at {POOL_HOST}:{POOL_PORT}')
    print()
    print(f'  Open http://localhost:{HTTP_PORT} to start mining')
    print()

    async with websockets.serve(bridge, '0.0.0.0', WS_PORT):
        await asyncio.Future()  # run forever


if __name__ == '__main__':
    asyncio.run(main())
