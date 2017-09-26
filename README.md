# Pathway

[![Gem Version](https://badge.fury.io/rb/pathway.svg)](https://badge.fury.io/rb/pathway)
[![CircleCI](https://circleci.com/gh/pabloh/pathway/tree/master.svg?style=shield)](https://circleci.com/gh/pabloh/pathway/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/pabloh/pathway/badge.svg?branch=master)](https://coveralls.io/github/pabloh/pathway?branch=master)

Pathway allows you to encapsulate your app's business logic into operation objects (also known as application services on the DDD lingo).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pathway'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install pathway

## Introduction

Pathway helps you separate your business logic from the rest of your application; regardless if is an HTTP backend, a background processing daemon, etc.
The main concept Pathway relies upon to build domain logic modules is the operation, this important concept will be explained in detail in the following sections.


Pathway also aims to be easy to use, be lightweight and modular, avoid unnecessary heavy dependencies, keep the stdlib clean from monkey patches and yield an organized and uniform codebase.

## Usage

### Core API and concepts

As mentioned earlier the operation is a crucial concept Pathway leverages upon. Operations not only structures your codebase (into steps as will be explained later) but also express meaningful business actions. Operations can be thought as use cases too: they should express an activity -to be perform by an actor interacting with system- which should be understandable by anyone familiar with the business regardless of their technical expertise.


Operations should ideally don't contain any business rules but instead orchestrate and delegate to other more specific subsystems and services. The only logic present then should be glue code and transformations that make iterations with the inner system layers possible.

#### Function object protocol (the `call` method)
#### Steps
- Succesful
- Failed
#### Operation result
#### Initialization and context
#### Execution process state
#### Result value
#### Alternative invocation syntaxes and pattern matching DSL

### Plugins
#### Plugin architecture

#### `SimpleAuth` plugin
#### `DryValidation` plugin
#### `SequelModels` plugin
#### `Responder` plugin

### Testing tools
#### Rspec config
#### Rspec matchers

## Best practices
### Operation object design and organization
### Testing recomendations

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pabloh/pathway.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
