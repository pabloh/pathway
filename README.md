# Pathway

[![Gem Version](https://badge.fury.io/rb/pathway.svg)](https://badge.fury.io/rb/pathway)
[![Tests](https://github.com/pabloh/pathway/workflows/Tests/badge.svg)](https://github.com/oabloh/pathway/actions?query=workflow%3ATests)
[![Coverage Status](https://coveralls.io/repos/github/pabloh/pathway/badge.svg?branch=master)](https://coveralls.io/github/pabloh/pathway?branch=master)

Pathway encapsulates your business logic into simple operation objects (AKA application services on the [DDD](https://en.wikipedia.org/wiki/Domain-driven_design) lingo).

## Installation

    $ gem install pathway

## Description

Pathway helps you separate your business logic from the rest of your application; regardless of is an HTTP backend, a background processing daemon, etc.
The main concept Pathway relies upon to build domain logic modules is the operation, this important concept will be explained in detail in the following sections.

Pathway also aims to be easy to use, stay lightweight and extensible (by the use of plugins), avoid unnecessary dependencies, keep the core classes clean from monkey patching and help yield an organized and uniform codebase.

<!--
## Migrating to Ruby 3.x

TODO: small comment and link to `auto_deconstruct_state` plugin
-->

## Usage

### Main concepts and API

As mentioned earlier the operation is an essential concept Pathway is built around. Operations not only structure your code (using steps as will be explained later) but also express meaningful business actions. Operations can be thought of as use cases too: they represent an activity -to be performed by an actor interacting with the system- which should be understandable by anyone familiar with the business regardless of their technical expertise.

Operations shouldn't ideally contain any business rules but instead, orchestrate and delegate to other more specific subsystems and services. The only logic present then should be glue code or any data transformations required to make interactions with the inner system layers possible.

#### Function object protocol (the `call` method)

Operations work as function objects, they are callable and hold no state, as such, any object that responds to `call` and returns a result object can be a valid operation and that's the minimal protocol they need to follow.
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

Note first, we are not inheriting from any class nor including any module. This won't be the case in general as `pathway` provides classes to help build your operations, but it serves to illustrate how little is needed to implement one.

Also, let's ignore the specifics about `Repository.create(...)`, we just need to know that is some backend service from which a value is returned.


We then define a `call` method for the class. It only checks if the result is available and then wraps it into a successful `Result` object when is ok, or a failing one when is not.
And basically, that's all is needed, you can then call the operation object, check whether it was completed correctly with `success?` and get the resulting value.

By following this protocol, you will be able to uniformly apply the same pattern on every HTTP endpoint (or whatever means your app has to communicate with the outside world). The upper layer of the application will offload all the domain logic to the operation and only will need to focus on the HTTP transmission details.

Maintaining always the same operation protocol will also be very useful when composing them.

#### Operation result

As should be evident by now an operation should always return either a successful or failed result. These concepts are represented by following a simple protocol, which `Pathway::Result` subclasses comply with.

As we've seen before, by querying `success?` on the result we can see if the operation we just ran went well, or call to `failure?` to see if it failed.

The actual result value produced by the operation is accessible at the `value` method and the error description (if there's any) at `error` when the operation fails.
To return wrapped values or errors from your operation you must call `Pathway::Result.success(value)` or `Pathway::Result.failure(error)`.

It is worth mentioning that when you inherit from `Pathway::Operation` you'll have helper methods at your disposal to create result objects easily. For instance, the previous section's example could be written as follows:

```ruby
class MyFirstOperation < Pathway::Operation
  def call(input)
    result = Repository.create(input)

    result.valid? ? success(result) : failure(:create_error)
  end
end
```

#### Error objects

`Pathway::Error` is a helper class to represent the error description from a failed operation execution (and also supports pattern matching as we'll see later).
Its use is completely optional but provides you with a basic schema to communicate what went wrong. You can instantiate it by calling `new` on the class itself or using the helper method `error` provided by the operation class:

```ruby
class CreateNugget < Pathway::Operation
  def call(input)
    validation = Validator.call(input)

    if validation.ok?
      success(Nugget.create(validation.values))
    else
      error(:validation, message: 'Invalid input', details: validation.errors)
    end
  end
end
```

As you can see `error(...)` expects the `type` as the first parameter (and only the mandatory) then `message:` and `details` keyword arguments; these 2 last ones can be omitted and have default values. The type parameter must be a `Symbol`, `message:` a `String` and `details:` can be a `Hash` or any other structure you see fit.

Finally, the `Error` object have three accessors available to get the values back:

```ruby
result = CreateNugget.new.call(foo: 'foobar')
if result.failure?
  puts "#{result.error.type} error: #{result.error.message}"
  puts "Error details: #{result.error.details}"
end

```

Mind you, `error(...)` creates an `Error` object wrapped into a `Pathway::Failure` so you don't have to do it yourself.
If you decide to use `Pathway::Error.new(...)` directly, you will have to pass all the arguments as keywords (including `type:`), and you will have to wrap the object before returning it.

#### Initialization context

It was previously mentioned that operations should work like functions, that is, they don't hold state and you should be able to execute the same instance all the times you need, on the other hand, there will be some values that won't change during the operation lifetime and won't make sense to pass as `call` parameters, you can provide these values on initialization as context data.

Context data can be thought of as 'request data' on an HTTP endpoint, values that aren't global but won't change during the execution of the request. Examples of this kind of data are the current user, the current device, a CSRF token, other configuration parameters, etc. You will want to pass these values on initialization, and probably pass them along to other operations down the line.

You must define your initializer to accept a `Hash` with these values, which is what every operation is expected to do, but as before, when inheriting from `Operation` you have the helper class method `context` handy to make it easier for you:

```ruby
class CreateNugget < Pathway::Operation
  context :current_user, notify: false

  def call(input)
    validation = Validator.call(input)

    if validation.valid?
      nugget = Nugget.create(owner: current_user, **validation.values)

      Notifier.notify(:new_nugget, nugget) if @notify
      success(nugget)
    else
      error(:validation, message: 'Invalid input', details: validation.errors)
    end
  end
end


op = CreateNugget.new(current_user: user)
op.call(foo: 'foobar')
```

In the example above `context` is defining `:current_user` as a mandatory argument (it will raise an error if not provided) and `:notify` as an optional config argument, since it has a default value. Note that any extra non-defined value provided will be simply ignored.

Both of these parameters are available through accessors (and instance variables) inside the operation. Also, there is a `context` private method you use to get all the initialization values as a frozen hash, in order to pass them along easily.

#### Alternative invocation syntax

If you don't care about keeping the operation instance around you can execute the operation directly on the class. To do so, use `call` with the initialization context first and then the remaining parameters:

```ruby
user = User.first(session[:current_user_id])
context = { current_user: user }

CreateNugget.call(context, params[:nugget]) # Using 'call' on the class
```
Also, you have Ruby's alternative syntax to invoke the `call` method: `CreateNugget.(context, params[:nugget])`. In both cases, you'll get the operation result like when invoking `call` on the operation's instance.

Mind you that a context must always be provided for this syntax, if you don't need any initialization use an empty hash.

There's also a third way to execute an operation, made available through a plugin, that will be explained later.

#### Steps

Finally, the steps are the heart of the `Operation` class and the main reason you will want to inherit your own classes from `Pathway::Operation`.

So far we know that every operation needs to implement a `call` method and return a valid result object, `pathway` provides another option: the `process` block DSL, this method will define `call` behind the scenes for us, while also providing a way to define a business-oriented set of steps to describe our operation's behavior.

Every step should be cohesive and focused on a single responsibility, ideally by offloading work to other subsystems. Designing steps this way is the developer's responsibility but is made much simpler by the use of custom steps provided by plugins as we'll see later.

##### Process DSL

Let's start by showing some actual code:

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

To define your `call` method using the DSL just call to `process` and pass a block, inside it, the DSL will be available.
Each `step` (or `set`) call is referring to a method inside the operation class, superclasses, or available through a plugin, these methods will be eventually invoked by `call`.
All of the steps constitute the operation use case and follow a series of conventions in order to carry the process state along the execution process.

When you run the `call` method, the auto-generated code will save the provided argument at the `input` key within the execution state. Subsequent steps will receive this state and will be able to modify it, setting the result or auxiliary values, in order to communicate with the next steps on the execution path.

Each step (as the operation as a whole) can succeed or fail, when the latter happens execution is halted, and the operation `call` method returns immediately.
To signal a failure you must return a `failure(...)` or `error(...)` in the same fashion as when defining `call` directly.

If you return a `success(...)` or anything that's not a failure the execution carries on but the value is ignored. If you want to save the result value, you must use `set` instead of `step` at the process block, which will save your wrapped value, into the key provided at `to:`.
Also, non-failure return values inside steps are automatically wrapped so you can use `success` for clarity's sake but it's optional.
If you omit the `to:` keyword argument when defining a `set` step, the result key will be used by default, but we'll explain more on that later.

##### Operation execution state

To operate with the execution state, every step method receives a structure representing the current state. This structure is similar to a `Hash` and responds to its main methods (`:[]`, `:[]=`, `:fetch`, `:store`, `:include?` and `to_hash`).

When an operation is executed, before running the first step, an initial state is created by copying all the values from the initialization context (and also including `input`).
Note that these values can be replaced in later steps but it won't mutate the context object itself since is always frozen.

A state object can be splatted on method definition in the same fashion as a `Hash`, thus, allowing us to cherry-pick the attributes we are interested in any given step:

```ruby
# ...
  # This step only takes the values it needs and doesn't change the state.
  def send_emails(state)
    user, report = state[:user], state[:report]
    ReportMailer.send_report(user.email, report)
  end
# ...
```
<!--
TODO: explain Ruby 2.7 and 3.0 state deconstruction alternatives

Note the empty double splat at the end of the parameter list, this Ruby-ism means: grab the mentioned keys and ignore all the rest. If you omit the `**` when you have outstanding keys, Ruby's `Hash` destructing will fail.
-->

##### Successful operation result

On each step, you can access or change the result the operation will produce on a successful execution.
The value will be stored at one of the attributes within the state.
By default, the state's key `:value` will hold the result, but if you prefer to use another name you can specify it through the `result_at` operation class method.

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
      error(:validation, details: validation.errors)
    end
  end

  def create_nugget(state)
    Nugget.create(owner: current_user, **state[:params])
  end

  def notify(state)
    Notifier.notify(:new_nugget, state[:nugget])
  end
end
```

In the example above the operation will produce a nugget (whatever that is...).

As you can see in the code, we are using the previously mentioned methods to indicate we need the current user to be present on initialization: `context: current_user`, a `call` method (defined by `process do ... end`), and the result value should be stored at the `:nugget` key (`result_at :nugget`).

Let's delve into the `process` block: it defines three steps using the `step` method and `create_nugget` using `set`, as we said before, this last step will set the result key (`:nugget`) since the `to:` keyword argument is absent.

Now, for each of the step methods:

- `:authorize` doesn't need the state so just ignores it, then checks if the current user is allowed to run the operation and halts the execution by returning a `:forbidden` error type if is not, otherwise does nothing and the execution goes on.
- `:validate` gets the state, checks the validity of the `:input` value which as we said is just the `call` method input, returns an `error(...)` when there's a problem, and if the validation is correct it updates the state but saving the sanitized values in `:params`. Note that on success the return value is `state[:params]`, but is ignored like on `:authorize`, since this method was also specified using `step`.
- `:create_nugget` first takes the `:params` attribute from the state, and calls `create` on the `Nugget` model with the sanitized params and the current user. The return value is saved to the result key (`:nugget` in this case) as the step is defined using `step` without `to:`.
- `:notify` grabs the `:nugget` from the state, and simply emits a notification with it, it has no meaningful return value, so is ignored.

The previous example goes through all the essential concepts needed for defining an operation class. If you can grasp it, you already have a good understanding on how to implement one. There are still some very important bits to cover (like testing), and we'll tackle them in the latter sections.

On a final note, you may be thinking the code could be a bit less verbose; also, shouldn't very common stuff like validation or authorization be simpler to use? and why always specify the result key name? maybe is possible to infer it from the surrounding code. We will address all those issues in the next section using plugins, `pathway`'s extension mechanism.

### Plugins

Pathway operations can be extended with plugins. They are very similar to the ones found in [Roda](http://roda.jeremyevans.net/) or [Sequel](http://sequel.jeremyevans.net/). So if you are already familiar with any of those gems you shouldn't have any problem with `pathway`'s plugin system.

To activate a plugin just call the `plugin` method on the operation class:

```ruby
class BaseOperation < Pathway::Operation
  plugin :foobar, qux: 'quz'
end

class SomeOperation < BaseOperation
  # The :foobar plugin will also be activated here
end
```

The plugin name must be specified as a `Symbol` (or also as the `Module` where is implemented, but more on that later), and it can take parameters next to the plugin's name.
When activated it will enrich your operations with new instance and class methods plus extra customs step for the `process` DSL.

Mind you, if you wish to activate a plugin for a number of operations you can activate it for all of them directly on the `Pathway::Operation` class, or you can create your own base operation and all its descendants will inherit the base class' plugins.

#### `DryValidation` plugin

This plugin provides integration with the [dry-validation](http://dry-rb.org/gems/dry-validation/) gem. I won't explain in detail how to use this library since is already extensively documented on its official website, but instead, I'll assume certain knowledge of it, nonetheless, as you'll see in a moment, its API is pretty self-explanatory.

`dry-validation` provides a very simple way to define contract objects (conceptually very similar to form objects) to process and validate input. The provided custom `:validate` step allows you to run your input through a contract to check if your data is valid before carrying on. When the input is invalid it will return an error object of type `:validation` and the reasons the validation failed will be available at the `details` attribute. Is usually the first step an operation runs.

When using this plugin we can provide an already defined contract to the step to use or we can also define it within the operation.
Let's see a few examples:

```ruby
class NuggetContract < Dry::Validation::Contract
  params do
    required(:owner).filled(:string)
    required(:price).filled(:integer)
  end
end

class CreateNugget < Pathway::Operation
  plugin :dry_validation

  contract NuggetContract

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

As is shown above, the contract is defined first, then configured to be used by the operation by calling `contract NuggetContract`, and validate the input at the process block by placing the step `step :validate` inside the `process` block.

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation

  contract do
    params do
      required(:owner).filled(:string)
      required(:price).filled(:integer)
    end
  end

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

Now, this second example is equivalent to the first one, but here we call `contract` with a block instead of an object parameter; this block will be used as the definition body for a contract class that will be stored internally. Thus keeping the contract and operation code in the same place, this is convenient when you have a rather simpler contract and don't need to reuse it.

One interesting nuance to keep in mind regarding the inline block contract is that, when doing operation inheritance, if the parent operation already has a contract, the child operation will define a new one inheriting from the parent's. This is very useful to share validation logic among related operations in the same class hierarchy.

As a side note, if your contract is simple enough and has parameters and not extra validations rules, you can call the `params` method directly instead, the following code is essentially equivalent to the previous example:

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation

  params do
    required(:owner).filled(:string)
    required(:price).filled(:integer)
  end

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

##### Contract options

If you are familiar with `dry-validation` you probably know it provides a way to [inject options](https://dry-rb.org/gems/dry-validation/1.4/external-dependencies/) before calling the contract.

In those scenarios, you must either set the `auto_wire_options: true` plugin argument or specify how to map options from the execution state to the contract when calling `step :validate`.
Lets see and example for the first case:

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation, auto_wire_options: true

  context :user_name

  contract do
    option :user_name

    params do
      required(:owner).filled(:string)
      required(:price).filled(:integer)
    end

    rule(:owner) do
      key.failure("invalid owner") unless user_name == values[:owner]
    end
  end

  process do
    step :validate
    step :create_nugget
  end

  # ...
end
```

Here the defined contract needs a `:user_name` option, so we tell the operation to grab the attribute with the same name from the state by activating `:auto_wire_options`, afterwards, when the validation runs, the contract will already have the user name available.

Mind you, this option is `false` by default, so be sure to set it to `true` at `Pathway::Operation` if you'd rather have it enabled for all your operations.

On the other hand, if for some reason the name of the contract's option and state attribute don't match, we can just pass `with: {...}` when calling to `step :validate`, indicating how to wire the attributes, the following example illustrates just that:

```ruby
class CreateNugget < Pathway::Operation
  plugin :dry_validation

  context :current_user_name

  contract do
    option :user_name

    params do
      required(:owner).filled(:string)
      required(:price).filled(:integer)
    end

    rule(:owner) do
      key.failure("invalid owner") unless user_name == values[:owner]
    end
  end

  process do
    step :validate, with: { user_name: :current_user_name } # Inject :user_name to the contract object with the state's :current_user_name
    step :create_nugget
  end

  # ...
end
```

The `with:` parameter can always be specified for `step :validate`, and allows you to override the default mapping regardless if auto-wiring is active or not.

##### Older versions of `dry-validation`

Pathway supports the `dry-validation` gem down to version `0.11` (inclusive) in case you still have unmigrated code. When using versions below `1.0` the concept of contract is not present and instead of calling the `contract` method to set up your validation logic, you must use the `form` method. Everything else remains the same except, obviously, that you would have to use `dry-definition`'s [old API](https://dry-rb.org/gems/dry-validation/0.13/) which is a bit different from the current one.

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

The `sequel_models` plugin helps integrate operations with the [Sequel](http://sequel.jeremyevans.net/) ORM, by adding a few custom steps.

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

As you can see above you can also customize the search field (`:search_by`) and indicate if you want to override or not the result key (`:set_result_key`) when calling the `model` method.
These two options aren't mandatory, and by default, Pathway will set the search field to the class model primary key, and override the result key to a snake-cased version of the model name (ignoring namespaces if contained inside a class or module).

Let's now take a look at the provided extensions:

##### `:fetch_model` step

This step will fetch a model from the DB, by extracting the search field from the `call` method input parameter stored at `:input` in the execution state. If the model cannot be fetched from the DB it will halt the execution with a `:not_found` error, otherwise it will simply save the model into the result key (which will be `:nugget` for the example below).
You can later access the fetched model from that attribute and if the operation finishes successfully, it will be used as its result.

```ruby
class UpdateNugget < Pathway::Operation
  plugin :sequel_models, model: Nugget

  process do
    step :validate
    step :fetch_model
    step :fetch_model, from: User, using: :user_id, search_by: :pk, to: :user # Even the default class can also be overrided with 'from:'
    step :update_nugget
  end

  # ...
end
```

As a side note, and as shown in the 3rd step, `:fetch_model` allows you to override the search column (`search_by:`), the input parameter to extract from `input` (`using:`), the attribute to store the result (`to:`) and even the default search class (`from:`). If the current defaults don't fit your needs and you'll have these options available. This is commonly useful when you need some extra object, besides the main one, to execute your operation.

##### `transaction` and `after_commit`

These two are a bit special since they aren't actually custom steps but just new methods that extend the process DSL itself.
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

When won't get into the details for each step in the example above, but the important thing to take away is that `:create_nugget` and `:attach_history_note` will exists within a single transaction and `send_mails` (and any steps you add in the `after_commit` block) will only run after the transaction has finished successfully.

Another nuance to take into account is that calling `transaction` will start a new savepoint, since, in case you're already inside a transaction, it will be able to properly notify that the transaction failed by returning an error object when that happens.

#### `Responder` plugin

This plugin extends the `call` class method on the operation to accept a block. You can then use this block for flow control on success, failure, and also different types of failures.

There are two ways to use this plugin: by discriminating between success and failure, and also discriminating according to the specific failure type.

In each case you must provide the action to execute for every outcome using blocks:

```ruby
MyOperation.plugin :responder # 'plugin' is actually a public method

MyOperation.(context, params) do
  success { |value| r.halt(200, value.to_json) } # BTW: 'r.halt' is a Roda request method used to exemplify
  failure { |error| r.halt(403) }
end
```
<!--
```ruby
case MyOperation.(context, params)
in Success(value) then r.halt(200, value.to_json)
in Failure(_)     then r.halt(403)
end
```
-->

In the example above we provide a block for both the success and the failure case. On each block, the result value or the error object error will be provided at the blocks' argument, and the result of the corresponding block will be the result of the whole expression.

Lets now show an example with the error type specified:

```ruby
MyOperation.plugin :responder

MyOperation.(context, params) do
  success              { |value| r.halt(200, value.to_json) }
  failure(:forbidden)  { |error| r.halt(403) }
  failure(:validation) { |error| r.halt(422, error.details.to_json) }
  failure(:not_found)  { |error| r.halt(404) }
end
```
<!--
```ruby
case MyOperation.(context, params)
in Success(value)                       then r.halt(200, value.to_json)
in Failure(type: :forbidden)            then r.halt(403)
in failure(type: :validation, details:) then r.halt(422, details.to_json)
in failure(type: :not_found)            then r.halt(404)
end
```
-->

As you can see is almost identical to the previous example only that this time you provide the error type on each `failure` call.

<!--
#### `AutoDeconstructState` plugin

TODO: Explain reason, how to migrate, how to activate
-->
### Plugin architecture

Going a bit deeper now, we'll explain how to implement your own plugins. As was mentioned before `pathway` follows a very similar approach to the [Roda](http://roda.jeremyevans.net/) or [Sequel](http://sequel.jeremyevans.net/) plugin systems, which is reflected at its implementation.

Each plugin must be defined in a file placed within the `pathway/plugins/` directory of your gem or application, so `pathway` can require the file; and must be implemented as a module inside the `Pathway::Plugins` namespace module. Inside your plugin module, three extra modules can be defined to extend the operation API `ClassMethods`, `InstanceMethods` and `DSLMethods`; plus a class method `apply` for plugin initialization when needed.

If you are familiar with the aforementioned plugin mechanism (or others as well), the function of each module is probably starting to feel evident: `ClassMethods` will be used to extend the operation class, so any class methods should be defined here; `InstanceMethods` will be included on the operation so all the instance methods you need to add to the operation should be here, this includes every custom step you need to add; and finally `DSLMethods` will be included on the `Operation::DSL` class, which holds all the DSL methods like `step` or `set`.
The `apply` method will simply be run whenever the plugin is included, taking the operation class on the first argument and all then arguments the call to `plugin` received (excluding the plugin name).

Let's explain with more detail using a complete example:

```ruby
# lib/pathway/plugins/active_record.rb

module Pathway
  module Plugins
    module ActiveRecord
      module ClassMethods
        attr_accessor :model, :pk

        def inherited(subclass)
          super
          subclass.model = self.model
          subclass.pk    = self.pk
        end
      end

      module InstanceMethods
        delegate :model, :pk, to: :class

        # This method will conflict with :sequel_models so you mustn't load both plugins in the same operation
        def fetch_model(state, column: pk)
          current_pk = state[:input][column]
          result     = model.first(column => current_pk)

          if result
            state.update(result_key => result)
          else
            error(:not_found)
          end
        end
      end

      module DSLMethods
        # This method also conflicts with :sequel_models, so don't use them at once
        def transaction(&steps)
          transactional_seq = -> seq, _state do
            ActiveRecord::Base.transaction do
              raise ActiveRecord::Rollback if seq.call.failure?
            end
          end

          around(transactional_seq, &steps)
        end
      end

      def self.apply(operation, model: nil, pk: nil)
        operation.model = model
        opertaion.pk    = pk || model&.primary_key
      end
    end
  end
end
```

The code above implements a plugin to provide basic interaction with the [ActiveRecord](http://guides.rubyonrails.org/active_record_basics.html) gem.
Even though is a very simple plugin, it shows all the essentials to develop more complex ones.

As is pointed out in the code, some of the methods implemented here (`fetch_model` and `transmission`) collide with methods defined for `:sequel_models`, so as a consequence, these two plugins are not compatible with each other and cannot be activated for the same operation (although you can still do it for different operations within the same application).
You must be mindful about colliding method names when mixing plugins since `Pathway` can't bookkeep compatibility among every plugin that exists or will ever exist.
Is a good practice to document known incompatibilities on the plugin definition itself when they are known.

The whole plugin is completely defined within the `ActiveRecord` module inside the `Pathway::Plugins` namespace, also the file is placed at the load path in `pathway/plugin/active_record.rb` (assuming `lib/` is listed in `$LOAD_PATH`). This will ensure when calling `plugin :active_record` inside an operation, the correct file will be loaded and the correct plugin module will be applied to the current operation.

Moving on to the `ClassMethods` module, we can see the accessors `model` and `pk` are defined for the operation's class to allow configuration.
Also, the `inherited` hook is defined, this will simply be another class method at the operation and as such will be executed normally when the operation class is inherited. In our implementation, we just call to `super` (which is extremely important since other modules or parent classes could be using this hook) and then copy the `model` and `pk` options from the parent to the subclass in order to propagate the configuration downwards.

At the end of the `ActiveRecord` module definition, you can see the `apply` method. It will receive the operation class and the parameters passed when the `plugin` method is invoked. This method is usually used for loading dependencies or just setting up config parameters as we do in this particular example.

`InstanceMethods` first defines a few delegator methods to the class itself for later use.
Then the `fetch_model` step is defined (remember steps are but operation instance methods). Its first parameter is the state itself, as in the other steps we've seen before, and the remaining parameters are the options we can pass when calling `step :fetch_model` (mind you, this is also valid for steps defined in operations classes). Here we only take a single keyword argument: `column: pk`, with a default value; this will allow us to change the look-up column when using the step and is the only parameter we can use, passing other keyword arguments or extra positional parameters when invoking the step will raise errors.

Let's now examine the `fetch_model` step body, it's not really that much different from other steps, here we extract the model primary key from `state[:input][column]` and use it to perform a search. If nothing is found an error is returned, otherwise the state is updated in the result key, to hold the model that was just fetched from the DB.

We finally see a `DSLMethods` module defined to extend the process DSL.
For this plugin, we'll define a way to group steps within an `ActiveRecord` transaction, much in the same way the `:sequel_models` plugin already does for `Sequel`.
To this end, we define a `transaction` method to expect a steps block and pass it down to the `around` helper below which expects a callable (like a `Proc`) and a step list block. As you can see the lambda we pass on the first parameter makes sure the steps are being run inside a transaction or aborts the transaction if the intermediate result is a failure.

The `around` method is a low-level tool available to help extend the process DSL and it may seem a bit daunting at first glance but its usage is quite simple, the block is just a step list like the ones we find inside the `process` call; and the parameter is a callable (usually a lambda), that will take 2 arguments, an object from which we can run the step list by invoking `call` (and is the only thing it can do), and the current state. From here we can examine the state and decide upon whether to run the steps, how many times (if any), or run some code before and/or after doing so, like what we need to do in our example to surround the steps within a DB transaction.

### Testing tools

As of right now, only `rspec` is supported, that is, you can obviously test your operations with any framework you want, but all the provided matchers are designed for `rspec`.

#### Rspec config

In order to load Pathway's operation matchers you must add the following line to your `spec_helper.rb` file, after loading `rspec`:

```ruby
require 'pathway/rspec'
```

#### Rspec matchers

Pathway provides a few matchers in order to test your operation easier.
Let's go through a full example:

```ruby
# create_nugget.rb

class CreateNugget < Pathway::Operation
  plugin :dry_validation

  params do
    required(:owner).filled(:string)
    required(:price).filled(:integer)
    optional(:disabled).maybe(:bool)
  end

  process do
    step :validate
    set  :create_nugget
  end

  def create_nugget(state)
    Nugget.create(state[:params])
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

  describe '.contract' do
    subject(:contract) { CreateNugget.build_contract }

    it { is_expected.to require_fields(:owner, :price) }
    it { is_expected.to accept_optional_field(:disabled) }
  end
end
```

##### `succeed_on` matcher

This first matcher works on the operation itself and that's why we could set `subject` with the operation instance and use `is_expected.to succeed_on(...)` on the example.
The assertion it performs is simply that the operation was successful, also you can optionally chain `returning(...)` if you want to test the returning value, this method allows nesting matchers as is the case in the example.

##### `fail_on` matcher

This second matcher is analog to `succeed_on` but it asserts that operation execution was a failure instead. Also if you return an error object, and you need to, you can assert the error type using the `type` chain method (aliased as `and_type` and `with_type`); the error message (`and_message`, `with_message` or `message`); and the error details (`and_details`, `with_details` or `details`). Mind you, the chain methods for the message and details accept nested matchers while the `type` chain can only test by equality.

##### contract/form matchers

Finally, we can see that we are also testing the operation's contract (or form), implemented here with the `dry-validation` gem.

Two more matchers are provided: `require_fields` (aliased `require_field`) to test when a contract is expected to define a required set of fields, and `accept_optional_fields` (aliased `accept_optional_field`) to test when a contract must define a certain set of optional fields, both the contract class (at operation class method `contract_class`) or an instance (operation class method `build_contract`) can be provided.

These matchers are only useful when using `dry-validation` (on every version newer or equal to `0.11.0`) and will probably be extracted to their own gem in the future.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pabloh/pathway.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
