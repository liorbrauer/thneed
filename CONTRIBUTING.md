# Contributing

Thanks for helping improve Thneed. Bug fixes, accessibility improvements,
tests, documentation corrections, and focused features are welcome.

Before opening a change:

1. Search existing issues and pull requests.
2. Keep changes narrow and preserve the established story, comment,
   invitation, ranking, and moderation behavior unless the change explicitly
   addresses one of those systems.
3. Add tests for behavior changes and run `bin/rspec`.
4. Run `bin/standardrb` for Ruby changes and the CSS compatibility spec for
   stylesheet changes.
5. Explain user-visible effects and deployment considerations in the pull
   request.

Thneed is forked from [Lobsters](https://github.com/lobsters/lobsters).
Upstream-compatible fixes should generally be proposed upstream as well.
Thneed-specific product and community-policy decisions belong in this
repository.

Do not include credentials, private user information, production logs, or
security vulnerability details in a public issue. Report vulnerabilities to
[security@thneed.org](mailto:security@thneed.org).
