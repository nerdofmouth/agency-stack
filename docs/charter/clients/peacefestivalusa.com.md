# ✅ PeaceFestivalUSA WordPress Migration – Task Checklist

## Scope + Repo Prep + Fallback Lock
- [ ] Confirm path layout inside AgencyStack (/opt/agency_stack/clients/peacefestivalusa/wordpress/)
- [ ] Create initial GitHub repo or folder snapshot for PeaceFestivalUSA client infra (not content)
- [ ] Draft .env.example and folder placeholders for WordPress files, DB, nginx config
- [ ] Decide fallback approach: systemd/nginx path + containerized path
- [ ] Ensure domain/subdomain routing (peacefestivalusa.nerdofmouth.com) plan is viable

## Dockerization Attempt & Fallback Ready
- [ ] Attempt initial Docker Compose service using WordPress + MariaDB
- [ ] Document volume mounts to match /opt/agency_stack/clients/... structure
- [ ] If Docker fails, prepare systemd/nginx site directory and scaffolding
- [ ] Identify if Traefik or local nginx should serve this first version
- [ ] Log exact steps to replay for other clients later

## DNS + Deployment Prep
- [ ] Point peacefestivalusa.nerdofmouth.com DNS to target server
- [ ] Configure nginx or Traefik to resolve routing to WordPress
- [ ] Validate 80/443 availability (Let’s Encrypt or self-signed ok)
- [ ] Confirm site resolves publicly (default WP page ok)

## Content Migration
- [ ] Request/export backup from GoDaddy (DB + wp-content)
- [ ] Restore into your local (or hosted) instance
- [ ] Confirm plugin/theme compatibility (minimal fix pass)
- [ ] Confirm homepage and a sample post/page render properly

## Site Hardening + Admin Prep
- [ ] Clean up permalinks, caching, and basic SEO configs
- [ ] Disable unused plugins, themes, or insecure code
- [ ] Create Wayne’s admin user and confirm login access
- [ ] Prepare visual checklist of what’s functional and what’s pending

## Wrap + Reintegrate
- [ ] Decide: leave as fallback (nginx) or reattempt Docker conversion
- [ ] Optionally mirror install for CI testing
- [ ] Begin writing AgencyStack Makefile entries or automation triggers for future installs
- [ ] Demo to Wayne + prep simple handoff doc if needed
