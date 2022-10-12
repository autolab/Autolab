$(window).scroll(function(e){ 
  const $el = $('.result-fixed'); 
  const containerWidth = $('.result-container')[0].offsetWidth;
  console.log(containerWidth);
  if ($(this).scrollTop() > 250){ 
    $el.css({'position': 'fixed', 'top': '30px', width: `${containerWidth * .33}px`}); 
  } else {
    $el.css({'position': 'absolute', 'top': '0px'}); 
  } 
});