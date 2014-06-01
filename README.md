# Puddle

```
gem install puddle
```

Puddle is a tiny gem for scheduling blocks in a background thread,
and optionally waiting for the return value.

## Usage

``` ruby
puddle = Puddle.new

result = puddle.sync { 2 + 1 }
result # => 3

future = puddle.async { 2 + 1 }
future.value # => 3

nested = puddle.sync do
  puddle.sync { 2 + 1 }
end
nested # => 3

puddle.shutdown(timeout) do
  puts "Puddle has been properly terminated."
end
```
