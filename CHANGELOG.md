## [0.5.1] - 2017-12-18
### Changed
- Change behavior for `:fetch_model` step option `search_by:` to override both the search column and the input key (combine it with `using:` if you need a different value for the input key as well)
- `:fetch_model` step will no longer hit the database if the input key is nil and just return a `:not_found` error instead

## [0.5.0] - 2017-11-6
### Changed
- Change base class for `Pathway::Error` from `StandardError` to `Object`

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
