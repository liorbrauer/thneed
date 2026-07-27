# Deploy Thneed to Hatchbox with SQLite

## Summary

Deploy commit `e3daa5c9` from `main` to a new, dedicated Hetzner Cloud
server managed by Hatchbox:

- Hetzner Ashburn, Virginia (`us-east`)
- Ubuntu 24.04 LTS, x86, 2 vCPU / 4 GB RAM
- Fresh persistent SQLite databases
- Cloudflare authoritative DNS
- Self-hosted Postfix/OpenDKIM
- Encrypted Restic backups in Hetzner Object Storage
- Full HTTPS, mail, cron, queue, sitemap, backup, and smoke-test setup

Full launch is gated on Hetzner approving outbound SMTP port 25. Hetzner
Object Storage is unavailable in US regions, so backups will use its
Nuremberg endpoint as an off-region copy. See
[Hetzner locations](https://docs.hetzner.com/cloud/general/locations/).

## Implementation

### 1. Access and infrastructure

- Complete interactive sign-ins for Hatchbox, Hetzner, GitHub, and
  Cloudflare; do not share account passwords.
- Verify `e3daa5c9` exists on GitHub `main`, without committing the unrelated
  local `AGENTS.md` change.
- Connect Hatchbox to Hetzner and GitHub, create a `thneed` cluster, and
  provision the dedicated Ashburn server with web/application roles only.
- Check the assigned IP against major mail blocklists before continuing;
  recreate the fresh server if the IP has a poor reputation.
- Set the server hostname and Hetzner reverse DNS to `thneed.org`.
- Request Hetzner SMTP-port unblocking and require successful external inbound
  and outbound port-25 tests before mail launch.
- Create a private Hetzner Object Storage bucket in Nuremberg with dedicated
  S3 credentials and object-lock/versioning protection where available.

### 2. Secure production bootstrap

Before the first application deploy, create `/home/deploy/thneed/shared`
storage and upload:

- `etc/credentials.yml.enc` and `etc/master.key`, generated from the checked-in
  credentials template with a new secret key.
- `etc/database.yml`, based on `config/database.yml.sample`.
- `etc/admin_email`, containing the external destination for all
  administrative aliases.
- `etc/restic-env`, mode `0600`, containing the S3 endpoint, bucket
  credentials, repository URL, and a generated Restic password.
- Persistent `storage`, `database-backups`, `log`, `tmp/pids`, and
  `public/avatars` directories owned by `deploy`.

Initialize Restic and confirm an encrypted test snapshot can be listed and
restored.

### 3. Hatchbox application configuration

Create the `thneed` app from GitHub `main` with `/home/deploy/thneed` as its
deployment path.

Configure:

- Web process: `bundle exec puma -C config/puma.rb`
- Queue process: `bundle exec rails solid_queue:start`
- Pre-build hook: `hatchbox/pre-build`
- Post-deploy hook: `hatchbox/post-deploy`
- Caddyfile: exact contents of `hatchbox/Caddyfile`
- Cron every minute: `script/expire_page_cache`
- Cron every five minutes: `script/thneed-cron`

Set environment variables:

```text
BUNDLE_WITHOUT=development:test
INGRESS_PASSWORD=<generated>
PORT=9000
RACK_ENV=production
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=true
RAILS_MAX_THREADS=10
PUMA_WORKERS=2
SECRET_KEY_BASE=<generated>
```

Do not set `DATABASE_URL` or `SOLID_QUEUE_IN_PUMA`; SQLite uses
`database.yml`, and Solid Queue runs as a separately monitored process.

### 4. Deploy and provision the host

- Perform the first deploy and verify `storage` resolves to
  `/home/deploy/thneed/shared/storage`.
- Preinstall the packages required by `hatchbox/root-deploy`, including
  SQLite, Restic, Postfix, OpenDKIM, iptables persistence, and
  `libclang-dev`.
- Link and enable `root-deploy.service` and `root-deploy.path`, then deploy
  again to apply the tracked Caddy, mail, logging, SSH, firewall, and backup
  configuration.
- Add inbound TCP 25 to Hatchbox/UFW firewall rules alongside SSH, HTTP, and
  HTTPS.
- Confirm unattended security upgrades, Caddy, Puma, Solid Queue, Postfix,
  OpenDKIM, and the root deployment units are enabled and healthy.

### 5. Database and administration

- Run production migrations without `db:setup`, `db:seed`, or `db:prepare`,
  avoiding the insecure sample `test/test` administrator.
- Confirm all four databases exist under shared storage: primary, cache,
  queue, and rack-attack.
- Create the first administrator/moderator through a production Rails console
  using a supplied username/email and generated one-time password.
- Preview and create the initial taxonomy, substituting the administrator's
  username:
  `DRY_RUN=1 RAILS_ENV=production bin/rails "thneed:bootstrap_taxonomy[admin_username]"`
  followed by the same command without `DRY_RUN=1`.
- Manage later category and tag changes through the authenticated site
  workflow; rerunning the bootstrap never overwrites existing records.
- Compile assets, generate the sitemap, restart both application processes,
  and verify recurring Solid Queue jobs are registered.

### 6. DNS and mail launch

Keep Cloudflare records DNS-only rather than proxied:

- Apex `A` record to the server IPv4 address
- `www` CNAME to `thneed.org`
- MX priority 10 to `thneed.org`
- SPF authorizing the server
- `mail._domainkey` TXT from the generated OpenDKIM key
- DMARC initially at `p=none` with aggregate reports sent to the
  administrative inbox

Forward `security@`, `privacy@`, `support@`, and system aliases to the single
external administrator address; route application reply addresses through
Action Mailbox.

Verify:

- Forward and reverse DNS alignment
- Postfix TLS using Caddy's certificate
- SPF, DKIM, and DMARC
- External inbound and outbound delivery
- Action Mailbox email replies
- Mail reputation with a service such as Mail-Tester

Do not publish the MX record until Hetzner has unblocked SMTP and all direct
mail tests pass.

## Test and acceptance plan

- Run the repository test suite before deployment.
- Verify HTTP-to-HTTPS and `www`-to-apex redirects, HSTS, `/up`, assets,
  sitemap, login, admin access, and an empty fresh installation.
- Create a temporary record, redeploy, and confirm SQLite data survives
  release replacement.
- Confirm Puma and Solid Queue recover after restart and reboot.
- Run Restic immediately, restore the primary database to a temporary path,
  and pass `PRAGMA integrity_check`.
- Verify both cron schedules and recurring jobs execute successfully.
- Confirm logs rotate and the root deployment hook runs after a subsequent
  deployment.
- Preserve the pre-migration SQLite backup for rollback; application releases
  can roll back through Hatchbox, while database rollback uses the verified
  Restic snapshot.

## Assumptions

- `thneed.org` is the intended production domain.
- Cloudflare already controls its authoritative DNS.
- The administrator address and account identity will be supplied during the
  authenticated deployment session.
- Optional Diffbot, GitHub OAuth, Mastodon, Pushover, and telemetry credentials
  remain unset unless supplied.
- Interactive account sign-ins are the only user handoffs; all remaining
  configuration, SSH work, verification, and deployment are handled afterward.
- Hetzner SMTP approval is an external dependency. If denied, the web
  application may be deployed, but full production launch pauses until a
  managed mail alternative is selected.
