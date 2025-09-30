# Zentropy
A high-performance, lightweight key-value store server written in Zig, supporting both TCP and Unix socket interfaces.

## Features
- **Dual Interface:** Simultaneous TCP and Unix socket support

- **High Performance:** Built with Zig for maximum efficiency

- **Simple Protocol:** Easy-to-use text-based protocol

- **Thread-Safe:** Concurrent client handling

- **Memory Safe:** No garbage collector, manual memory management


## TCP


# Connect using netcat
```bash
nc 127.0.0.1 6383
PING
# -> +PONG

SET apple red
# -> +OK

GET apple
# -> red
```


## Using socat
```bash
echo "PING" | socat - UNIX-CONNECT:/tmp/zentropy.sock
# -> +PONG
```

