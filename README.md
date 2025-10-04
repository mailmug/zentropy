# Zentropy
A high-performance, lightweight key-value store server written in Zig, supporting both TCP and Unix socket interfaces.

## Features
- **Dual Interface:** Simultaneous TCP and Unix socket support

- **High Performance:** Built with Zig for maximum efficiency

- **Simple Protocol:** Easy-to-use text-based protocol

- **Thread-Safe:** Concurrent client handling

- **Memory Safe:** No garbage collector, manual memory management

## PERFORMANCE SUMMARY

Data Size: 100 records
----------------------------------------
WRITE        -> Redis: 0.0075s | Zentropy: 0.0046s | Zentropy is 1.61x faster
READ         -> Redis: 0.0000s | Zentropy: 0.0000s | Redis is 1.19x faster
KEY_VALUE    -> Redis: 0.0078s | Zentropy: 0.0021s | Zentropy is 3.79x faster

Data Size: 1000 records
----------------------------------------
WRITE        -> Redis: 0.0285s | Zentropy: 0.0148s | Zentropy is 1.92x faster
READ         -> Redis: 0.0000s | Zentropy: 0.0000s | Zentropy is 1.23x faster
KEY_VALUE    -> Redis: 0.0033s | Zentropy: 0.0023s | Zentropy is 1.46x faster

Data Size: 5000 records
----------------------------------------
WRITE        -> Redis: 0.0808s | Zentropy: 0.0731s | Zentropy is 1.10x faster
READ         -> Redis: 0.0000s | Zentropy: 0.0000s | Zentropy is 2.73x faster
KEY_VALUE    -> Redis: 0.0032s | Zentropy: 0.0022s | Zentropy is 1.49x faster

Data Size: 20000 records
----------------------------------------
WRITE        -> Redis: 0.3173s | Zentropy: 0.2894s | Zentropy is 1.10x faster
READ         -> Redis: 0.0001s | Zentropy: 0.0000s | Zentropy is 8.76x faster
KEY_VALUE    -> Redis: 0.0098s | Zentropy: 0.0020s | Zentropy is 4.82x faster


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


## Using unix socket
```bash
echo "PING" | nc -U /tmp/zentropy.sock
# -> +PONG
```

# Zentropy
