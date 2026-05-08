window.addEventListener('load', init, false)

function init() {
  console.log('init...');
  var hiddenFileInput = document.getElementById('upload_file_uploaded_data');
  console.log(hiddenFileInput);
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
