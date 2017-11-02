# Pathway

[![Gem Version](https://badge.fury.io/rb/pathway.svg)](https://badge.fury.io/rb/pathway)
[![CircleCI](https://circleci.com/gh/pabloh/pathway/tree/master.svg?style=shield)](https://circleci.com/gh/pabloh/pathway/tree/master)
[![Coverage Status](https://coveralls.io/repos/github/pabloh/pathway/badge.svg?branch=master)](https://coveralls.io/github/pabloh/pathway?branch=master)

Pathway allows you to encapsulate your application business logic into operation objects (also known as application services on the DDD lingo).

## Installation

    $ gem install pathway

## Introduction

Pathway helps you separate your business logic from the rest of your application; regardless if is an HTTP backend, a background processing daemon, etc.
The main concept Pathway relies upon to build domain logic modules is the operation, this important concept will be explained in detail in the following sections.


Pathway also aims to be easy to use, stay lightweight and extensible (by the use of plugins), avoid unnecessary dependencies, keep the core classes clean from monkey patching and help yielding an organized and uniform codebase.

## Usage

### Main concepts and API

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
Each `step` (or `set`) call is referring to a method inside the operation class, superclasses or available through a plugin, these methods will be eventually invoked on `call`.
All of the steps constitute the operation use case and follow a series of conventions in order to carry the process state along the execution process.

When you run the `call` method, the auto-generated code will save the provided argument at the `input` key within the execution state. Subsequent steps will receive this state and will be able to update it, to set the result value or and auxiliary key to communicate with the next steps on the execution path.

Each step (as the operation as whole) can succeed of fail, when the latter happens execution is halted, and the operation `call` method returns immediately.
To signal a failure you must return a `failure(...)` or `error(...)` in the same fashion as when defining `call` directly.

If you return a `success(...)` or anything that's not a failure the execution carries on but the value is ignored. If you want to save the result value, you must use `set` instead of `step` at the process block, that will save your wrapped value, into the key provided at `to:`.
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

Let's now go through a fully defined operation using steps:

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

  def authorize(*)
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

  def create_nugget(:params, **)
    Nugget.create(owner: current_user, **params)
  def

  def notify(:nugget, **)
    Notifier.notify(:new_nugget, nugget)
  else
end
```

In the above example the operation will create nugget (whatever that is...). As you can see we are using the methods we mention before to indicate that we need a current user to be present `context: current_user` on initialization, a `call` method to be defined `process do ... end`, and the result value should be stored at the `:nugget` key.

Lets delve into the `process` block: it defines three steps using the `step` method and `create_nugget` using `set`, as we said before, this last step will set the result key (`:nugget`) since the `to:` keyword argument is absent.

Now, for each of the step methods:

- `:authorize` doesn't needs the state so just ignores it, then checks if the current user is allowed to perform the operation and halts the execution by returning a `:forbidden` error type if is not, otherwise does nothing and the execution goes on.
- `:validate` gets the state, checks the validity of the `:input` value which as we said is just the `call` method input, returns an `error(...)` when there's a problem, and if the validation is correct it updates the state but saving the sanitized values in `:params`. Note that the return value is `state[:params]`, but is ignored like the last one, since this method is specified using `step`.
- `:create_nugget` first takes the `:params` attribute from the state (ignoring everything else), and calls `create` on the `Nugget` model with the sanitized params and the current user. The return value is saved to the result key (`:nugget` in this case) as the step is defined using `step` without `to:`.
- `:notify` grabs the `:nugget` from the state, and simply emits a notification with it, it has no meaningful return value, so is ignored.

This example basically touches all the essential concepts needed for defining an operation class. If you can grasp it you already have a good understanding on how to implement one. There are still some very important bits to cover (like testing), and we'll tackle that on later sections.

On a final note, you may be thinking that the code could be bit less verbose; also, shouldn't very common stuff like validation or authorization be simpler to use?; and maybe, why specify the result key?, it could be possible infer it from the surrounding code. We will address all these issues on the next section by using plugins, `pathway`'s extension mechanism.

### Plugins

Pathway can be extended by the use of plugins. They are very similar to the one found in [Roda](http://roda.jeremyevans.net/) or [Sequel](http://sequel.jeremyevans.net/). So if you are already familiar with any of those gems you shouldn't have any problem using `pathway`'s plugin system.

In order to activate a plugin you must call the `plugin` method on the class:

```ruby
class BaseOperation < Pathway::Operation
  plugin :foobar, qux: 'quz'
end


class SomeOperation < BaseOperation
  # The :foobar plugin will also be activated here
end
```

The plugin name must be specified as a `Symbol` (or also as the `Module` where is implemented, but more on that later), and can it take parameters next to the plugin's name.
When activated it will enrich your operations with new instance and class methods plus new customs step for the process DSL.

Mind you, if you wish to activate a plugin for a number of operations you can activate it for all of them directly on the `Pathway::Operation` class, or you can create your own base operation and all its descendants will inherit the base class' plugins.

#### `DryValidation` plugin

This plugin provides integration with the [dry-validation](http://dry-rb.org/gems/dry-validation/) gem. I won't explain in detail how to use this library since is already extensively documented on its official website, but instead I'll assume certain knowledge of it, nonetheless, as you'll see in a moment, its API pretty self-explanatory.

`dry-validation` provides a very simple way to define form (or schema) objects to process and validate our input. The provided custom `:validate` step allows you to run your input though a form to check your data is valid before continuing. When the input is invalid it will return an error object with type `:validation` and the reasons the validation failed on the `details` attribute. Is commonly the first step any operation runs.

When using this plugin we'll have to provide an already defined form to the step to use or we can also define one inline.
Let's see a few examples:

```ruby
NuggetForm = Dry::Validation.Form do
  required(:owner).filled(:str?)
  required(:price).filled(:int?)
end

class CreateNugget < Pathway::Operation
  plugin :dry_validation

  form NuggetForm

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

As it can be seen at the code above, the form is first defined elsewhere, and the operation can be set up to use it by calling `form NuggetForm`, and use validate the input at the process block by calling `step :validate`.

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation

  form do
    required(:owner).filled(:str?)
    required(:price).filled(:int?)
  end

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

This second example is equivalent to the first one, but here we call `form` a block instead and no parameter; this block will be use as definition body for a form object that will be stored internally. This way you to keep the form and operation at the same place, which is convenient when you have a rather simpler form and don't need to reuse it.

One interesting nuance to keep in mind regarding the inline block form is that, when doing operation inheritance, if the parent operation already has a form, the child operation will define a new one extending from the parent's. This is very useful to share form functionality among related operations in the same class hierarchy.

##### Form options

If you are familiar with `dry-validation` you probably know it provides a way to [inject options](http://dry-rb.org/gems/dry-validation/basics/working-with-schemas/#injecting-external-dependencies) before calling the form instance.

On those scenarios you must either use the `auto_wire_options: true` plugin argument, or specify how to map options from the execution state to the form when calling `step :validate`.
Lets see and example for each case:

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation, auto_wire_options: true

  context :user_name

  form do
    configure { options :user_name }

    required(:owner).filled(:str?, :eql?: user_name)
    required(:price).filled(:int?)
  end

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

Here we see that the form needs a `:user_name` option so we tell the operation to grab the attribute with the same name from the execution state by activating `:auto_wire_options`, afterwards, when the validation runs, the form will already have the user name available.

Mind you, this option is `false` by default, so be sure to set it to `true` at `Pathway::Operation` if you'd rather have it for all your operations.

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation

  context :current_user_name

  form do
    configure { options :user_name }

    required(:owner).filled(:str?, :eql?: user_name)
    required(:price).filled(:int?)
  end

  process do
    step :validate, with: { user_name: :current_user_name } # Inject :user_name to the form object using :current_user_name
    step :create_nugget
  end

  # ...
end
```

On the other hand, if for some reason the name of the form's option and state attribute don't match, we can just pass `with: {...}` when calling to `step :validate`, indicating how to wire the attributes, the example above illustrates just that.

The `with:` parameter can always be specified, at `step :validate`, and allows you to override the default mapping regardless if auto-wiring is active or not.

#### `SimpleAuth` plugin

This very simple plugin adds a custom step called `:authorize`, that can be used to check for permissions and halt the operation with a `:forbidden` error when they aren't fulfilled.

In order to use it you must define a boolean predicate to check for permissions, by passing a block to the `authorization` method:

```ruby
class MyOperation < Pathway::Operation
  plugin :simple_auth

  context :current_user
  authorization { current_user.is_admin? }

  process do
    step :authorize
    step :perform_some_action
  end

  # ...
end
```

#### `SequelModels` plugin

The `sequel_models` plugin helps integrating operations with the [Sequel](http://sequel.jeremyevans.net/) ORM, by adding a few custom steps.

This plugin expects you to be using `Sequel` model classes to access your DB. In order to exploit it, you need to indicate which model your operation is going to work with, hence you must specify said model when activating the plugin with the `model:` keyword argument, or later using the `model` class method.
This configuration will then be used on the operation class and all its descendants.

```ruby
class MyOperation < Pathway::Operation
  plugin :sequel_models, model: Nugget, search_by: :name, set_result_key: false
end

# Or...

class MyOperation < Pathway::Operation
  plugin :sequel_models

  # This is useful when using inheritance and you need different models per operation
  model Nugget, search_by: :name, set_result_key: false

  process do
    step :authorize
    step :perform_some_action
  end
end
```

As you can see above you can also customize the search field (`:search_by`) and indicate if you want to override the result key (`:set_result_key`) when calling to `model`.
These two options aren't mandatory, and by default pathway will set the search field to the class model primary key, and override the result key to a snake cased version of the model name (ignoring namespaces if contained inside a class or module).

Let's now take a look at the provided extensions:

##### `:fetch_model` step

This step will fetch a model from the DB, by extracting the search field from the `call` method input parameter stored at `:input` in the execution state. If the model cannot be fetched from the DB it will halt the execution with a `:not_found` error, otherwise it will simply save the model into the result key (which will be `:nugget` for the example below).
You can latter access the fetched model from that attribute and if the operation finish successfuly, it will be the operation result.

```ruby
class UpdateNugget < Pathway::Operation
  plugin :sequel_models, model: Nugget

  process do
    step :validate
    step :fetch_model
    step :fetch_model, from: User, with: :user_id, search_by: :pk, to: :user # Even the default class can also be overrided with 'from:'
    step :update_nugget
  end

  # ...
end
```

As a side note, and as you can see at the 3rd step, `:fetch_model` allows you to override the search column (`search_by:`), the input parameter to extract from `input` (`with:`), the attribute to store the result (`to:`) and even the default search class (`from:`). If the current defaults doesn't fit your needs and you'll have these options available. When, for instance, if you need some extra object to execute your operation.

##### `transaction` and `after_commit`

These two are bit special since they aren't actually custom steps but just new methods that extend the process DSL itself.
These methods will take a block as an argument within which you can define inner steps.
Keeping all that in mind the only thing `transaction` and `after_commit` really do is surround the inner steps with `SEQUEL_DB.transaction { ... }` and `SEQUEL_DB.after_commit { ... }` blocks, respectively.

```ruby
class CreateNugget < Pathway::Operation
  plugin :sequel_models, model: Nugget

  process do
    step :validate
    transaction do
      step :create_nugget
      step :attach_history_note
      after_commit do
        step :send_emails
      end
    end
  end

  # ...
end
```

When won't get into the details for each step in the example above, but the important thing to take away is that `:create_nugget` and `:attach_history_note` will exists withing a single transaction and `send_mails` (and any steps you add in the `after_commit` block) will only run after the transaction has finished successfuly.

Another nuance to take into account is that calling `transaction` will start a new savepoint, since, in case you're already inside a transaction, it will be able to properly notify that the transaction failed by returning an error object when that happens.

#### `Responder` plugin

This plugin extend the `call` class method on the operation in order to accept a block. You can then use this block for flow control on success and failure and to pattern match different type of errors.

There are two way to use this plugin: by discriminating between success and failure, and when by also discriminating according to the specific failure reason.

On each case you must provide the action to execute for every outcome using blocks:

```ruby
MyOperation.plugin :responder # 'plugin' is actually a public method

MyOperation.(context, params) do
  success { |value| r.halt(200, value.to_json) } # BTW: 'r.halt' is a Roda request method used to exemplify
  failure { |error| r.halt(403) }
end
```

On example above we provide a block for both the success and the failure case. On each block the result value or the error object error will be provided at the blocks' argument, the result of corresponding block will be the result of the whole expression.

Lets now show an example with pattern matching:

```ruby
MyOperation.plugin :responder

MyOperation.(context, params) do
  success              { |value| r.halt(200, value.to_json) }
  failure(:forbidden)  { |error| r.halt(403) }
  failure(:validation) { |error| r.halt(422, error.details.to_json) }
  failure(:not_found)  { |error| r.halt(404) }
end
```

As you can see is almost identical as the previous example only that this time you provide the error type on each `failure` call.

### Plugin architecture

### Testing tools

As of right now only `rspec` is supported, that is, you can obviously test your operations with any framework you want, but all the provided matchers are designed for `rspec`.

#### Rspec config

In order to load Pathway's operation matchers you must add the following line to your `spec_helper.rb` file, after loading `rspec`:

```ruby
require 'pathway/rspec'
```

#### Rspec matchers

Pathway provide a few matchers in order to tests your operation easier.
Let's go through a full example and break it up in the following subsections:

```ruby
# create_nugget.rb

class CreateNugget < Pathway::Operation
  plugin :dry_validation

  form do
    required(:owner).filled(:str?)
    required(:price).filled(:int?)
    optional(:disabled).maybe(:bool?)
  end

  process do
    step :validate
    set  :create_nugget
  end

  def create_nugget(params:,**)
    Nugget.create(params)
  end
end


# create_nugget_spec.rb

describe CreateNugget do
  describe '#call' do
    subject(:operation) { CreateNugget.new }

    context 'when the input is valid' do
      let(:input) { owner: 'John Smith', value: '11230' }

      it { is_expected.to succeed_on(input).returning(an_instace_of(Nugget)) }
    end

    context 'when the input is invalid' do
      let(:input) { owner: '', value: '11230' }

      it { is_expected.to fail_on(input).
             with_type(:validation).
             message('Is not valid').
             and_details(owner: ['must be present']) }
    end
  end

  describe '.form' do
    subject(:form) { CreateNugget.form }

    it { is_expected.to require_fields(:owner, :price) }
    it { is_expected.to accept_optional_field(:disabled) }
  end
end
```

##### `succeed_on` matcher

This first matcher works on the operation itself and that's why could set `subject` with the operation instance and use `is_expected.to succeed_on(...)` on the example.
The assertion it performs is simply is the operation was successful, also you can optionally chain `returning(...)` if you want to test the returning value, this method allows nesting matchers as is the case in the example.

##### `fail_on` matcher

This second matcher is analog to `succeed_on` but it asserts that operation execution was a failure instead. If you return an error object you can also assert the error type using the `type` chain method (aliased as `and_type` and `with_type`); the error message (`and_message`, `with_message` or `message`); and the error details (`and_details`, `with_details` or `details`). Mind you, the chain methods for the message and details accept nested matchers while the `type` chain can only test by equality.

##### form matchers

Finally we can see that we are also testing the operation's form, implemented here with the `dry-validation` gem.

Two more matchers are provided when we use this gem: `require_fields` (aliased `require_field`) to test a form is expected to define a required set of fields, and `accept_optional_fields` (aliased `accept_optional_field`) to test an optional set of fields is defined for a form.

These matchers are only useful when using `dry-validation` and will very likely be extracted to its own gem in the future.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pabloh/pathway.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
