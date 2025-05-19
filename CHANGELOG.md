## [1.0.0] - 2025-05-19
### Changed
- Removed support for `Ruby` versions older than 3.0
- Removed support for `dry-validation` versions older than 1.0

## [0.12.3] - 2024-08-13
### Changed
- Renamed config option `:auto_wire_options` to `:auto_wire` at `:dry_validation` plugin
- Updated `Pathway::State#use` to accept block with postional parameters
- Updated `Pathway::State#use` to raise an `ArgumentError` exception on invalid arguments
### Added
- Provide alias `Pathway::State#use` to `Pathway::State#unwrap`

## [0.12.2] - 2024-08-06
### Added
- Add `Pathway::State#unwrap` and `Pathway::State#u` to access internal state

## [0.12.1] - 2024-06-23
### Added
- Add support for pattern matching on `Result`, `State` and `Error` instances
- Add `Pathway::Result::Mixin` to allow easy constant lookup for `Result::Success` and `Result::Failure`

## [0.12.0] - 2022-05-31
### Changed
- Improve compatibility with Ruby 3.0
### Added
- Add plugin `:auto_deconstruct_state` to help migrating old apps to Ruby 3.0

## [0.11.3] - 2020-07-22
### Changed
- Use default error message on `:fetch_model` step, at `:sequel_models` plugin, if model type cannot be determined

## [0.11.2] - 2020-07-22
### Changed
- Improve `from:` option for `:fetch_model` step, at `:sequel_models` plugin, to also accept a Sequel Dataset

## [0.11.1] - 2020-01-09
### Changed
- Improve custom `rspec` matchers for testing field presence on schemas

## [0.11.0] - 2020-01-02
### Added
- Add support for `dry-validation` 1.0 and above

## [0.10.0] - 2019-10-06
### Changed
- Restrict support for `dry-validation` from 0.11.0 up to (excluding) 1.0.0
- Changed behavior for `:transaction` step wrapper, on `:sequel_models` plugin, to allow to take a single step name instead of block.
- Changed behavior for `:after_commit` step wrapper, on `:sequel_models` plugin, to allow to take a single step name instead of block.

## [0.9.1] - 2019-02-18
### Changed
- Various improvements on documentation and gemspec.

## [0.9.0] - 2019-02-04
### Changed
- Changed behavior for `:after_commit` step wrapper, on `:sequel_models` plugin, to capture current state and reuse it later when executing.

### Fixed
- Allow invoking `call` directly on an operation class even if the `:responder` plugin is not loaded.

## [0.8.0] - 2018-10-01
### Changed
- Added support for `dry-validation` 0.12.x
- Renamed DSL method `sequence` to `around`. Keep `sequence` as an alias, although it may be deprecated on a future mayor release.
- Renamed DSL method `guard` to `if_true`. Keep `guard` as an alias, although it may be deprecated on a future mayor release.
- Added DSL method `if_false`, which behaves like `if_true` but checks if the passed predicate is false instead.
- Moved `Responder` class inside the `responder` plugin module.

## [0.7.0] - 2018-09-25
### Changed
- `sequel_models` plugin now automatically adds an optional context parameter to preload the model and avoid hitting the db on `:fetch_model` when the model is already available.
- Added `:set_context_param` option for `sequel_models` plugin to prevent trying to preload the model from the context.
- Allow `authorization` block to take multiple parameters on `simple_auth` plugin.

## [0.6.2] - 2018-05-19
### Fixed
- Allow `:error_message` option for `sequel_models` plugin to propagate down inherited classes

## [0.6.1] - 2018-03-16
### Changed
- Updated default error message for `:fetch_model` step, at `sequel_models` plugin, to indicate the model's name
- Added `:error_message` option for `sequel_models` plugin initializer to set the default error message
- Added `:error_message` option for `:fetch_model` step to override the default error message

## [0.6.0] - 2018-03-01
### Changed
- Replaced unmaintained `inflecto` gem with `dry-inflector`

## [0.5.1] - 2017-12-18
### Changed
- Changed behavior for `:fetch_model` step option `search_by:` to override both the search column and the input key (combine it with `using:` if you need a different value for the input key as well)
- `:fetch_model` step will no longer hit the database if the input key is nil and just return a `:not_found` error instead

## [0.5.0] - 2017-11-06
### Changed
- Changed base class for `Pathway::Error` from `StandardError` to `Object`

## [0.4.0] - 2017-10-31
### Changed
- Renamed `:authorization` plugin to `:simple_auth`

### Removed
- Removed `build_model_with` method from `:sequel_models` plugin

### Added
- New documentation for core functionality and plugins

## [0.3.0] - 2017-10-31 [YANKED]

## [0.2.0] - 2017-10-31 [YANKED]

## [0.1.0] - 2017-10-31 [YANKED]

## [0.0.20] - 2017-10-17
### Changed
- Renamed options `key:` and `column:` to `using:` and `search_by:`, for `:fetch_model` step, at `:sequel_models` plugin

### Added
- Added new option `to:` for overriding where to store the result, for `:fetch_model` step, at `:sequel_models` plugin

## [0.0.19] - 2017-10-17
### Removed
- Removed `Error#error_type` (use `Error#type` instead)
- Removed `Error#error_message` (use `Error#message` instead)
- Removed `Error#errors` (use `Error#details` instead)

## [0.0.18] - 2017-10-08
### Changed
- Changed `:sequel_models` default value for `search_by:` option from `:id` to the model's primary key
