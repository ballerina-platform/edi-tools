# Changelog
This file contains all the notable changes done to the Ballerina EDI Module through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- [Extract X12 XSD enumerations (inline and named simple types resolved through `xs:include`, e.g. a shared `Codes.xsd`) into the generated schema as `values` constraints, marking inline enumerations of same-code sibling definitions as `discriminator`s for qualifier-based segment matching](https://github.com/ballerina-platform/ballerina-library/issues/9100)
- [Read optional `values` code lists from ESL element definitions into the generated schema](https://github.com/ballerina-platform/ballerina-library/issues/9100)
- [Generate string-literal union types (e.g. `("17"|"23"|"DX")`) for discriminator fields in generated records, so an out-of-set qualifier becomes a compile-time error; validation-only `values` lists keep their base type](https://github.com/ballerina-platform/ballerina-library/issues/9100)

### Fixed

## [2.2.1] - 2026-08-21

### Fixed

- [Strip characters that are illegal in a Ballerina identifier from generated EDIFACT tags, so element names such as "United Nations Dangerous Goods (UNDG) identifier" no longer generate records that fail to compile](https://github.com/ballerina-platform/ballerina-library/issues/9065)
- [Ship the `UGH` and `UGT` service segment definitions, which are published in the service segment directory rather than in the standard segments directory, so the messages referencing them can be converted and generated](https://github.com/ballerina-platform/ballerina-library/issues/9065)
- [Suffix colliding sibling segment tags, so a segment listed at two positions of the same segment group no longer generates two record fields with the same name](https://github.com/ballerina-platform/ballerina-library/issues/9065)
- [Convert only the batch message directory of an EDIFACT release, skipping the interactive messages that used to abort a whole-release conversion, and report an unconvertible message instead of discarding the run](https://github.com/ballerina-platform/ballerina-library/issues/9065)

## [2.2.0] - 2026-08-03

### Added
- [Generate envelope-aware EDI schemas and typed envelope wrappers (BEP-1441)](https://github.com/ballerina-platform/ballerina-spec/issues/1441)
- [Populate the schema envelope in X12 headers mode so `convertX12Schema -H` output works with envelope-aware APIs (BEP-1441)](https://github.com/ballerina-platform/ballerina-spec/issues/1441)
- [Expose the envelope-aware functions in the default module of a `libgen` package (BEP-1441)](https://github.com/ballerina-platform/ballerina-spec/issues/1441)

### Changed
- [Convert EDIFACT schemas from a locally downloaded UNECE directory passed with `convertEdifactSchema -i`, as `service.unece.org` no longer serves the directories to non-browser clients](https://github.com/ballerina-platform/ballerina-library/issues/8983)

### Fixed
- [Retain segment fields whose names wrap across two lines in the EDIFACT specification, which were previously dropped from the generated segment definitions](https://github.com/ballerina-platform/ballerina-library/issues/8983)
- [Surface command failures instead of exiting with a success status: print usage for `--help` and for missing options, propagate the EDI tool exit code, and stop discarding the tool's error output](https://github.com/ballerina-platform/ballerina-library/issues/8982)
- [Skip non-`.json` entries in a `libgen` schema folder with a warning instead of failing on them, and remove the generated package when no schemas could be generated so an unbuildable one is never left behind](https://github.com/ballerina-platform/ballerina-library/issues/8982)

## [2.0.0] - 2024-05-29

### Changed
- [bal tool is not working when java is not installed](https://github.com/ballerina-platform/ballerina-library/issues/6473)

## [1.0.0] - 2024-03-13

### Added
- [Add support for Ballerina Swan Lake Update 8.](https://github.com/ballerina-platform/ballerina-library/issues/5900)
- [Add support for field length constraints (min/max).](https://github.com/ballerina-platform/ballerina-library/issues/5896)
- Add support for EDIFACT to Ballerina schema conversion.

### Changed
- Documentation improvements on tool and CLI commands.
- Set the default value of `required` to `true` for the field `code` in schema definitions.
