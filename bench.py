import socket
import time
import random

class SocketPerformanceTest:
    def __init__(self, zentropy_port=6383, redis_port=6379):
        self.zentropy_port = zentropy_port
        self.redis_port = redis_port
        self.data_sizes = [100, 1000, 5000, 20000]
        
        # Test connections
        self.redis_available = self.test_connection(redis_port, "Redis")
        self.zentropy_available = self.test_connection(zentropy_port, "Zentropy")
    
    def test_connection(self, port, name):
        """Test if a service is running on the specified port"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(2)
            result = sock.connect_ex(('127.0.0.1', port))
            sock.close()
            if result == 0:
                print(f"✓ {name} is running on port {port}")
                return True
            else:
                print(f"✗ {name} is NOT running on port {port}")
                return False
        except Exception as e:
            print(f"Error checking {name} on port {port}: {e}")
            return False
    
    def send_redis_command(self, sock, command):
        """Send Redis protocol command and get response"""
        # Redis protocol: *<number of args>\r\n$<length>\r\n<arg>\r\n...
        parts = command.strip().split()
        protocol = f"*{len(parts)}\r\n"
        for part in parts:
            protocol += f"${len(part)}\r\n{part}\r\n"
        
        sock.sendall(protocol.encode())
        response = sock.recv(4096).decode()
        return response
    
    def send_zentropy_command(self, sock, command):
        """Send Zentropy command (plain text)"""
        sock.sendall((command + "\n").encode())
        response = sock.recv(4096).decode()
        return response
    
    def generate_test_data(self, size):
        """Generate simple test data"""
        data = []
        base_time = int(time.time()) - size
        for i in range(size):
            timestamp = base_time + i
            value = random.random() * 100
            data.append((timestamp, value))
        return data
    
    def test_redis_write(self, data_size):
        """Test Redis write performance using socket"""
        if not self.redis_available:
            return None
        
        test_data = self.generate_test_data(data_size)
        ts_name = f"redis_test_{data_size}_{int(time.time())}"
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('127.0.0.1', self.redis_port))
            
            start_time = time.time()
            for timestamp, value in test_data:
                # Using ZADD for sorted set (similar to time series)
                command = f"ZADD {ts_name} {timestamp} {value}"
                self.send_redis_command(sock, command)
            
            redis_time = time.time() - start_time
            sock.close()
            print(f"Redis write {data_size} records: {redis_time*1000:.2f} ms ({data_size/redis_time:.1f} ops/sec)")
            return redis_time
            
        except Exception as e:
            print(f"Redis write failed: {e}")
            return None
    
    def test_zentropy_write(self, data_size):
        """Test Zentropy write performance using socket"""
        if not self.zentropy_available:
            return None
        
        test_data = self.generate_test_data(data_size)
        ts_name = f"zt_test_{data_size}_{int(time.time())}"
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('127.0.0.1', self.zentropy_port))
            
            start_time = time.time()
            for timestamp, value in test_data:
                # Assuming Zentropy uses ADD command: ADD <series> <timestamp> <value>
                command = f"ADD {ts_name} {timestamp} {value}"
                self.send_zentropy_command(sock, command)
            
            zt_time = time.time() - start_time
            sock.close()
            print(f"Zentropy write {data_size} records: {zt_time*1000:.2f} ms ({data_size/zt_time:.1f} ops/sec)")
            return zt_time
            
        except Exception as e:
            print(f"Zentropy write failed: {e}")
            return None
    
    def test_redis_read(self, data_size):
        """Test Redis read performance using socket"""
        if not self.redis_available:
            return None
        
        ts_name = f"redis_test_{data_size}"
        
        try:
            # First write some data
            test_data = self.generate_test_data(data_size)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('127.0.0.1', self.redis_port))
            
            for timestamp, value in test_data:
                command = f"ZADD {ts_name} {timestamp} {value}"
                self.send_redis_command(sock, command)
            
            # Now test reading
            start_time = time.time()
            iterations = 10
            for i in range(iterations):
                command = f"ZRANGE {ts_name} 0 -1 WITHSCORES"
                self.send_redis_command(sock, command)
            
            redis_time = (time.time() - start_time) / iterations
            sock.close()
            print(f"Redis read {data_size} records: {redis_time*1000:.2f} ms avg")
            return redis_time
            
        except Exception as e:
            print(f"Redis read failed: {e}")
            return None
    
    def test_zentropy_read(self, data_size):
        """Test Zentropy read performance using socket"""
        if not self.zentropy_available:
            return None
        
        ts_name = f"zt_test_{data_size}"
        
        try:
            # First write some data
            test_data = self.generate_test_data(data_size)
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.connect(('127.0.0.1', self.zentropy_port))
            
            for timestamp, value in test_data:
                command = f"ADD {ts_name} {timestamp} {value}"
                self.send_zentropy_command(sock, command)
            
            # Now test reading (assuming GET command)
            start_time = time.time()
            iterations = 10
            for i in range(iterations):
                command = f"GET {ts_name}"
                self.send_zentropy_command(sock, command)
            
            zt_time = (time.time() - start_time) / iterations
            sock.close()
            print(f"Zentropy read {data_size} records: {zt_time*1000:.2f} ms avg")
            return zt_time
            
        except Exception as e:
            print(f"Zentropy read failed: {e}")
            return None
    
    def test_key_value_operations(self, data_size):
        """Test basic SET/GET operations (both support this)"""
        results = {}
        
        # Redis SET/GET test
        if self.redis_available:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.connect(('127.0.0.1', self.redis_port))
                
                start_time = time.time()
                for i in range(data_size):
                    key = f"key_{i}"
                    value = f"value_{i}_{random.random()}"
                    # SET operation
                    self.send_redis_command(sock, f"SET {key} {value}")
                    # GET operation
                    self.send_redis_command(sock, f"GET {key}")
                
                redis_time = time.time() - start_time
                sock.close()
                results['redis'] = redis_time
                print(f"Redis SET/GET {data_size} pairs: {redis_time*1000:.2f} ms")
                
            except Exception as e:
                print(f"Redis SET/GET failed: {e}")
                results['redis'] = None
        
        # Zentropy SET/GET test (if it supports key-value operations)
        if self.zentropy_available:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.connect(('127.0.0.1', self.zentropy_port))
                
                start_time = time.time()
                for i in range(data_size):
                    key = f"key_{i}"
                    value = f"value_{i}_{random.random()}"
                    # Try SET command
                    self.send_zentropy_command(sock, f"SET {key} {value}")
                    # Try GET command
                    self.send_zentropy_command(sock, f"GET {key}")
                
                zt_time = time.time() - start_time
                sock.close()
                results['zentropy'] = zt_time
                print(f"Zentropy SET/GET {data_size} pairs: {zt_time*1000:.2f} ms")
                
            except Exception as e:
                print(f"Zentropy SET/GET failed: {e}")
                results['zentropy'] = None
        
        return results
    
    def run_all_tests(self):
        """Run all performance tests"""
        print("Starting socket-based performance comparison...")
        print("=" * 60)
        
        all_results = {}
        
        for size in self.data_sizes:
            print(f"\nTesting with {size} records:")
            print("-" * 40)
            
            # Write tests
            redis_write = self.test_redis_write(size)
            zentropy_write = self.test_zentropy_write(size)
            
            # Read tests
            redis_read = self.test_redis_read(size)
            zentropy_read = self.test_zentropy_read(size)
            
            # Key-value tests
            kv_results = self.test_key_value_operations(min(100, size))
            
            all_results[size] = {
                'write': {
                    'redis': redis_write,
                    'zentropy': zentropy_write
                },
                'read': {
                    'redis': redis_read,
                    'zentropy': zentropy_read
                },
                'key_value': kv_results
            }
        
        self.print_summary(all_results)
        return all_results
    
    def print_summary(self, results):
        """Print summary of all test results"""
        print("\n" + "=" * 60)
        print("PERFORMANCE SUMMARY")
        print("=" * 60)
        
        for size in self.data_sizes:
            print(f"\nData Size: {size} records")
            print("-" * 40)
            
            size_results = results[size]
            for test_name, test_results in size_results.items():
                print(f"{test_name.upper():<12} -> ", end="")
                
                redis_time = test_results.get('redis')
                zt_time = test_results.get('zentropy')
                
                if redis_time and zt_time:
                    faster = "Zentropy" if zt_time < redis_time else "Redis"
                    ratio = redis_time / zt_time if zt_time < redis_time else zt_time / redis_time
                    print(f"Redis: {redis_time*1000:.2f} ms | Zentropy: {zt_time*1000:.2f} ms | {faster} is {ratio:.2f}x faster")
                elif redis_time:
                    print(f"Redis: {redis_time:.2f}ms | Zentropy: N/A")
                elif zt_time:
                    print(f"Redis: N/A | Zentropy: {zt_time:.2f}ms")
                else:
                    print("Both: N/A")

# Run the benchmark
if __name__ == "__main__":
    benchmark = SocketPerformanceTest(zentropy_port=6383, redis_port=6379)
    results = benchmark.run_all_tests()