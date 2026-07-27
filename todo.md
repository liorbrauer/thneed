# TODO

## Production deployment

- [ ] Configure encrypted off-site backups.
  - [ ] Create a private Hetzner Object Storage bucket and dedicated S3 credentials.
  - [ ] Configure Restic on the production server.
  - [ ] Schedule recurring SQLite and file backups.
  - [ ] Verify a snapshot can be listed and restored.
  - [ ] Run `PRAGMA integrity_check` against a restored SQLite database.

- [x] Configure production email.
  - [x] Obtain Hetzner approval for outbound SMTP on port 25.
  - [x] Configure Postfix and OpenDKIM.
  - [x] Set the Hetzner reverse DNS record to `thneed.org`.
  - [x] Open TCP port 25 in the server firewall.
  - [x] Add SPF, DKIM, DMARC, and MX records in Cloudflare.
  - [x] Forward administrative and system aliases to `lior@hey.com`.
  - [x] Verify inbound delivery, outbound delivery, TLS, and Action Mailbox replies.
