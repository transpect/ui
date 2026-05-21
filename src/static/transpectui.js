window.addEventListener('load', init, false)

function init() {
  console.log('init...');
  var hiddenFileInput = document.getElementById('upload_file_uploaded_data');
  if (hiddenFileInput) {
    hiddenFileInput.addEventListener("change", event => {
      const target = event.target;
      const filename = target.value;
      var display = document.getElementById('file-name');
      var submitBtn = document.getElementById('submit-to-conversion');
      console.log(filename);
      console.log(display);
      display.value = filename;
      if (filename) {
        submitBtn.removeAttribute('disabled');
        submitBtn.classList.remove('disabled');
        display.classList.remove('invalid');
        display.classList.add('valid');
      } else {
        submitBtn.setAttribute('disabled','');
        submitBtn.classList.add('disabled');
        display.classList.add('invalid');
        display.classList.remove('valid');
      }
    })
  }
  
  var actionButtons = document.querySelectorAll('input[type="button"][data-href]')
  actionButtons.forEach(button => {
    button.addEventListener('click', (event) => runAction(event.target))
  })
}


function runAction(button) {
  const url = button.getAttribute('data-href');
  fetch (url)
  .then(response => response.text())
  .then(data => {
    console.log(data);
  })
};