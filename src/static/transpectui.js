const wsDataHref = 'ws://' + location.host + '/ws/data'; /* Get Data */
let wsData = new WebSocket(wsDataHref);
const wsParser = new DOMParser();
const serializer = new XMLSerializer();
let intentionalClose = false;
let username;


window.addEventListener('load', init, false)
window.addEventListener('load',wsInit,false)
window.addEventListener('pagehide',wsUnload,false)

function wsUnload() {
  intentionalClose = true;
  wsData.close();
  intentionalClose = false;
}

function showFile(file) {
  if (!file) return;
  
  const fileName = document.getElementById("fileName");
  fileName.textContent = file.name;
  fileName.classList.add("selected");
}

function init() {
  console.log('init...');
  username = document.querySelector('a.username')?.title;
  
  const dropZone = document.getElementById("dropZone");
  const fileInput = document.getElementById("fileInput");
  const fileName = document.getElementById("fileName");
  var submitBtn = document.getElementById('submit-to-conversion');
  if (fileInput) {
    fileInput.addEventListener("change", () => {
      console.log(fileInput.files);
      showFile(fileInput.files[0]);
      if (fileInput.files.length > 0) {
        submitBtn.removeAttribute('disabled');
        submitBtn.classList.remove('disabled');
      } else {
        submitBtn.setAttribute('disabled','');
        submitBtn.classList.add('disabled');
      }
    });
  }
  if (dropZone) {
    
    dropZone.addEventListener("dragover", (event) => {
      event.preventDefault();
      dropZone.classList.add("dragover");
    });
  
    dropZone.addEventListener("dragleave", () => {
      dropZone.classList.remove("dragover");
    });
  
    dropZone.addEventListener("drop", (event) => {
      event.preventDefault();
      dropZone.classList.remove("dragover");
  
      const file = event.dataTransfer.files[0];
  
      if (file) {
        // Keep the dropped file in the actual input.
        const dataTransfer = new DataTransfer();
        dataTransfer.items.add(file);
        fileInput.files = dataTransfer.files;
  
        showFile(file);
      }
    }); 
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

function wsInitListeners(){
  wsData.addEventListener("message", (event) => {
    //console.log("Data from server: " + Date.now());
    //console.log(event.data);
    receiveData(event.data)
  });
  
  wsData.addEventListener("close", (event) => {
    if (!intentionalClose) {
      displayDisconnectMessage(event)
    }
  });
}

function heartBeat() {
  wsDataSend('HEARTBEAT:' + username);
}

function restartPage(){
  wsData = new WebSocket(wsDataHref)
}

function wsInit() {
  /* WEBSOCKET INIT*/
  wsInitListeners();
  
  setInterval(heartBeat, 15000);
  //initTokenFields();
}
/*
function initTokenFields() {
  console.log('initTokens')
  document.getElementById('current-object-ids')?.getAttribute('data-value').split(',').forEach((o) => currentPageData.push(o));

  wsDataSend('ADDTOSTORE' + currentPageData.join(',') + ',' + Array.from(document.getElementById('existing-data').children).map(e => e.tagName.toLowerCase() + '|' + e.getAttribute('object-id')).join())
  const currentPageRequestQuery = mapToQueryString(currentLinkQueries)
  
  Array.from(document.querySelectorAll('*'))
  .filter((el) => el.closest('.template') == null)
  .filter(el =>  
    Array.from(el.attributes)
    .some(attr => attr.name.startsWith('data-token')))
  .forEach((a) => {currentPageFields.push(a)});

  loadExistingData();

  Array.from(document.getElementsByClassName('template'))
  .forEach((template) => {
    var newId = makeid(32);
    template.id = newId;
  })

   currentPageData
   .filter(d => d != 'not-set')
   .filter(d => !oDataMap.get(d))
   .forEach(d => {requestData('single:' + d + (currentPageRequestQuery?currentPageRequestQuery:''))})
  
  //replace all tokens
  if (objectDataPresent(currentPageData)) {
    currentPageData
    .filter(d => d != 'not-set')
    .filter(d => oDataMap.get(d))
    .forEach(d => {
      const oId = d
      replaceCurrentDataPaths(oId, false)
    })
  }
  //trigger all fullfilled templates
  Array.from(document.querySelectorAll('.template'))
  .filter(t => t.hasAttribute('data-form-id'))
  .filter(t => currentPageFields.some(e => formFromTemplate(t)?.contains(e)))
  .filter(t => currentPageData.all(c => oDataMap.get(c)))
  .filter(t => formFromTemplate(t).classList.contains('trigger-with-content'))
  .map(t => formFromTemplate(t))
  .filter(onlyUnique)
  .forEach(f => {
    console.log('request 197')
    f.requestSubmit()
  })

  Array.from(document.querySelectorAll(".current-data"))
  .filter((item) => {
    return item.closest('.template') == null
  })
  .forEach((item) => {
    var newId = makeid(32);
    //console.log(newId);
    item.id = newId;
    const oIdArray = new Array();
    oIdArray.push(item.getAttribute('data-path').split('/')[0]);
    oIdArray.forEach((oId) => {
      if (objectTemplateMap.get(oId)) {
        const old = Array.from(objectTemplateMap.get(oId))
        old.push(newId)
        objectTemplateMap.set(oId, old)
      } else {
        objectTemplateMap.set(oId, new Array(newId))
      }
    })
  })
  
  console.log('init templates');
  Array.from(document.getElementsByClassName('template'))
  .filter(e => e.hasAttribute('data-form-id'))
  .forEach((template) => {
    const items = template.getAttribute('data-items');
    const form = formFromTemplate(template);
    setSearchStatusDisplay(form, 'Started');
    if (form && items) {
      const filters = getFilterArray(form).join('&');
      //Init Search
      if (template.classList.contains('startEmpty')) {
      } else {
        //console.log('init Search');
        doSearch('' + items + '?' + filters, template.id)
      }
    }
  })
  console.log('init templates done');
}*/

function wsDataSend(query){
  if (query != '<heartbeat>'){
    console.log('send: ' + query)
  }
  switch (wsData.readyState) {
    case 0:
    return setTimeout(() => {
      wsDataSend(query)}, 1000)
    case 1:
    return wsData.send(query);
    case 2:
      displayDisconnectMessage()
    case 3:
      displayDisconnectMessage()
    default:
    return
  }
}

function wsParse(data) {
  try {
    return wsParser.parseFromString(data, "application/xml");
  } catch(err) {
    console.log(err)
    return null
  }
}

function receiveData(data) {
  const received = new Date();
  const parsed = wsParse(data)
  if (parsed.querySelector("parsererror")) {
    console.log(data);
  }
  console.log(serializer.serializeToString(parsed));
  console.log(parsed.evaluate('//data',parsed).iterateNext().children);
}

function displayDisconnectMessage(event){
  console.log("Connection Lost: ", event);
  /*if (document.querySelector('.fullscreen')){
    
  } else { 
    const blackScreen = document.createElement('div')
    blackScreen.classList.add('fullscreen')
    blackScreen.classList.add('blurred')
    blackScreen.innerHTML = ('VERBINDUNG ZUM SERVER VERLOREN. Bitte laden Sie die Seite neu [F5]\n') + (event?event.reason:'')
    document.querySelector('html').appendChild(blackScreen)
  }*/
}

function removeDisconnectMessage(event){
  console.log('remove disco-message');
  console.log(document.querySelector('.fullscreen'));
  document.querySelector('.fullscreen').remove()
}