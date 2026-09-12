"""Real loopback host: reject invalid controllers, pause safely, and exit cleanly."""
import json
from pathlib import Path
import socket
import struct
import subprocess
import time
import pytest

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "sim/build/libs/dh-server/dh-server"


@pytest.mark.skipif(not HELPER.is_file(), reason="Build the C++ workspace to exercise the live transport")
def test_local_host_protocol_and_lifecycle():
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.bind(("127.0.0.1", 0))
    client.settimeout(2)
    token = 125963
    process = subprocess.Popen([str(HELPER), "--living-preview", "--client-port",
                                str(client.getsockname()[1]), "--token", str(token)])
    def snapshot():
        packet, address = client.recvfrom(4096)
        magic, echoed_token, sequence, count, stamp = struct.unpack_from("<5I", packet)
        assert magic == 0x32534c44 and echoed_token == token and count == 452
        assert stamp == json.loads((ROOT/"game/living/generated/chapter.json").read_text())["simulation_stamp"]
        return struct.unpack_from(f"<{count}f", packet, 20), address
    def send(address, sequence, buttons=0, key=token, mx=1.0):
        client.sendto(struct.pack("<3I4f2I", 0x31494c44, key, sequence,
                                  mx, 0, 400, 180, buttons, 3), address)
    def until_ack(wanted):
        deadline = time.monotonic()+2
        while time.monotonic()<deadline:
            state, _ = snapshot()
            if state[0] == wanted:
                return state
        raise AssertionError(f"Controller ack {wanted} never arrived")
    try:
        first, address = snapshot()
        assert address[0] == "127.0.0.1" and first[0] == 0
        send(address, 1, key=token+1)
        send(address, 2, mx=float("nan"))
        for _ in range(4):
            rejected, _ = snapshot()
            assert rejected[0] == 0
        send(address, 3)
        moving = until_ack(3)
        assert moving[10] > first[10]
        send(address, 4, buttons=64)
        paused = until_ack(4)
        send(address, 3)  # stale packet cannot resume the world
        for _ in range(4):
            frozen, _ = snapshot()
            assert frozen[0] == 4 and frozen[1] == paused[1]
        send(address, 5, buttons=256)
        assert process.wait(timeout=2) == 0
    finally:
        client.close()
        if process.poll() is None:
            process.kill()
            process.wait(timeout=2)

@pytest.mark.skipif(not HELPER.is_file(), reason="Build native helper first")
@pytest.mark.parametrize('mode, entrance, reason', [('rush','0,0',1), ('lair','1,1',2)])
def test_locked_or_missing_lair_cannot_be_started_or_award_loot(tmp_path, mode, entrance, reason):
    profile = tmp_path/'collection.txt'
    lair = json.loads((ROOT/'genforge/playable/fen_bells.json').read_text())['lairs'][0]['id']
    client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    client.bind(('127.0.0.1',0)); client.settimeout(2)
    process = subprocess.Popen([str(HELPER),'--living-preview','--client-port',str(client.getsockname()[1]),
                                '--token','9981','--mode',mode,'--profile',str(profile),'--lair',lair,
                                '--seed','42','--entrance-chunk',entrance])
    try:
        packet,address=client.recvfrom(4096)
        state=struct.unpack_from('<452f',packet,20)
        assert state[442] == reason and state[1] == 0
        client.sendto(struct.pack('<3I4f2I',0x31494c44,9981,1,0,0,430,187,512|32|1|4|8|16,3),address)
        for _ in range(4):
            state=struct.unpack_from('<452f',client.recvfrom(4096)[0],20)
            assert state[1] == 0 and sum(state[446:450]) == 0
        client.sendto(struct.pack('<3I4f2I',0x31494c44,9981,2,0,0,430,187,256,3),address)
        assert process.wait(timeout=2) == 0
        assert not profile.exists()
    finally:
        client.close()
        if process.poll() is None: process.kill(); process.wait(timeout=2)
