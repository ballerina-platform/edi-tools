# Changelog
This file contains all the notable changes done to the Ballerina EDI Module through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- [Add envelope-aware schema generation and typed envelope codegen per BEP-1441](https://github.com/ballerina-platform/ballerina-spec/issues/1441):
  `convertX12Schema` and `convertEdifactSchema` now auto-populate a structured
  `envelope` field (interchange / group? / transaction levels). `codegen` emits
  typed envelope wrappers when the schema declares an `envelope` — `<Name>Interchange`,
  `<Name>FunctionalGroup` (X12), `<Name>Transaction` (with `body: <Name>|error`),
  plus generated `headersFromEdiString`, `interchangeFromEdiString`, and
  `interchangeToEdiString` functions.
- When a schema declares an `envelope`, `libgen` emits a
  `[[dependency]] ballerina/edi >= 1.6.0` block in the generated library's
  `Ballerina.toml` (and prints a notice), since older runtimes reject the new
  `envelope` field on the closed `edi:EdiSchema` record.

### Changed
- EDIFACT schema generation no longer emits the `ignoreSegments: ["UNB"]`
  workaround; UNB/UNZ and UNH/UNT are lifted into the `envelope`. X12 generation
  lifts ST/SE and inlines ISA/IEA/GS/GE into the envelope levels. Generated
  EDIFACT schemas list `UNA` in `ignoreSegments` as a safeguard for
  non-envelope parsing paths (the >= 1.6.0 runtime strips/validates UNA itself
  in all envelope-aware paths).
- X12 `ISA02` (authorization information) and `ISA04` (security information)
  are generated as optional fields: they carry 10 spaces when `ISA01`/`ISA03`
  is `00`, and the runtime treats whitespace-only required fields as missing.
  `ISA11` is now tagged `standardsId` (Interchange Control Standards
  Identifier, 004010) instead of `repetitionSeparator`.
- EDIFACT pre-defined envelope segments model the full standard composites:
  UNB S001/S002/S003 carry all four components, S005 is a composite, and the
  UNH S009 message identifier has all seven components with meaningful tags.
  UNT fields are tagged `number_of_segments` / `message_reference_number`.
- Schema conversion fails with a clear error (instead of silently generating a
  broken envelope) when the source spec lacks UNH/UNT (EDIFACT) or ST/SE (X12).

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
