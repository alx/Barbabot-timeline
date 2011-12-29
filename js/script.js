/* Author:

*/


$(window).scroll(function () {
  if($(document).height() - ($(window).scrollTop() + $(window).height()) < 200){
    $(".hidden:lt(50)").removeClass("hidden");
  }
});
