function AutolabComponent(elementId, initialState = {}) {
  this.$element = $(`#${elementId}`);
  this.state = initialState;

  this.setState = function(newState) {
      $.extend(this.state, newState);
      console.log('set state')
      this.render();
  };

  this.template = function() {
      // Default template; should be overridden by users of the library
      return `<div></div>`;
  };

  this.render = function() {
      this.$element.html(this.template());
  };
}

/**
 * Usage:
 * // Create a new instance, associating it with the 'app' element
    const MyComponent = new AutolabComponent('app');

    // Define a template for the instance
    MyComponent.template = function() {
        return `
            <div>
                <p>Name: ${this.state.name}</p>
                <p>Age: ${this.state.age}</p>
            </div>
        `;
    };

    // Set the initial state
    MyComponent.setState({
        name: 'John',
        age: 30
    });

    // Later in the code, you can update the state like this:
    // MyComponent.setState({ age: 31 });
 */
