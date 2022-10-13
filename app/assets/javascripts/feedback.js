document.getElementById("pageBody").style.width = '90%';
$(window).scroll(function(e){ 
  const $el = $('.result-fixed'); 
  const container = $('.result-container')[0];
  const containerWidth = container.offsetWidth;
  if (container.getBoundingClientRect().top <= 30){ 
    // set to be 25% of feedback container width instead of entire page
    // (which is what happens if you use % for a fixed div)
    // if the .25 is changed, also change the width for .result-summary class
    $el.css({'position': 'fixed', 'top': '30px', width: `${containerWidth * .25}px`}); 
  } else {
    $el.css({'position': 'absolute', 'top': '0px'}); 
  } 
});