$(document).ready(function() {
  // Add new rubric item
  $('#add-rubric-item').click(function(e) {
    e.preventDefault();
    var newItem = createRubricItem();
    $('#rubric-items').append(newItem);
    M.updateTextFields();
  });

  // Delete rubric item
  $(document).on('click', '.delete-rubric-item', function(e) {
    e.preventDefault();
    var item = $(this).closest('.rubric-item');
    var id = item.data('id');
    
    if (id) {
      // If item exists in database, send delete request
      $.ajax({
        url: deletePath(id),
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
        },
        success: function() {
          item.remove();
          M.toast({html: 'Rubric item deleted'});
        },
        error: function() {
          M.toast({html: 'Error deleting rubric item'});
        }
      });
    } else {
      // If item is new (no id), just remove from DOM
      item.remove();
    }
  });

  // Save rubric item changes
  $(document).on('change', '.rubric-description, .rubric-points', function() {
    var item = $(this).closest('.rubric-item');
    var id = item.data('id');
    var data = {
      description: item.find('.rubric-description').val(),
      points: item.find('.rubric-points').val(),
      order: item.index()
    };
    console.log("data", data, id, basePath, item);
    if (!data.description || !data.points) {
      M.toast({html: 'Description and points are required'});
      return;
    }

    if (id) {
      // Update existing item
      $.ajax({
        url: updatePath(id),
        method: 'PATCH',
        data: data,
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
        },
        success: function() {
          M.toast({html: 'Rubric item saved'});
        },
        error: function() {
          M.toast({html: 'Error saving rubric item'});
        }
      });
    } else {
      // Create new item
      data.problem_id = window.location.pathname.split('/')[4];
      $.ajax({
        url: createPath,
        method: 'POST',
        data: data,
        headers: {
          'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
        },
        success: function(response) {
          item.data('id', response.id);
          M.toast({html: 'Rubric item created'});
        },
        error: function() {
          M.toast({html: 'Error creating rubric item'});
        }
      });
    }
  });

  // Path helpers for AJAX requests
  var createPath = basePath + "/rubric_items";
  var updatePath = function(id) {
    return basePath + "/rubric_items/" + id;
  };
  var deletePath = updatePath;
});

function createRubricItem() {
  return `
    <div class="rubric-item">
      <div class="row">
        <div class="input-field col s8">
          <input type="text" class="rubric-description" placeholder="Description" required>
        </div>
        <div class="input-field col s2">
          <input type="number" class="rubric-points" placeholder="0" step="any" required>
        </div>
        <div class="col s2">
          <button class="btn-flat delete-rubric-item"><i class="material-icons">delete</i></button>
        </div>
      </div>
    </div>
  `;
}