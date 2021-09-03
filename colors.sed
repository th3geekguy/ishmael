#!/bin/sed -f
s/leader\b/\x1b[32m&\x1b[0m/g
s/\bready\b/\x1b[32m&\x1b[0m/g
s/\bHealthy\b/\x1b[32m&\x1b[0m/g
s/\bmanager\b/\x1b[34m&\x1b[0m/g
s/\bworker\b/\x1b[33m&\x1b[0m/g
2,$s/\bMSR\b/\x1b[34m&\x1b[0m/g
s/\bheartbeat failure\b/\x1b[5;31m&\x1b[0m/g
s/\bdown\b/\x1b[5;31m&\x1b[0m/g
2,$s/\bMKE\b/\x1b[90m&\x1b[0m/g
1s/\b[A-Z_][A-Z_]*\b/\x1b[1m&\x1b[0m/g
