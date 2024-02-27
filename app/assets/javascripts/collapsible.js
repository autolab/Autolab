$(document).ready(function(){
  const $collapsible = $('.collapsible');
  $collapsible.collapsible({ accordion: false }); // Multiple items can be open at once

  // Accessibility features
  const $menuLink = $collapsible.find('.collapsible-menu-link');
  $menuLink.attr('aria-expanded', false);
  $menuLink.attr('role', 'button');
  $menuLink.on('click keydown', function() {
    $(this).attr("aria-expanded", function(_, attr){
      return attr !== "true";
    });
  });

  // Expand first item of first collapsible
  const $firstCollapsible = $collapsible.first();
  $firstCollapsible.collapsible('open', 0);
  $firstCollapsible.find('.collapsible-menu-link:first').attr('aria-expanded', 'true');
});
