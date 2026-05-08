(: TODO:CLEAN-UP, ADD MORE FUNCTIONS :)

module namespace api = 'http://le-tex.de/api';

declare
  %rest:GET
  %rest:path("/api")
  %output:method("xml")
function api:overview(){
  element functions {
  for $f in inspect:module(db:system()/globaloptions/webpath/text() || '/transpectui/api.xqm')/function
  where not($f/@name eq 'api:overview')
  return $f
  }
}; 

declare
  %rest:POST
  %rest:path("/api/upload")
  %rest:form-param('input_file', '{$file}')
  %rest:form-param('type', '{$type}')
  %output:method("json")
function api:upload_file($file as map(xs:string, xs:base64Binary), $type as xs:string){
  
};