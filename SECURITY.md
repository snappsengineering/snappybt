# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `26.0` | Yes |
| `18.0` | Yes |
| `16.0` | Yes |

Older tags from prior repo history are unsupported.

## Reporting a vulnerability

Please do not open a public issue. Use GitHub's private reporting:
**Security > Report a vulnerability** on this repository.

Include affected version, a minimal reproduction, and the impact. You can expect an acknowledgement within a few days.

## Scope

In scope: `Sources/SnappyBT` and any behavior that could crash, corrupt data, or expose secrets in consuming apps. Apps remain responsible for their own API keys and backend policies.
