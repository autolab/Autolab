# Schedulers

Schedulers are instructor scripts that run periodically. They can be managed via `Manage Course > Manage schedulers`.

!!! info "Interval Guarantees"
    Schedulers only run when a page load occurs. Thus, the interval parameter only guarantees a minimum time between runs.

## Scheduler structure
Schedulers must define a `update` method within a class or module. Changes made to the scheduler file take effect immediately.

**Using a module**
```ruby
module Updater
    def self.update(course)
        # code goes here
    end
end
```
**Using a class**
```ruby
class Updater
    def self.update(course)
        # code goes here
    end
end
```

## Visual Run
You can run a scheduler manually by clicking the `Run` button. This is useful for ensuring the code's correctness. 

To assist in debugging, you can return a string from the `update` method, which will be displayed as output in the browser.
You should return `nil` to represent no output.

!!! info "Output String"
    If you do not explicitly return a value, this might lead to unexpected outputs due to Ruby's implicit return values.

    The return value will be converted to a string if possible, else it will be treated as no output.

**Example file**
```ruby
module Updater
    def self.update(course)
        out = ""
        out << "my output\n"

        out
    end
end
```
**Visual Run Output**
![Scheduler Visual Run](/images/scheduler_visual_run.png)