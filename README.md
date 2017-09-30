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


Pathway also aims to be easy to use, stay lightweight and modular, avoid unnecessary heavy dependencies, keep the core classes clean from monkey patching and help yielding an organized and uniform codebase.

## Usage

### Core API and concepts

As mentioned earlier the operation is a crucial concept Pathway leverages upon. Operations not only structure your code (using steps as will be explained latter) but also express meaningful business actions. Operations can be thought as use cases too: they represent an activity -to be perform by an actor interacting with the system- which should be understandable by anyone familiar with the business regardless of their technical expertise.


Operations should ideally don't contain any business rules but instead orchestrate and delegate to other more specific subsystems and services. The only logic present then should be glue code or any adaptations required to make iterations with the inner system layers possible.

#### Function object protocol (the `call` method)

Operations works as function objects, they are callable and hold no state, as such, any object that responds to `call` and returns a result object can be a valid operation and that's the minimal protocol they needs to follow.
The result object must follow its own protocol as well (and a helper class is provided for that end) but we'll talk about that in a minute.

Let's see an example:

```ruby
class MyFirstOperation
  def call(params)
    result = Repository.create(params)

    if result.ok?
      Pathway::Result.success(result)
    else
      Pathway::Result.failure('could not create')
    end
  end
end

result = MyFirstOperation.new.call(foo: 'foobar')
if result.success?
  puts result.value.inspect
else
  puts "Error: #{result.error}"
end

```

Note first we are not inheriting from any class nor including any module. This won't be the case in general as `pathway` provides classes to help build your operations, but it serves to illustrate how little is needed to implement one.

Also, let's ignore the specifics about `Repository.create(...)`, we just need to know that is a backend that's able to return some value.


We now provide for our class a `call` implementation. It will just check if the result is available and then wrap it into a successful `Result` object when is ok, or a failing one when is not.
And that's it, you can then call the operation object, check whether it was completed correctly with `success?` and get the result value.

By following this protocol, you will be able to uniformly use the same pattern on every HTTP endpoint (or whatever means your app has to communicates with the outside world). The upper layer of the application is now offloading all domain logic to the operation and now only needs to focus on the data transmission details. Maintaining always the same protocol will also be very useful when composing operations.


#### Operation result
- Successful
- Failed

#### Error objects
#### Initialization and context
#### Steps

Finally the steps, these are the heart of the operation class and the reason you will want to inherit your own from `Pathway::Operation`.

#### Execution process state
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
