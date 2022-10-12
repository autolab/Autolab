$(window).scroll(function(e){ 
  const $el = $('.result-fixed'); 
  const container = $('.result-container')[0];
  const containerWidth = container.offsetWidth;
  if (container.getBoundingClientRect().top <= 30){ 
    $el.css({'position': 'fixed', 'top': '30px', width: `${containerWidth * .33}px`}); 
  } else {
    $el.css({'position': 'absolute', 'top': '0px'}); 
  } 
});