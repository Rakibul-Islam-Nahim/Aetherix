# Cloudflare Tunnel setup (manual once)

The `setup-vps.sh` script already runs `cloudflared tunnel run` inside
Docker. The steps below only need to be done once per VPS to mint the
tunnel credentials.

## One-time setup

```bash
# 1. Login and create the tunnel (run anywhere with your Cloudflare account)
cloudflared tunnel login
cloudflared tunnel create aetherix

# 2. Copy the resulting JSON credential somewhere safe.
#    The setup script reads CLOUDFLARE_TUNNEL_TOKEN from .env.

# 3. In Cloudflare DNS, point news.cybersentinel.top CNAME to <UUID>.cfargotunnel.com

# 4. In Cloudflare Zero Trust → Tunnels → aetherix,
#    add a public hostname:
#      Subdomain: news
#      Domain:    cybersentinel.top
#      Service:   http://aetherix-backend:8000

# 5. Restart the cloudflared container:
sudo docker compose restart cloudflared
```

## Health check

```bash
curl -fsS https://news.cybersentinel.top/api/v1/health
# -> {"status":"ok","db":true,"version":"0.1.0"}
```