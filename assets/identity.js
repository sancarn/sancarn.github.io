(function () {
  var params = new URLSearchParams(window.location.search);
  if (params.get("ref") === "business") {
    sessionStorage.setItem("ref", "business");
  }

  var isBusiness = sessionStorage.getItem("ref") === "business";
  document.documentElement.dataset.ref = isBusiness ? "business" : "public";

  function applyIdentity() {
    document.querySelectorAll('[data-identity="name"]').forEach(function (el) {
      el.textContent = isBusiness ? "James Warren" : "Sancarn";
    });

    document.querySelectorAll('[data-identity="author"]').forEach(function (el) {
      el.textContent = isBusiness ? "James Warren, Software Engineer" : "Sancarn";
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", applyIdentity);
  } else {
    applyIdentity();
  }
})();
