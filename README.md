<p align="center"><a href="#logo"><img src="https://raw.githubusercontent.com/mailmug/zentropy/main/logo.png" width="200" alt="Zentropy Logo"></a></p>
<p align="center">
    <a href="https://github.com/mailmug/zentropy/releases/latest"><img src="https://badgen.net/github/release/mailmug/zentropy" /></a>
    <a href="LICENSE"><img src="https://badgen.net/github/license/mailmug/zentropy" /></a>
    <a href="https://github.com/mailmug/zentropy"><img src="https://badgen.net/badge/project/zentropy/blue" /></a>
</p>


A high-performance, lightweight key-value store server written in Zig, supporting both TCP and Unix socket interfaces.

## Features
- **Dual Interface:** Simultaneous TCP and Unix socket support

- **High Performance:** Built with Zig for maximum efficiency

- **Simple Protocol:** Easy-to-use text-based protocol

- **Thread-Safe:** Concurrent client handling

- **Memory Safe:** No garbage collector, manual memory management

Zig Build version: 0.15.1+

## PERFORMANCE SUMMARY

### Data Size: 100 records

| Operation   | Redis    | Zentropy | Performance Delta |
|-------------|----------|----------|-------------------|
| Write       | 0.0075s  | 0.0046s  | 🟢 Zentropy 1.61x faster |
| Read        | 0.0000s  | 0.0000s  | 🟢 Same Result |
| Key-Value   | 0.0078s  | 0.0021s  | 🟢 Zentropy 3.79x faster |

### Data Size: 1,000 records

| Operation   | Redis    | Zentropy | Performance Delta |
|-------------|----------|----------|-------------------|
| Write       | 0.0285s  | 0.0148s  | 🟢 Zentropy 1.92x faster |
| Read        | 0.0000s  | 0.0000s  | 🟢 Zentropy 1.23x faster |
| Key-Value   | 0.0033s  | 0.0023s  | 🟢 Zentropy 1.46x faster |

### Data Size: 5,000 records

| Operation   | Redis    | Zentropy | Performance Delta |
|-------------|----------|----------|-------------------|
| Write       | 0.0808s  | 0.0731s  | 🟢 Zentropy 1.10x faster |
| Read        | 0.0000s  | 0.0000s  | 🟢 Zentropy 2.73x faster |
| Key-Value   | 0.0032s  | 0.0022s  | 🟢 Zentropy 1.49x faster |

### Data Size: 20,000 records

| Operation   | Redis    | Zentropy | Performance Delta |
|-------------|----------|----------|-------------------|
| Write       | 0.3173s  | 0.2894s  | 🟢 Zentropy 1.10x faster |
| Read        | 0.0001s  | 0.0000s  | 🟢 Zentropy 8.76x faster |
| Key-Value   | 0.0098s  | 0.0020s  | 🟢 Zentropy 4.82x faster |


## 🧩 How to Install

**Step 1:** Download the [release binary](https://github.com/mailmug/zentropy/releases/tag/v1.0.0)

**Step 2:** Extract the ZIP file.

**Step 3:** Copy the `zentropy.conf` file, edit the password, and place it in the same directory as the `zentropy` binary:

```bash
bind_address 127.0.0.1
port 6383
password pass@123
```
**Step 4:** Run the binary based on your CPU architecture:
```bash
./zentropy
```

✅ Tip: Once the server is running, you can test it using the [Python Client](https://pypi.org/project/zentropy-py/):
```python
from zentropy import Client

client = Client(password="pass@123")
print(client.ping())  # Should print: True
```

## Client Library
1. [Python Client Library](https://pypi.org/project/zentropy-py/).
2. [PHP Client Library](https://packagist.org/packages/mailmug/zentropy-php).

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

DELETE apple
```


## Using unix socket
```bash
echo "PING" | nc -U /tmp/zentropy.sock
# -> +PONG
```

## Contribution
[Roadmap](https://github.com/mailmug/zentropy/issues/9)

Zentropy is open-source! Contributions, suggestions, and bug reports are welcome.

Feel free to fork the repo, submit PRs, or open issues.