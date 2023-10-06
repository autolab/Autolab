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


function AutolabComponent(elementId, initialState = {}) {
  this.state = initialState;

  this.setState = function(newState = {}) {
      $.extend(this.state, newState);
      this.render();
      console.log('rendered', $(`#${elementId}`).html(), this.template())
  };

  this.template = function() {
      // Default template; should be overridden by users of the library
      return `<div></div>`;
  };

  this.render = function() {
    $(`#${elementId}`).html(this.template());
  };
}
