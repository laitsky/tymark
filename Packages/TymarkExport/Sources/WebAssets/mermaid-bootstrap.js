(function() {
  const nodes = document.querySelectorAll('pre.mermaid');
  nodes.forEach((node) => {
    node.setAttribute('data-renderer', 'offline');
    node.setAttribute('title', 'Mermaid rendering library is not embedded; raw diagram source is shown.');
  });
})();
