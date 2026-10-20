# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting on this repository (Security → Report a vulnerability). Include the file, the steps to reproduce, and the impact you expect.

## Scope

This repo contains setup scripts that run as root on a Proxmox host, and plugins that read and write local files and call connectors. Problems in any of these are in scope.

## Secrets

Never put API keys, tokens or passwords in an issue, a pull request or a commit. If one was committed by accident, revoke it first, then ask for the history to be cleaned.
