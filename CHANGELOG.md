# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added

- backup of individual objects ([#3])
- Option to disable the component via hierarchy
- Fix slow object dumping on OpenShift 4 ([#6])
- Add `ProjectRequests` to known-to-fail list ([#7])

### Changed

- Update object-dumper image default tag to v0.1.1 ([#8])
- Update object-dumper image default tag to v0.2.0 ([#9])
- Revert object-dumper image default tag to v0.1.1 ([#10])

[Unreleased]: https://github.com/projectsyn/component-cluster-backup/compare/11573bc...HEAD

[#3]: https://github.com/projectsyn/component-cluster-backup/pull/3
[#6]: https://github.com/projectsyn/component-cluster-backup/pull/6
[#7]: https://github.com/projectsyn/component-cluster-backup/pull/7
[#8]: https://github.com/projectsyn/component-cluster-backup/pull/8
[#9]: https://github.com/projectsyn/component-cluster-backup/pull/9
[#10]: https://github.com/projectsyn/component-cluster-backup/pull/10
