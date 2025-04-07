# Tailscale

## Purpose

Tailscale is a secure mesh VPN built on WireGuard that enables encrypted connectivity between all agency systems. It provides a secure networking layer for AgencyStack components and allows remote access to services without exposing them directly to the internet.

## Installation Paths

- **Installation Directory**: `/opt/agency_stack/tailscale`
- **Configuration Files**: `/opt/agency_stack/tailscale/config`
- **Setup Script**: `/usr/local/bin/setup-tailscale`
- **Multi-Tenant Installation**: `/opt/agency_stack/clients/${CLIENT_ID}/tailscale` (when installed with `--client-id`)

## Configuration

Tailscale requires authentication to your Tailscale account. After installation, run the setup script:

```bash
sudo setup-tailscale
```

For advanced configuration, the setup script accepts additional options:

```bash
sudo setup-tailscale --exit-node --routes "10.0.0.0/24,192.168.1.0/24" --hostname "agency-server"
```

Options:
- `--exit-node`: Configure this machine as an exit node
- `--routes ROUTES`: Advertise routes (comma-separated CIDR format)
- `--hostname NAME`: Set the hostname on Tailscale network

## Logs

Tailscale logs can be found in:
- Component logs: `/var/log/agency_stack/components/tailscale.log`
- System logs: View with `journalctl -u tailscaled`

You can also view logs via the Makefile target:
```bash
make tailscale-logs
```

## Ports & Services

Tailscale uses the following ports:
- UDP port 41641 (outbound only, for establishing connections)
- UDP port 3478 (outbound only, STUN for NAT traversal)

No inbound ports need to be opened in your firewall for Tailscale to function.

## Security Considerations

- Tailscale provides end-to-end encryption for all traffic
- Network access controls are managed through the Tailscale admin console
- All connections are authenticated with node keys
- All connections are authorized via ACLs defined in the admin console

## Restart Methods

### Restart via Makefile

```bash
make tailscale-restart
```

### Manual Restart

```bash
sudo systemctl restart tailscaled
```

## Status Check

Check the status of your Tailscale connection:

```bash
make tailscale-status
```

or

```bash
tailscale status
```

## Common Errors

1. **Authentication Failed**:
   - Solution: Run `sudo setup-tailscale` and complete the authentication process

2. **Subnet Routing Not Working**:
   - Solution: Verify that subnet routes are enabled in the Tailscale admin console

3. **Connection Issues**:
   - Solution: Check firewall settings and verify outbound UDP traffic is allowed

## Usage

Tailscale creates a secure mesh network between all connected devices. After setting up Tailscale:

1. Access other Tailscale nodes by their assigned Tailscale IP address
2. Use tailnet DNS names to access services by name (if configured)
3. All traffic between Tailscale nodes is encrypted and secure

For multi-tenant deployments, each client can have their own isolated Tailscale network with separate authentication and ACLs.
