//NAVIGATION SCRIPT:
var navigateHeader = function(){
  var hash = window.location.hash;
  var headers = document.querySelectorAll("h1,h2,h3,h4,h5,h6,h7,h8,h9");
  for(var i=0;i<headers.length;i++){
    var header = headers[i];
    var hdr = encodeURI(header.innerText);
    if(hdr==hash.substr(1)){
      document.body.scrollTop = 0;
      header.scrollIntoView();
      break;
    };
  };
}

var makeHeader = function(header){
    var a = document.createElement("a");
    a.setAttribute("href","#" + encodeURI(header.innerText));
    var h = document.createElement(header.tagName);
    h.innerText = header.innerText;
    a.appendChild(h);
    header.replaceWith(a);
}

window.addEventListener("load",function(){
  var headers = document.querySelectorAll("h1,h2,h3,h4,h5,h6,h7,h8,h9");
  var arr = Array.from(headers);
  
  arr = arr.filter(function(e){
    return e.className != "headerIgnore"
  })
  arr.forEach(function(el){
    makeHeader(el);
  });
});

//Navigate to headers:
window.addEventListener('popstate', navigateHeader);
window.addEventListener("load",function(){
  setTimeout(function(){
    navigateHeader();
  });
});