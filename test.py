import socket
import time
import psutil
import os

HOST = "127.0.0.1"
PORT = 6379     # Redis (6379) or Zentropy (6383)
# PORT = 6383     # Redis (6379) or Zentropy (6383)
REQUESTS = 15000  # Total SET+GET requests (so 2x operations)
print("port : ", PORT)
def send_command(sock, cmd):
    sock.sendall(cmd.encode())
    return sock.recv(4096)

def benchmark(sock, command_fn, label):
    start = time.time()
    for i in range(REQUESTS):
        command_fn(sock, i)
    end = time.time()
    duration = end - start
    print(f"{label} -> {REQUESTS} ops in {duration:.4f} sec ({REQUESTS / duration:.2f} ops/sec)")

def set_command(sock, i):
    key = f"key{i}"
    val = f"value{i}"
    send_command(sock, f"SET {key} {val}\n")

def get_command(sock, i):
    key = f"key{i}"
    send_command(sock, f"GET {key}\n")

def main():
    process = psutil.Process(os.getpid())
    start_mem = process.memory_info().rss / 1024 / 1024

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((HOST, PORT))

    print("Running SET benchmark...")
    benchmark(sock, set_command, "SET")

    print("Running GET benchmark...")
    benchmark(sock, get_command, "GET")

    sock.close()

    end_mem = process.memory_info().rss / 1024 / 1024
    print(f"Memory usage: {end_mem - start_mem:.2f} MB")

if __name__ == "__main__":
    main()
