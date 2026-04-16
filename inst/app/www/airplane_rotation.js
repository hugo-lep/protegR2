Shiny.addCustomMessageHandler('rotateImage', function(msg) {
  var img = document.getElementById(msg.id);
  if (img) {
    img.style.transform = 'rotate(' + msg.angle + 'deg)';
    img.style.transformOrigin = 'center center';
  }
});
