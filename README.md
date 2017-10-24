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


Pathway also aims to be easy to use, stay lightweight and extensible (by the use of plugins), avoid unnecessary dependencies, keep the core classes clean from monkey patching and help yielding an organized and uniform codebase.

## Usage

### Core API and concepts

As mentioned earlier the operation is a crucial concept Pathway leverages upon. Operations not only structure your code (using steps as will be explained later) but also express meaningful business actions. Operations can be thought as use cases too: they represent an activity -to be perform by an actor interacting with the system- which should be understandable by anyone familiar with the business regardless of their technical expertise.

Operations should ideally don't contain any business rules but instead orchestrate and delegate to other more specific subsystems and services. The only logic present then should be glue code or any adaptations required to make interactions with the inner system layers possible.

#### Function object protocol (the `call` method)

Operations works as function objects, they are callable and hold no state, as such, any object that responds to `call` and returns a result object can be a valid operation and that's the minimal protocol they needs to follow.
The result object must follow its protocol as well (and a helper class is provided for that end) but we'll talk about that in a minute.

Let's see an example:

```ruby
class MyFirstOperation
  def call(input)
    result = Repository.create(input)

    if result.valid?
      Pathway::Result.success(result)
    else
      Pathway::Result.failure(:create_error)
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

Also, let's ignore the specifics about `Repository.create(...)`, we just need to know that is some backend service which can return a value.


We then define a `call` method for the class. It only checks if the result is available and then wrap it into a successful `Result` object when is ok, or a failing one when is not.
And that is all is needed, you can then call the operation object, check whether it was completed correctly with `success?` and get the resulting value.

By following this protocol, you will be able to uniformly apply the same pattern on every HTTP endpoint (or whatever means your app has to communicates with the outside world). The upper layer of the application will offload all the domain logic to the operation and only will need to focus on the HTTP transmission details.

Maintaining always the same operation protocol will also be very useful when composing them.


#### Operation result

As should be evident by now an operation should always return either a successful or failed result. This concepts are represented by following a simple protocol, which `Pathway::Result` subclasses comply.

As we seen before, by querying `success?` on the result we can see if the operation we just ran went well, or you can also call to `failure?` for a negated version.

The actual result value produced by the operation is accessible at the `value` method and the error description (if there's any) at `error` when the operation fails.
To return wrapped values or errors from your operation you must call to `Pathway::Result.success(value)` or `Pathway::Result.failure(error)`.

It is worth mentioning that when you inherit from `Pathway::Operation` you'll have helper methods at your disposal to create result objects easier, for instance the previous section's example could be written as follows:


```ruby
class MyFirstOperation < Pathway::Operation
  def call(input)
    result = Repository.create(input)

    result.valid? ? success(result) : failure(:create_error)
  end
end
```

#### Error objects

`Pathway::Error` is a helper class to represent the error description from an failed operation execution (and can be used also for pattern matching as we'll see later).
It's use is completely optional, but provides you with a basic schema to communicate what when wrong. You can instantiate it by calling `new` on the class itself or using the helper method `error` provided in the operation class:

```ruby
class CreateNugget < Pathway::Operation
  def call(input)
    validation = Form.call(input)

    if validation.ok?
      success(Nugget.create(validation.values))
    else
      error(type: :validation, message: 'Invalid input', details: validation.errors)
    end
  end
end
```

As you can see `error(...)` expects `type:`, `message:` and `details` keyword arguments; `type:` is the only mandatory, the other ones can be omitted and have default values. Also `type` should be a `Symbol`, `message:` a `String` and `details:` can be a `Hash` or any other structure you see fit.

You then have accessors available on the error object to get the values back:

```ruby
result = CreateNugget.new.call(foo: 'foobar')
if result.failure?
  puts "#{result.error.type} error: #{result.error.message}"
end

```

Mind you, `error(...)` creates an `Error` object wrapped into a `Pathway::Failure` so you don't have to do it yourself.
If you decide to use `Pathway::Error.new(...)` directly, the expected arguments will be the same, but you will have to wrap the object before returning it.

#### Initialization context

It was previously mentioned that operations should work like functions, that is, they don't hold state and you should be able to execute the same instance all the times you need, on the other hand there will be some values that won't change during the operation life time and won't make sense to pass as `call` parameters, you can provide these values on initialization as context data.

Context data can be thought as 'request data' on an HTTP endpoint, values that aren't global but won't change during the executing of the request. Examples of this kind of data are the current user, the current device, a CSRF token, other configuration parameters, etc. You will want to pass this values on initialization, and probably pass them along to other operations down the line.

You must define your initializer to accept a `Hash` with this values, which is what every operation is expected to do, but as before, when inheriting from `Operation` you have the helper class method `context` handy to make it easier for you:

```ruby
class CreateNugget < Pathway::Operation
  context :current_user, notify: false

  def call(input)
    validation = Form.call(input)

    if validation.valid?
      nugget = Nugget.create(owner: current_user, **validation.values)

      Notifier.notify(:new_nugget, nugget) if @notify
      success(nugget)
    else
      error(type: :validation, message: 'Invalid input', details: validation.errors)
    end
  end
end


op = CreateNugget.new(current_user: user)
op.call(foo: 'foobar')
```

On the example above `context` is defining `:current_user` as a mandatory argument (it will raise an error if not provided) and `:notify` as an optional config argument, since it has a default value. Note that any extra non-defined value provided will be simply ignored.

Both of these parameters are available through accessors (and instance variables) inside the operation. Also there is a `context` private method you use to get all the initialization values as a frozen hash, in order to pass then along easily.

#### Alternative invocation syntax

If you don't care about keeping the operation instance around you can execute the operation directly on the class. To do so, use `call` with the initialization context first and then the remaining parameters:

```ruby
user = User.first(session[:current_user_id])
context = { current_user: user }

CreateNugget.call(context, params[:nugget]) # Using 'call' on the class
```

Also you have Ruby's alternative syntax to invoke the `call` method: `CreateNugget.(context, params[:nugget])`. On any case you'll get the operation result like when invoking `call` on the operation's instance.

Mind you that a context must always be provided for this syntax, if you don't need any initialization use an empty hash.

There's also third way to execute an operation, made available through a plugin, and will be explained later.

#### Steps

Finally the steps, these are the heart of the `Operation` class and the main reason you will want to inherit your own classes from `Pathway::Operation`.

So far we know that every operation needs to implement a `call` method and return a valid result object, `pathway` provides another option: the `process` block DSL, this method will define `call` behind the scenes for us, while also providing a way to define a business oriented set of steps to describe our operation's behavior.

Every step should be cohesive and focused on a single responsibly, ideally by offloading work to other subsystems. Designing steps this way is the developer's responsibility, but is made much simpler by the use of custom steps provided by plugins as we'll see later.

##### Process DSL

Lets start by showing some actual code:

```ruby
# ...
  # Inside an operation class body...
  process do
    step :authorize
    step :validate
    set  :create_nugget, to: :nugget
    step :notify
  end
# ...
```

To define your `call` method using the DSL just call to `process` and pass a block, inside it the DSL will be available.
Each `step` (or `set`) call is referring to a method inside the operation class, superclasses or available through a plugin, that will be eventually invoked.
All of the steps constitute the operation use case and must follow a series of conventions in order to carry the process state along the execution process.

When you run the `call` method, the auto-generated code will save the provided argument at the `input` key within the execution state. Subsequent steps will receive this state and will be able to update it, setting the result value or communicating with the next steps on the execution path.

Each step (as the operation as whole) can succeed of fail, when the latter happens execution is halted, and the operation `call` method returns immediately.
To signal a failure you must return with `failure` or `error` in the same fashion as when defining `call` directly.

If you return `success(...)` or anything that's not a failure the execution carries on but the value is ignored. If you want to save the result value, you must use `set` instead of `step` at the process block, that will save your wrapped value, into the key provided at `to:`.
Also non-failure return values inside steps are automatically wrapped so you can use `success` for clarity sake but it's optional.
If you omit the `to:` keyword argument when defining a `set` step, the result key value will be used by default, but we'll explain more on that later.

##### Operation execution state

In order to operate with the execution state, every step method receives a structure representing the current state. This structure is similar to a `Hash` and responds to its key methods (`:[]`, `:[]=`, `:fetch`, `:store` and `:include?`).

When an operation is executed, before running the first step, an initial state is created by coping all the values from the initialization context (and also including `input`).
Note that these values can be replaced on later steps but it won't mutate the context object itself since is always frozen.

A state object can be splatted on method definition in the same fashion as a `Hash`, allowing to cherry pick the attributes we are interested for a given step:

```ruby
# ...
  # This step only takes the values it needs and doesn't change the state.
  def send_emails(user:, report:, **)
    ReportMailer.send_report(user.email, report)
  end
# ...
```

Note the empty double splat at the end of the parameter list, this Ruby-ism means: grab the mentioned keys and ignore all the rest. If you omit it when you have outstanding keys Ruby's `Hash` destructing will fail.

##### Successful operation result

On each step you can access or change the operation result for a successful execution.
The value will be stored at one of the attributes within the state.
By default the state `:value` key will hold the resulting value, but if you prefer to use another name you can specify it through the `result_at` operation class method.

##### Full example

Let's now go through an operation with steps example:

```ruby
class CreateNugget < Pathway::Operation
  context :current_user

  process do
    step :authorize
    step :validate
    set  :create_nugget
    step :notify
  end

  result_at :nugget

  def authorize(**)
    unless current_user.can? :create, Nugget
      error(:forbidden)
    end
  end

  def validate(state)
    validation = NuggetForm.call(state[:input])

    if validation.ok?
      state[:params] = validation.values
    else
      error(type: :validation, details: validation.errors)
    end
  end

  def create_nugget(:params,**)
    Nugget.create(owner: current_user, **params)
  def

  def notify(:nugget, **)
    Notifier.notify(:new_nugget, nugget)
  else
end
```

On a final note, you may be thinking that the code could be bit less verbose; also, shouldn't very common stuff like validation or authorization be simpler to use?; and maybe, why specify the result key?, is possible you could infer it from the surrounding code. We will address all these issues on the next section by using plugins, `pathway`'s extension mechanism.

### Plugins

#### `DryValidation` plugin
#### `SimpleAuth` plugin
#### `SequelModels` plugin
#### `Responder` plugin

### Plugin architecture

### Testing tools
#### Rspec config
#### Rspec matchers

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pabloh/pathway.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
