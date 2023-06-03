# Schedulers

Schedulers allow instructors to define scripts that are run periodically. They can be managed via `Manage Course > Manage schedulers`.

!!! info "Interval Guarantees"
    Schedulers only run during a page load, meaning that the interval parameter represents the minimum time between executions.

## Scheduler structure
Schedulers must define a `update` method within a class or module. Changes made to the scheduler file take effect immediately.

**Using a module**
```
module Updater
    def self.update(course)
        # code goes here
    end
end
```
**Using a class**
```
class Updater
    def self.update(course)
        # code goes here
    end
end
```

## Visual Run
You can run a scheduler manually by clicking the `Run` button. This is useful to check for any syntax errors in the code. 

To assist in debugging, you can return a string from the `update` method, which will be displayed as output in the browser.

**Example file**
```
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