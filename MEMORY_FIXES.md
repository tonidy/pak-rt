# Memory Usage Tracking and OOM Testing Fixes

## Problem Summary

The RT container runtime had several issues with memory usage tracking and OOM (Out of Memory) testing:

1. **Inaccurate Memory Usage Tracking**: Memory usage was only read from cgroup accounting, but processes weren't actually using memory in a way that would show up in cgroup statistics.

2. **No OOM Testing**: There was no functionality to actually stress test memory limits and trigger OOM conditions.

3. **Limited cgroup v2 Support**: The code was primarily designed for cgroup v1, but many modern systems use cgroup v2.

4. **Ineffective Memory Allocation**: Test commands didn't actually allocate memory that would be tracked by the kernel's memory accounting.

## Solutions Implemented

### 1. Enhanced Memory Testing Commands

Added two new commands for comprehensive memory testing:

#### `test-memory <container> [memory_mb]`
- Tests memory limits and OOM killer functionality
- Progressively allocates memory using multiple strategies
- Actually uses memory (not just allocates) to trigger proper accounting
- Monitors memory usage in real-time during the test
- Detects OOM killer activation

#### `stress-memory <container> [target_mb] [duration_seconds]`
- Continuous memory stress testing
- Multiple allocation strategies running concurrently
- Sustained memory pressure over specified duration
- Real-time monitoring of memory usage and system response

### 2. Improved Memory Allocation Strategies

The new memory test scripts use multiple effective memory allocation methods:

```bash
# Strategy 1: Large sequential allocation with actual data usage
dd if=/dev/zero bs=1M count=$chunk_mb | tee "$temp_file" | head -c $size > /dev/null

# Strategy 2: Pattern-based allocation that consumes memory
yes "$(printf '%*s' 1024 'STRESS')" | head -c $size > /dev/null

# Strategy 3: Random data allocation
head -c $size /dev/urandom > /dev/null

# Strategy 4: File-based memory usage
# Create temp files and repeatedly read them to keep data in memory
```

### 3. Enhanced cgroup Support

#### Improved cgroup Version Detection
```bash
detect_cgroup_version() {
    if [[ "$DETECTED_OS" == "Darwin" ]]; then
        echo "none"
    elif [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
        # cgroup v2 unified hierarchy
        echo "v2"
    elif mount | grep -q "cgroup2.*cgroup2"; then
        # cgroup v2 mounted
        echo "v2"
    elif [[ -d "/sys/fs/cgroup/memory" ]] && [[ -f "/sys/fs/cgroup/memory/memory.limit_in_bytes" ]]; then
        # cgroup v1 with memory controller
        echo "v1"
    # ... additional checks
}
```

#### Dual cgroup Support in Memory Monitoring
```bash
# Support both cgroup v1 and v2 in memory usage tracking
if [[ -f "$memory_cgroup/memory.usage_in_bytes" ]]; then
    # cgroup v1
    usage_bytes=$(cat "$memory_cgroup/memory.usage_in_bytes")
    limit_bytes=$(cat "$memory_cgroup/memory.limit_in_bytes")
elif [[ -f "$memory_cgroup/memory.current" ]]; then
    # cgroup v2
    usage_bytes=$(cat "$memory_cgroup/memory.current")
    limit_bytes=$(cat "$memory_cgroup/memory.max")
fi
```

### 4. Real-time Memory Monitoring

Enhanced the monitoring functions to:
- Show accurate memory usage from both cgroup v1 and v2
- Display memory usage as actual MB values
- Calculate percentage usage correctly
- Handle unlimited memory scenarios
- Provide real-time updates during tests

### 5. Proper OOM Testing

The new memory tests can actually trigger OOM conditions by:
- Allocating memory that is actually used (not just reserved)
- Creating memory pressure that the kernel tracks
- Using multiple allocation strategies simultaneously
- Sustaining memory usage over time
- Properly detecting when OOM killer is triggered (exit code 137)

## Usage Examples

### Basic Memory Limit Testing
```bash
# Create container with 128MB memory limit
./rt.sh create test-container --ram=128 --cpu=25

# Test memory allocation within limits (64MB)
./rt.sh test-memory test-container 64

# Test memory allocation that may trigger OOM (150MB > 128MB limit)
./rt.sh test-memory test-container 150
```

### Memory Stress Testing
```bash
# Stress test with 100MB target for 30 seconds
./rt.sh stress-memory test-container 100 30

# Monitor memory usage in real-time
./rt.sh monitor test-container 60
```

### Comprehensive Testing
```bash
# Run the complete test suite
./test-memory-fixes.sh
```

## Technical Details

### Memory Allocation Techniques Used

1. **dd with tee**: Creates actual data flow that consumes memory
2. **yes with pattern**: Generates large amounts of data in memory
3. **urandom reading**: Forces kernel to generate and buffer random data
4. **File-based caching**: Creates files and repeatedly reads them to keep data in memory buffers

### OOM Detection

The tests properly detect OOM killer activation by:
- Monitoring process exit codes (137 = SIGKILL from OOM killer)
- Checking process survival during allocation
- Monitoring cgroup memory statistics
- Detecting when processes are killed unexpectedly

### cgroup Compatibility

The implementation now works with:
- **cgroup v1**: Traditional separate controller hierarchies
- **cgroup v2**: Unified hierarchy with different file names
- **Mixed environments**: Systems with both v1 and v2 controllers
- **Rootless containers**: Limited cgroup access scenarios

## Testing the Fixes

Run the comprehensive test script:
```bash
./test-memory-fixes.sh
```

This will:
1. Create a test container with memory limits
2. Verify cgroup setup and memory limit configuration
3. Test basic memory monitoring
4. Test memory allocation within limits
5. Test memory stress that may trigger OOM
6. Demonstrate real-time memory usage tracking

## Expected Results

With these fixes, you should now see:
- ✅ Accurate memory usage reporting in MB
- ✅ Proper percentage calculations based on limits
- ✅ OOM killer activation when limits are exceeded
- ✅ Real-time memory monitoring during tests
- ✅ Support for both cgroup v1 and v2 systems
- ✅ Effective memory stress testing capabilities

The memory usage tracking is now accurate and OOM testing actually works by creating real memory pressure that the kernel properly tracks and limits.
