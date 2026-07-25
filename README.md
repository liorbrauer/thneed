# Thneed

[Thneed](https://thneed.org) is a text-first community for thoughtful
discussion about how artificial intelligence changes human work, creativity,
power, and agency.

The application is a fork of
[Lobsters](https://github.com/lobsters/lobsters), a Rails link-aggregation and
discussion codebase. Lobsters' design and source made Thneed possible. Both the
upstream code and this fork are distributed under the
[3-clause BSD license](LICENSE).

## Development

Thneed uses Ruby on Rails and SQLite. To prepare a local checkout:

```sh
bin/setup
bin/rails server
```

Run the test suite with:

```sh
bin/rspec
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and the setup notes in [docs](docs) for
more development-environment detail. When pulling upstream changes, keep the
internal `Lobsters` Rails namespace and historical migrations unless a
user-facing change requires otherwise.

## Production

The checked-in Hatchbox, Caddy, Postfix, and OpenDKIM files target
`thneed.org`, with the application at `/home/deploy/thneed`. Production secrets
belong in Rails credentials or deployment environment variables and must never
be committed.

Before deploying:

1. Point `thneed.org` and `www.thneed.org` at the server and configure reverse
   DNS for outbound mail.
2. Provision Rails credentials, `SECRET_KEY_BASE`, the production database,
   and any integration credentials described in
   `config/credentials.yml.enc.sample`.
3. Provision or forward `security@thneed.org`, `privacy@thneed.org`, and
   `support@thneed.org`.
4. Install the files under `hatchbox/`, enable the root deployment units, and
   configure the application processes.
5. Schedule `script/expire_page_cache` each minute and
   `script/thneed-cron` every five minutes.
6. Generate and publish the DKIM record, verify TLS and mail delivery, compile
   assets, generate the sitemap, and perform a production boot smoke test.

The site starts without seeded topic categories. Administrators create and
manage categories and tags through the existing on-site workflow.

## Community administration

Community policy is published at [thneed.org/about](https://thneed.org/about).
Moderation actions are public, invitation relationships remain visible, and
the established ranking, flagging, feed, story, and comment interfaces are
preserved.

Security issues should be reported privately to
[security@thneed.org](mailto:security@thneed.org); see
[SECURITY.md](SECURITY.md).
